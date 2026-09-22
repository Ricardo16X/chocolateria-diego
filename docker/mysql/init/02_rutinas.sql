-- ============================================================================
-- Artesanal Chocolate Diego — Entrega 8
-- 02_rutinas.sql — Funciones, disparadores, procedimientos y vistas
--
-- 5 funciones · 3 disparadores · 5 procedimientos almacenados · 10 vistas
--
-- Requisito para la capa de aplicacion:
-- antes de modificar el precio de un producto, la conexion debe fijar
--   SET @id_usuario_actual = <id>, @motivo_cambio_precio = '<texto>';
-- El disparador trg_producto_historial_precio rechaza el cambio si la
-- primera variable viene nula.
-- ============================================================================


-- ============================================================================
-- FUNCIONES
-- ============================================================================
DELIMITER $$

DROP FUNCTION IF EXISTS fn_stock_disponible$$
-- Existencia total de un producto sumando todas las bodegas y lotes.
CREATE FUNCTION fn_stock_disponible(p_id_producto INT UNSIGNED)
RETURNS DECIMAL(10,3)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_stock DECIMAL(10,3);

    SELECT COALESCE(SUM(cantidad_disponible), 0)
      INTO v_stock
      FROM existencia
     WHERE id_producto = p_id_producto;

    RETURN v_stock;
END$$

DROP FUNCTION IF EXISTS fn_bajo_stock_minimo$$
-- Devuelve 1 cuando la existencia total esta en o por debajo del minimo.
CREATE FUNCTION fn_bajo_stock_minimo(p_id_producto INT UNSIGNED)
RETURNS TINYINT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_minimo DECIMAL(10,3) DEFAULT NULL;

    SELECT stock_minimo
      INTO v_minimo
      FROM producto
     WHERE id_producto = p_id_producto;

    IF v_minimo IS NULL THEN
        RETURN 0;
    END IF;

    RETURN IF(fn_stock_disponible(p_id_producto) <= v_minimo, 1, 0);
END$$

DROP FUNCTION IF EXISTS fn_valor_inventario$$
-- Valor monetario de la existencia de un producto al precio de venta vigente.
CREATE FUNCTION fn_valor_inventario(p_id_producto INT UNSIGNED)
RETURNS DECIMAL(12,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_precio DECIMAL(10,2) DEFAULT NULL;

    SELECT precio_venta
      INTO v_precio
      FROM producto
     WHERE id_producto = p_id_producto;

    IF v_precio IS NULL THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND(fn_stock_disponible(p_id_producto) * v_precio, 2);
END$$

DROP FUNCTION IF EXISTS fn_calcular_total_venta$$
-- Suma de las lineas de una venta. Corresponde a venta.subtotal, antes de
-- descuento. La columna venta.total es generada y no se escribe nunca.
CREATE FUNCTION fn_calcular_total_venta(p_id_venta BIGINT UNSIGNED)
RETURNS DECIMAL(12,2)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_subtotal DECIMAL(12,2);

    SELECT COALESCE(SUM(subtotal_linea), 0)
      INTO v_subtotal
      FROM detalle_venta
     WHERE id_venta = p_id_venta;

    RETURN v_subtotal;
END$$

DROP FUNCTION IF EXISTS fn_rol_usuario$$
-- Nombre del rol asignado a un usuario. Devuelve NULL si el usuario no existe.
CREATE FUNCTION fn_rol_usuario(p_id_usuario INT UNSIGNED)
RETURNS VARCHAR(40)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_rol VARCHAR(40) DEFAULT NULL;

    SELECT r.nombre
      INTO v_rol
      FROM usuario u
      INNER JOIN rol r ON r.id_rol = u.id_rol
     WHERE u.id_usuario = p_id_usuario;

    RETURN v_rol;
END$$

DELIMITER ;


-- ============================================================================
-- DISPARADORES
-- ============================================================================
DELIMITER $$

DROP TRIGGER IF EXISTS trg_producto_historial_precio$$
-- Registra cada cambio de precio de venta en historial_precio.
CREATE TRIGGER trg_producto_historial_precio
AFTER UPDATE ON producto
FOR EACH ROW
BEGIN
    IF NEW.precio_venta <> OLD.precio_venta THEN
        IF @id_usuario_actual IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'PRODUCTO_SESION_USUARIO_REQUERIDA: Debe fijar @id_usuario_actual antes de cambiar el precio de un producto.';
        END IF;

        INSERT INTO historial_precio
            (id_producto, precio_anterior, precio_nuevo, id_usuario, motivo)
        VALUES
            (NEW.id_producto, OLD.precio_venta, NEW.precio_venta,
             @id_usuario_actual, @motivo_cambio_precio);
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_venta_bitacora_insert$$
-- Asienta en bitacora el registro de cada venta completada.
CREATE TRIGGER trg_venta_bitacora_insert
AFTER UPDATE ON venta
FOR EACH ROW
BEGIN
    IF OLD.estado <> 'completada' AND NEW.estado = 'completada' THEN
        INSERT INTO bitacora
            (id_usuario, evento, tabla_afectada, id_registro, descripcion)
        VALUES
            (NEW.id_usuario, 'venta', 'venta', NEW.id_venta,
             CONCAT('Venta registrada: ', NEW.numero_venta));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_venta_bitacora_anulacion$$
-- Asienta en bitacora la anulacion de una venta.
CREATE TRIGGER trg_venta_bitacora_anulacion
AFTER UPDATE ON venta
FOR EACH ROW
BEGIN
    IF OLD.estado <> 'anulada' AND NEW.estado = 'anulada' THEN
        INSERT INTO bitacora
            (id_usuario, evento, tabla_afectada, id_registro, descripcion)
        VALUES
            (NEW.id_usuario_anula, 'anulacion', 'venta', NEW.id_venta,
             CONCAT('Venta anulada: ', NEW.numero_venta,
                    COALESCE(CONCAT(' — ', NEW.motivo_anulacion), '')));
    END IF;
END$$

DELIMITER ;


-- ============================================================================
-- PROCEDIMIENTOS ALMACENADOS
-- ============================================================================
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_registrar_producto$$
-- Alta de producto en el catalogo. No crea existencia: el inventario se
-- origina siempre con un movimiento, via sp_ajustar_inventario.
CREATE PROCEDURE sp_registrar_producto(
    IN  p_id_categoria            INT UNSIGNED,
    IN  p_codigo                  VARCHAR(20),
    IN  p_nombre                  VARCHAR(120),
    IN  p_descripcion             TEXT,
    IN  p_porcentaje_cacao        TINYINT UNSIGNED,
    IN  p_unidad_medida           VARCHAR(20),
    IN  p_precio_venta            DECIMAL(10,2),
    IN  p_costo_referencia        DECIMAL(10,2),
    IN  p_stock_minimo            DECIMAL(10,3),
    IN  p_dias_alerta_vencimiento SMALLINT UNSIGNED,
    IN  p_maneja_lote             TINYINT,
    IN  p_visible_tienda          TINYINT,
    OUT p_id_producto             INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_precio_venta IS NULL OR p_precio_venta <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'PRODUCTO_PRECIO_INVALIDO: El precio de venta debe ser mayor que cero.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM categoria WHERE id_categoria = p_id_categoria) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'PRODUCTO_CATEGORIA_INEXISTENTE: La categoria indicada no existe.';
    END IF;

    START TRANSACTION;

    INSERT INTO producto (
        id_categoria, codigo, nombre, descripcion, porcentaje_cacao,
        unidad_medida, precio_venta, costo_referencia, stock_minimo,
        dias_alerta_vencimiento, maneja_lote, visible_tienda
    ) VALUES (
        p_id_categoria, p_codigo, p_nombre, p_descripcion, p_porcentaje_cacao,
        COALESCE(p_unidad_medida, 'unidad'), p_precio_venta, p_costo_referencia,
        COALESCE(p_stock_minimo, 0), COALESCE(p_dias_alerta_vencimiento, 30),
        COALESCE(p_maneja_lote, 1), COALESCE(p_visible_tienda, 1)
    );

    SET p_id_producto = LAST_INSERT_ID();

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_ajustar_inventario$$
-- Entrada o salida de inventario. El sentido lo determina tipo_movimiento.efecto.
-- Actualiza existencia y deja el asiento en movimiento_inventario con el
-- saldo posterior, que es lo que sostiene el kardex.
CREATE PROCEDURE sp_ajustar_inventario(
    IN p_id_producto         INT UNSIGNED,
    IN p_id_bodega           INT UNSIGNED,
    IN p_id_lote             INT UNSIGNED,
    IN p_id_tipo_movimiento  TINYINT UNSIGNED,
    IN p_cantidad            DECIMAL(10,3),
    IN p_id_usuario          INT UNSIGNED,
    IN p_id_usuario_autoriza INT UNSIGNED,
    IN p_motivo              VARCHAR(255)
)
BEGIN
    DECLARE v_id_existencia INT UNSIGNED DEFAULT NULL;
    DECLARE v_stock         DECIMAL(10,3) DEFAULT NULL;
    DECLARE v_saldo         DECIMAL(10,3);
    DECLARE v_efecto        VARCHAR(10) DEFAULT NULL;
    DECLARE v_requiere      TINYINT DEFAULT 0;
    DECLARE v_maneja_lote   TINYINT DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'INVENTARIO_CANTIDAD_INVALIDA: La cantidad del movimiento debe ser mayor que cero.';
    END IF;

    SELECT efecto, requiere_autorizacion
      INTO v_efecto, v_requiere
      FROM tipo_movimiento
     WHERE id_tipo_movimiento = p_id_tipo_movimiento;

    IF v_efecto IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'INVENTARIO_TIPO_MOVIMIENTO_INEXISTENTE: El tipo de movimiento indicado no existe.';
    END IF;

    IF v_requiere = 1 AND p_id_usuario_autoriza IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'INVENTARIO_AUTORIZACION_REQUERIDA: Este tipo de movimiento requiere autorizacion de un usuario.';
    END IF;

    SELECT maneja_lote INTO v_maneja_lote
      FROM producto WHERE id_producto = p_id_producto;

    IF v_maneja_lote IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'INVENTARIO_PRODUCTO_INEXISTENTE: El producto indicado no existe.';
    END IF;

    IF v_maneja_lote = 1 AND p_id_lote IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'INVENTARIO_LOTE_REQUERIDO: El producto maneja lote: debe indicarse el lote del movimiento.';
    END IF;

    START TRANSACTION;

    SELECT id_existencia, cantidad_disponible
      INTO v_id_existencia, v_stock
      FROM existencia
     WHERE id_producto = p_id_producto
       AND id_bodega   = p_id_bodega
       AND COALESCE(id_lote, 0) = COALESCE(p_id_lote, 0)
     FOR UPDATE;

    IF v_id_existencia IS NULL THEN
        IF v_efecto = 'resta' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'INVENTARIO_EXISTENCIA_INEXISTENTE: No existe existencia registrada para realizar la salida.';
        END IF;

        INSERT INTO existencia (id_producto, id_lote, id_bodega, cantidad_disponible)
        VALUES (p_id_producto, p_id_lote, p_id_bodega, 0);

        SET v_id_existencia = LAST_INSERT_ID();
        SET v_stock = 0;
    END IF;

    SET v_saldo = IF(v_efecto = 'suma', v_stock + p_cantidad, v_stock - p_cantidad);

    IF v_saldo < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'INVENTARIO_EXISTENCIA_NEGATIVA: La existencia no puede quedar negativa.';
    END IF;

    UPDATE existencia
       SET cantidad_disponible = v_saldo,
           fecha_actualizacion = CURRENT_TIMESTAMP
     WHERE id_existencia = v_id_existencia;

    INSERT INTO movimiento_inventario (
        id_tipo_movimiento, id_producto, id_lote, id_bodega,
        cantidad, saldo_posterior, id_usuario, id_usuario_autoriza, motivo
    ) VALUES (
        p_id_tipo_movimiento, p_id_producto, p_id_lote, p_id_bodega,
        p_cantidad, v_saldo, p_id_usuario, p_id_usuario_autoriza, p_motivo
    );

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_registrar_venta$$
-- Procedimiento central del punto de venta.
--
-- p_items es un arreglo JSON: [{"id_producto":1,"cantidad":2.000}, ...]
-- El lote no se indica: el procedimiento despacha por vencimiento mas
-- proximo (FEFO), que es el proposito de llevar control de lotes.
--
-- Deja la venta en estado 'completada', descuenta existencia, asienta un
-- movimiento por linea y crea el documento_fel en estado 'pendiente'. La
-- certificacion ante el certificador FEL-SAT queda para la capa de
-- aplicacion: si falla, la venta ya esta registrada.
--
-- p_id_cliente admite NULL: la venta a consumidor final en mostrador no
-- exige cliente registrado.
CREATE PROCEDURE sp_registrar_venta(
    IN  p_id_usuario                    INT UNSIGNED,
    IN  p_id_cliente                    INT UNSIGNED,
    IN  p_id_turno                      INT UNSIGNED,
    IN  p_id_metodo_pago                TINYINT UNSIGNED,
    IN  p_canal                         VARCHAR(20),
    IN  p_descuento                     DECIMAL(10,2),
    IN  p_id_usuario_autoriza_descuento INT UNSIGNED,
    IN  p_justificacion_descuento       VARCHAR(255),
    IN  p_nit_receptor                  VARCHAR(15),
    IN  p_nombre_receptor               VARCHAR(150),
    IN  p_items                         JSON,
    OUT p_id_venta                      BIGINT UNSIGNED,
    OUT p_id_documento_fel              BIGINT UNSIGNED
)
BEGIN
    DECLARE v_fin              INT DEFAULT 0;
    DECLARE v_id_producto      INT UNSIGNED;
    DECLARE v_cantidad         DECIMAL(10,3);
    DECLARE v_pendiente        DECIMAL(10,3);
    DECLARE v_id_existencia    INT UNSIGNED;
    DECLARE v_id_lote          INT UNSIGNED;
    DECLARE v_id_bodega        INT UNSIGNED;
    DECLARE v_stock            DECIMAL(10,3);
    DECLARE v_toma             DECIMAL(10,3);
    DECLARE v_precio           DECIMAL(10,2);
    DECLARE v_tipo_movimiento  TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_subtotal         DECIMAL(10,2);
    DECLARE v_descuento        DECIMAL(10,2);
    -- La tasa de IVA es un parametro de negocio, no un valor de despliegue:
    -- se lee de parametro_sistema en cada venta para poder ajustarse sin
    -- redesplegar el procedimiento. 0.12 es el respaldo si la fila falta.
    DECLARE v_tasa_iva         DECIMAL(6,4) DEFAULT 0.12;

    DECLARE cur_items CURSOR FOR
        SELECT jt.id_producto, jt.cantidad
          FROM JSON_TABLE(
                p_items,
                '$[*]' COLUMNS (
                    id_producto INT UNSIGNED  PATH '$.id_producto',
                    cantidad    DECIMAL(10,3) PATH '$.cantidad'
                )
          ) AS jt;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = 1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_descuento = COALESCE(p_descuento, 0);

    SELECT CAST(valor AS DECIMAL(6,4)) INTO v_tasa_iva
      FROM parametro_sistema
     WHERE clave = 'fel.tasa_iva'
     LIMIT 1;
    SET v_tasa_iva = COALESCE(v_tasa_iva, 0.12);

    IF p_items IS NULL OR JSON_VALID(p_items) = 0 OR COALESCE(JSON_LENGTH(p_items), 0) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'VENTA_SIN_ITEMS: La venta debe contener al menos un producto.';
    END IF;

    IF v_descuento > 0
       AND (p_id_usuario_autoriza_descuento IS NULL OR p_justificacion_descuento IS NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'VENTA_DESCUENTO_SIN_AUTORIZACION: Todo descuento requiere usuario que lo autoriza y justificacion.';
    END IF;

    SELECT id_tipo_movimiento
      INTO v_tipo_movimiento
      FROM tipo_movimiento
     WHERE nombre = 'venta' AND efecto = 'resta'
     LIMIT 1;

    IF v_tipo_movimiento IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'VENTA_TIPO_MOVIMIENTO_FALTANTE: Falta el tipo de movimiento "venta" con efecto "resta" en el catalogo.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM JSON_TABLE(p_items, '$[*]'
            COLUMNS (cantidad DECIMAL(10,3) PATH '$.cantidad')) AS jt
         WHERE jt.cantidad IS NULL OR jt.cantidad <= 0
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'VENTA_CANTIDAD_INVALIDA: Todas las cantidades de la venta deben ser mayores que cero.';
    END IF;

    START TRANSACTION;

    -- numero_venta definitivo se fija despues del INSERT, a partir del
    -- correlativo real. El valor temporal es unico por conexion.
    INSERT INTO venta (
        numero_venta, id_cliente, id_usuario, id_turno, id_metodo_pago,
        canal, subtotal, descuento,
        id_usuario_autoriza_descuento, justificacion_descuento
    ) VALUES (
        CONCAT('#', CONNECTION_ID()),
        p_id_cliente, p_id_usuario, p_id_turno, p_id_metodo_pago,
        COALESCE(p_canal, 'presencial'), 0, 0,
        NULL, NULL
    );

    SET p_id_venta = LAST_INSERT_ID();

    UPDATE venta
       SET numero_venta = CONCAT('V-', DATE_FORMAT(fecha_hora, '%Y%m%d'), '-',
                                 LPAD(p_id_venta, 6, '0'))
     WHERE id_venta = p_id_venta;

    OPEN cur_items;

    item_loop: LOOP
        FETCH cur_items INTO v_id_producto, v_cantidad;
        IF v_fin = 1 THEN
            LEAVE item_loop;
        END IF;

        SET v_precio = NULL;
        SELECT precio_venta INTO v_precio
          FROM producto
         WHERE id_producto = v_id_producto AND estado = 'activo';

        IF v_precio IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'VENTA_PRODUCTO_INACTIVO: Un producto de la venta no existe o esta inactivo.';
        END IF;

        SET v_pendiente = v_cantidad;

        -- Despacho FEFO: se consumen los lotes por vencimiento mas proximo,
        -- pudiendo cubrir una linea con varios lotes.
        lote_loop: WHILE v_pendiente > 0 DO
            SET v_id_existencia = NULL;
            SET v_id_lote       = NULL;
            SET v_id_bodega     = NULL;
            SET v_stock         = NULL;

            SELECT e.id_existencia, e.id_lote, e.id_bodega, e.cantidad_disponible
              INTO v_id_existencia, v_id_lote, v_id_bodega, v_stock
              FROM existencia e
              LEFT JOIN lote l ON l.id_lote = e.id_lote
             WHERE e.id_producto = v_id_producto
               AND e.cantidad_disponible > 0
               AND (l.id_lote IS NULL OR l.estado = 'disponible')
             ORDER BY l.fecha_vencimiento IS NULL, l.fecha_vencimiento, e.id_existencia
             LIMIT 1
             FOR UPDATE;

            IF v_id_existencia IS NULL THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'VENTA_EXISTENCIA_INSUFICIENTE: Existencia insuficiente para completar la venta.';
            END IF;

            SET v_toma  = LEAST(v_stock, v_pendiente);
            SET v_stock = v_stock - v_toma;

            UPDATE existencia
               SET cantidad_disponible = v_stock,
                   fecha_actualizacion = CURRENT_TIMESTAMP
             WHERE id_existencia = v_id_existencia;

            INSERT INTO detalle_venta (id_venta, id_producto, id_lote, cantidad, precio_unitario)
            VALUES (p_id_venta, v_id_producto, v_id_lote, v_toma, v_precio);

            INSERT INTO movimiento_inventario (
                id_tipo_movimiento, id_producto, id_lote, id_bodega,
                cantidad, saldo_posterior, id_usuario, id_venta
            ) VALUES (
                v_tipo_movimiento, v_id_producto, v_id_lote, v_id_bodega,
                v_toma, v_stock, p_id_usuario, p_id_venta
            );

            IF v_id_lote IS NOT NULL AND v_stock = 0 THEN
                UPDATE lote SET estado = 'agotado'
                 WHERE id_lote = v_id_lote
                   AND NOT EXISTS (
                        SELECT 1 FROM existencia e2
                         WHERE e2.id_lote = v_id_lote AND e2.cantidad_disponible > 0
                   );
            END IF;

            SET v_pendiente = v_pendiente - v_toma;
        END WHILE lote_loop;
    END LOOP item_loop;

    CLOSE cur_items;

    SET v_subtotal = fn_calcular_total_venta(p_id_venta);

    IF v_descuento > v_subtotal THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'VENTA_DESCUENTO_EXCEDE_SUBTOTAL: El descuento no puede superar el subtotal de la venta.';
    END IF;

    UPDATE venta
       SET subtotal  = v_subtotal,
           descuento = v_descuento,
           id_usuario_autoriza_descuento = IF(v_descuento > 0, p_id_usuario_autoriza_descuento, NULL),
           justificacion_descuento       = IF(v_descuento > 0, p_justificacion_descuento, NULL),
           estado    = 'completada'
     WHERE id_venta = p_id_venta;

    INSERT INTO documento_fel (
        id_venta, tipo_documento, nit_receptor, nombre_receptor,
        monto_gravable, monto_impuesto, monto_total, estado
    ) VALUES (
        p_id_venta, 'factura',
        COALESCE(p_nit_receptor, 'CF'),
        COALESCE(p_nombre_receptor, 'Consumidor Final'),
        ROUND((v_subtotal - v_descuento) / (1 + v_tasa_iva), 2),
        ROUND((v_subtotal - v_descuento) - ((v_subtotal - v_descuento) / (1 + v_tasa_iva)), 2),
        v_subtotal - v_descuento,
        'pendiente'
    );

    SET p_id_documento_fel = LAST_INSERT_ID();

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_anular_venta$$
-- Anula una venta conservando su historial: devuelve la existencia de cada
-- linea al lote y bodega de donde salio, asienta el movimiento de devolucion
-- y marca la venta como anulada. Solo el rol Administrador puede ejecutarla.
--
-- Si el DTE aun no fue certificado, el documento queda anulado. Si ya fue
-- certificado, se deja intacto: la anulacion ante la SAT la gestiona la
-- capa de aplicacion mediante nota de credito.
CREATE PROCEDURE sp_anular_venta(
    IN p_id_venta                BIGINT UNSIGNED,
    IN p_id_usuario_solicitante  INT UNSIGNED,
    IN p_motivo                  VARCHAR(255)
)
BEGIN
    DECLARE v_estado          VARCHAR(20) DEFAULT NULL;
    DECLARE v_tipo_devolucion TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_fin             INT DEFAULT 0;
    DECLARE v_id_producto     INT UNSIGNED;
    DECLARE v_id_lote         INT UNSIGNED;
    DECLARE v_id_bodega       INT UNSIGNED;
    DECLARE v_cantidad        DECIMAL(10,3);
    DECLARE v_id_existencia   INT UNSIGNED;
    DECLARE v_saldo           DECIMAL(10,3);

    DECLARE cur_mov CURSOR FOR
        SELECT mi.id_producto, mi.id_lote, mi.id_bodega, mi.cantidad
          FROM movimiento_inventario mi
          INNER JOIN tipo_movimiento tm
                  ON tm.id_tipo_movimiento = mi.id_tipo_movimiento
         WHERE mi.id_venta = p_id_venta
           AND tm.efecto = 'resta';

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = 1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF COALESCE(fn_rol_usuario(p_id_usuario_solicitante), '') <> 'Administrador' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'VENTA_ANULACION_NO_AUTORIZADA: Solo un usuario con rol Administrador puede anular una venta.';
    END IF;

    IF p_motivo IS NULL OR TRIM(p_motivo) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'VENTA_ANULACION_SIN_MOTIVO: La anulacion requiere un motivo.';
    END IF;

    SELECT id_tipo_movimiento INTO v_tipo_devolucion
      FROM tipo_movimiento
     WHERE nombre = 'devolucion' AND efecto = 'suma'
     LIMIT 1;

    IF v_tipo_devolucion IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'VENTA_TIPO_DEVOLUCION_FALTANTE: Falta el tipo de movimiento "devolucion" con efecto "suma" en el catalogo.';
    END IF;

    -- La transaccion abre antes del bloqueo: de otro modo el FOR UPDATE se
    -- libera de inmediato y dos anulaciones simultaneas devolverian dos veces.
    START TRANSACTION;

    SELECT estado INTO v_estado
      FROM venta
     WHERE id_venta = p_id_venta
     FOR UPDATE;

    IF v_estado IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'VENTA_INEXISTENTE: La venta indicada no existe.';
    END IF;

    IF v_estado = 'anulada' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'VENTA_YA_ANULADA: La venta ya se encuentra anulada.';
    END IF;

    OPEN cur_mov;

    mov_loop: LOOP
        FETCH cur_mov INTO v_id_producto, v_id_lote, v_id_bodega, v_cantidad;
        IF v_fin = 1 THEN
            LEAVE mov_loop;
        END IF;

        SET v_id_existencia = NULL;
        SET v_saldo = NULL;

        SELECT id_existencia, cantidad_disponible
          INTO v_id_existencia, v_saldo
          FROM existencia
         WHERE id_producto = v_id_producto
           AND id_bodega   = v_id_bodega
           AND COALESCE(id_lote, 0) = COALESCE(v_id_lote, 0)
         FOR UPDATE;

        -- Si la consulta anterior no encontro fila, el manejador de NOT FOUND
        -- marco v_fin = 1 como si el cursor hubiera terminado. Se restablece:
        -- el ciclo solo debe terminar cuando el FETCH se agote.
        SET v_fin = 0;

        IF v_id_existencia IS NULL THEN
            INSERT INTO existencia (id_producto, id_lote, id_bodega, cantidad_disponible)
            VALUES (v_id_producto, v_id_lote, v_id_bodega, v_cantidad);
            SET v_saldo = v_cantidad;
        ELSE
            SET v_saldo = v_saldo + v_cantidad;
            UPDATE existencia
               SET cantidad_disponible = v_saldo,
                   fecha_actualizacion = CURRENT_TIMESTAMP
             WHERE id_existencia = v_id_existencia;
        END IF;

        INSERT INTO movimiento_inventario (
            id_tipo_movimiento, id_producto, id_lote, id_bodega,
            cantidad, saldo_posterior, id_usuario, motivo, id_venta
        ) VALUES (
            v_tipo_devolucion, v_id_producto, v_id_lote, v_id_bodega,
            v_cantidad, v_saldo, p_id_usuario_solicitante,
            CONCAT('Devolucion por anulacion: ', p_motivo), p_id_venta
        );

        IF v_id_lote IS NOT NULL THEN
            UPDATE lote SET estado = 'disponible'
             WHERE id_lote = v_id_lote
               AND estado  = 'agotado'
               AND fecha_vencimiento >= CURDATE();
        END IF;
    END LOOP mov_loop;

    CLOSE cur_mov;

    UPDATE venta
       SET estado           = 'anulada',
           fecha_anulacion  = CURRENT_TIMESTAMP,
           id_usuario_anula = p_id_usuario_solicitante,
           motivo_anulacion = p_motivo
     WHERE id_venta = p_id_venta;

    UPDATE documento_fel
       SET estado = 'anulado'
     WHERE id_venta = p_id_venta
       AND estado   = 'pendiente';

    COMMIT;
END$$

DROP PROCEDURE IF EXISTS sp_registrar_cliente$$
-- Alta de cliente de la tienda en linea o del mostrador.
CREATE PROCEDURE sp_registrar_cliente(
    IN  p_nombre    VARCHAR(60),
    IN  p_apellido  VARCHAR(60),
    IN  p_nit       VARCHAR(15),
    IN  p_correo    VARCHAR(120),
    IN  p_telefono  VARCHAR(20),
    IN  p_pais      VARCHAR(60),
    IN  p_origen    VARCHAR(20),
    OUT p_id_cliente INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'CLIENTE_NOMBRE_OBLIGATORIO: El nombre del cliente es obligatorio.';
    END IF;

    IF p_origen IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'CLIENTE_ORIGEN_OBLIGATORIO: Debe indicarse el origen del cliente.';
    END IF;

    START TRANSACTION;

    IF p_correo IS NOT NULL
       AND EXISTS (SELECT 1 FROM cliente WHERE correo = p_correo FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'CLIENTE_CORREO_DUPLICADO: Ya existe un cliente registrado con ese correo.';
    END IF;

    INSERT INTO cliente (nombre, apellido, nit, correo, telefono, pais, origen)
    VALUES (p_nombre, p_apellido, p_nit, p_correo, p_telefono, p_pais, p_origen);

    SET p_id_cliente = LAST_INSERT_ID();

    COMMIT;
END$$

DELIMITER ;


-- ============================================================================
-- VISTAS
-- ============================================================================

DROP VIEW IF EXISTS vw_existencias_actuales;
CREATE VIEW vw_existencias_actuales AS
SELECT
    e.id_existencia,
    p.id_producto,
    p.codigo            AS codigo_producto,
    p.nombre            AS producto,
    c.nombre            AS categoria,
    b.id_bodega,
    b.nombre            AS bodega,
    l.id_lote,
    l.codigo_lote,
    l.fecha_produccion,
    l.fecha_vencimiento,
    e.cantidad_disponible,
    p.stock_minimo,
    e.fecha_actualizacion,
    CASE WHEN e.cantidad_disponible <= p.stock_minimo
         THEN 'STOCK_BAJO' ELSE 'DISPONIBLE' END AS estado_stock
FROM existencia e
INNER JOIN producto  p ON p.id_producto  = e.id_producto
INNER JOIN categoria c ON c.id_categoria = p.id_categoria
INNER JOIN bodega    b ON b.id_bodega    = e.id_bodega
LEFT  JOIN lote      l ON l.id_lote      = e.id_lote;

DROP VIEW IF EXISTS vw_stock_bajo;
CREATE VIEW vw_stock_bajo AS
SELECT
    p.id_producto,
    p.codigo AS codigo_producto,
    p.nombre AS producto,
    c.nombre AS categoria,
    p.stock_minimo,
    COALESCE(SUM(e.cantidad_disponible), 0) AS existencia_total,
    p.stock_minimo - COALESCE(SUM(e.cantidad_disponible), 0) AS faltante_para_minimo
FROM producto p
INNER JOIN categoria c ON c.id_categoria = p.id_categoria
LEFT  JOIN existencia e ON e.id_producto = p.id_producto
WHERE p.estado = 'activo'
GROUP BY p.id_producto, p.codigo, p.nombre, c.nombre, p.stock_minimo
HAVING COALESCE(SUM(e.cantidad_disponible), 0) <= p.stock_minimo;

DROP VIEW IF EXISTS vw_lotes_proximos_vencer;
CREATE VIEW vw_lotes_proximos_vencer AS
SELECT
    l.id_lote,
    l.codigo_lote,
    p.id_producto,
    p.codigo AS codigo_producto,
    p.nombre AS producto,
    l.fecha_produccion,
    l.fecha_vencimiento,
    DATEDIFF(l.fecha_vencimiento, CURDATE()) AS dias_para_vencer,
    p.dias_alerta_vencimiento,
    COALESCE(SUM(e.cantidad_disponible), 0) AS existencia_lote,
    l.estado
FROM lote l
INNER JOIN producto p ON p.id_producto = l.id_producto
LEFT  JOIN existencia e ON e.id_lote = l.id_lote
WHERE l.estado = 'disponible'
  AND l.fecha_vencimiento >= CURDATE()
  AND l.fecha_vencimiento <= DATE_ADD(CURDATE(), INTERVAL p.dias_alerta_vencimiento DAY)
GROUP BY l.id_lote, l.codigo_lote, p.id_producto, p.codigo, p.nombre,
         l.fecha_produccion, l.fecha_vencimiento, p.dias_alerta_vencimiento, l.estado;

DROP VIEW IF EXISTS vw_ventas_detalladas;
CREATE VIEW vw_ventas_detalladas AS
SELECT
    v.id_venta,
    v.numero_venta,
    v.fecha_hora,
    v.canal,
    v.estado AS estado_venta,
    COALESCE(CONCAT(c.nombre, ' ', COALESCE(c.apellido, '')), 'Consumidor Final') AS cliente,
    CONCAT(u.nombre, ' ', u.apellido) AS vendedor,
    mp.nombre AS metodo_pago,
    p.codigo  AS codigo_producto,
    p.nombre  AS producto,
    l.codigo_lote,
    dv.cantidad,
    dv.precio_unitario,
    dv.subtotal_linea,
    v.subtotal,
    v.descuento,
    v.total
FROM venta v
INNER JOIN usuario       u  ON u.id_usuario      = v.id_usuario
INNER JOIN metodo_pago   mp ON mp.id_metodo_pago = v.id_metodo_pago
INNER JOIN detalle_venta dv ON dv.id_venta       = v.id_venta
INNER JOIN producto      p  ON p.id_producto     = dv.id_producto
LEFT  JOIN cliente       c  ON c.id_cliente      = v.id_cliente
LEFT  JOIN lote          l  ON l.id_lote         = dv.id_lote;

DROP VIEW IF EXISTS vw_resumen_ventas_diarias;
CREATE VIEW vw_resumen_ventas_diarias AS
SELECT
    DATE(v.fecha_hora)   AS fecha,
    v.canal,
    COUNT(*)             AS cantidad_ventas,
    SUM(v.subtotal)      AS subtotal_acumulado,
    SUM(v.descuento)     AS descuentos_acumulados,
    SUM(v.total)         AS total_vendido
FROM venta v
WHERE v.estado = 'completada'
GROUP BY DATE(v.fecha_hora), v.canal;

DROP VIEW IF EXISTS vw_pedidos_pendientes;
CREATE VIEW vw_pedidos_pendientes AS
SELECT
    p.id_pedido,
    p.numero_pedido,
    p.fecha_pedido,
    p.estado,
    CONCAT(c.nombre, ' ', COALESCE(c.apellido, '')) AS cliente,
    c.telefono,
    de.direccion,
    z.departamento,
    z.municipio,
    mp.nombre AS metodo_pago,
    p.subtotal,
    p.costo_envio,
    p.total,
    p.fecha_verificacion_pago
FROM pedido p
INNER JOIN cliente           c  ON c.id_cliente      = p.id_cliente
INNER JOIN direccion_entrega de ON de.id_direccion   = p.id_direccion
INNER JOIN zona_cobertura    z  ON z.id_zona         = de.id_zona
INNER JOIN metodo_pago       mp ON mp.id_metodo_pago = p.id_metodo_pago
WHERE p.estado IN ('pendiente_pago','pago_verificado','en_preparacion','enviado');

DROP VIEW IF EXISTS vw_envios_pendientes;
CREATE VIEW vw_envios_pendientes AS
SELECT
    e.id_envio,
    p.numero_pedido,
    t.nombre AS transportista,
    t.tipo   AS tipo_transportista,
    e.numero_guia,
    e.fecha_despacho,
    e.fecha_entrega_estimada,
    e.estado,
    z.departamento,
    z.municipio,
    CONCAT(u.nombre, ' ', u.apellido) AS usuario_despacha,
    e.observacion
FROM envio e
INNER JOIN pedido            p  ON p.id_pedido       = e.id_pedido
INNER JOIN direccion_entrega de ON de.id_direccion   = p.id_direccion
INNER JOIN zona_cobertura    z  ON z.id_zona         = de.id_zona
INNER JOIN transportista     t  ON t.id_transportista = e.id_transportista
INNER JOIN usuario           u  ON u.id_usuario      = e.id_usuario_despacha
WHERE e.estado IN ('preparado','en_transito');

DROP VIEW IF EXISTS vw_estado_fel;
CREATE VIEW vw_estado_fel AS
SELECT
    df.id_documento_fel,
    v.numero_venta,
    v.fecha_hora AS fecha_venta,
    df.tipo_documento,
    df.nit_receptor,
    df.nombre_receptor,
    df.serie,
    df.numero_dte,
    df.numero_autorizacion,
    df.fecha_certificacion,
    df.monto_gravable,
    df.monto_impuesto,
    df.monto_total,
    df.estado,
    df.intentos,
    df.mensaje_error,
    df.fecha_registro
FROM documento_fel df
INNER JOIN venta v ON v.id_venta = df.id_venta;

DROP VIEW IF EXISTS vw_suscripciones_activas;
CREATE VIEW vw_suscripciones_activas AS
SELECT
    s.id_suscripcion,
    CONCAT(c.nombre, ' ', COALESCE(c.apellido, '')) AS cliente,
    c.correo,
    c.telefono,
    ps.nombre       AS plan,
    ps.periodicidad,
    s.precio_congelado,
    s.fecha_inicio,
    s.fecha_proxima_entrega,
    DATEDIFF(s.fecha_proxima_entrega, CURDATE()) AS dias_para_entrega,
    de.direccion,
    z.departamento,
    z.municipio,
    s.estado
FROM suscripcion s
INNER JOIN cliente           c  ON c.id_cliente    = s.id_cliente
INNER JOIN plan_suscripcion  ps ON ps.id_plan      = s.id_plan
INNER JOIN direccion_entrega de ON de.id_direccion = s.id_direccion
INNER JOIN zona_cobertura    z  ON z.id_zona       = de.id_zona
WHERE s.estado = 'activa';

DROP VIEW IF EXISTS vw_clientes_compras;
CREATE VIEW vw_clientes_compras AS
SELECT
    c.id_cliente,
    CONCAT(c.nombre, ' ', COALESCE(c.apellido, '')) AS cliente,
    c.correo,
    c.telefono,
    c.origen,
    COUNT(v.id_venta)            AS cantidad_compras,
    COALESCE(SUM(v.total), 0)    AS total_comprado,
    MAX(v.fecha_hora)            AS ultima_compra
FROM cliente c
LEFT JOIN venta v ON v.id_cliente = c.id_cliente AND v.estado = 'completada'
GROUP BY c.id_cliente, c.nombre, c.apellido, c.correo, c.telefono, c.origen;
