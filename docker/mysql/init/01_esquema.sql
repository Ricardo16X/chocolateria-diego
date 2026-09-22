-- ============================================================================
-- Artesanal Chocolate Diego — Entrega 8
-- 01_esquema.sql — Estructura de la base de datos
--
-- 32 tablas · 274 columnas · 56 llaves foraneas · 28 restricciones CHECK
-- Motor InnoDB · utf8mb4 · MySQL 8.0
--
-- La base de datos NO se crea aqui: la crea el contenedor mediante la
-- variable de entorno MYSQL_DATABASE, y el punto de entrada de MySQL
-- ejecuta este archivo ya posicionado en ella.
-- ============================================================================


CREATE TABLE rol (
  id_rol TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(40) NOT NULL,
  descripcion VARCHAR(255) NULL,
  estado ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
  PRIMARY KEY (id_rol),
  UNIQUE KEY uq_rol_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE permiso (
  id_permiso SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  modulo VARCHAR(40) NOT NULL,
  accion VARCHAR(40) NOT NULL,
  descripcion VARCHAR(255) NULL,
  PRIMARY KEY (id_permiso),
  UNIQUE KEY uq_permiso (modulo, accion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE rol_permiso (
  id_rol TINYINT UNSIGNED NOT NULL,
  id_permiso SMALLINT UNSIGNED NOT NULL,
  fecha_asignacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_rol, id_permiso),
  CONSTRAINT fk_rp_rol FOREIGN KEY (id_rol) REFERENCES rol(id_rol) ON DELETE CASCADE,
  CONSTRAINT fk_rp_permiso FOREIGN KEY (id_permiso) REFERENCES permiso(id_permiso) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE usuario (
  id_usuario INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_rol TINYINT UNSIGNED NOT NULL,
  nombre VARCHAR(60) NOT NULL,
  apellido VARCHAR(60) NOT NULL,
  nombre_usuario VARCHAR(40) NOT NULL,
  correo VARCHAR(120) NOT NULL,
  contrasena_hash VARCHAR(255) NOT NULL,
  estado ENUM('activo','inactivo','bloqueado') NOT NULL DEFAULT 'activo',
  intentos_fallidos TINYINT UNSIGNED NOT NULL DEFAULT 0,
  ultimo_acceso DATETIME NULL,
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_usuario),
  UNIQUE KEY uq_usuario_nombre (nombre_usuario),
  UNIQUE KEY uq_usuario_correo (correo),
  CONSTRAINT fk_usuario_rol FOREIGN KEY (id_rol) REFERENCES rol(id_rol) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE bitacora (
  id_bitacora BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario INT UNSIGNED NULL,
  usuario_intento VARCHAR(40) NULL,
  evento ENUM('inicio_sesion','intento_fallido','cierre_sesion','venta','anulacion','ajuste_inventario','cambio_precio','gestion_usuario') NOT NULL,
  tabla_afectada VARCHAR(64) NULL,
  id_registro BIGINT UNSIGNED NULL,
  descripcion VARCHAR(255) NULL,
  direccion_ip VARCHAR(45) NULL,
  fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_bitacora),
  KEY ix_bitacora_fecha (fecha_hora),
  CONSTRAINT fk_bitacora_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE parametro_sistema (
  id_parametro SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  clave VARCHAR(60) NOT NULL,
  valor VARCHAR(255) NOT NULL,
  tipo_dato ENUM('texto','numero','booleano','fecha') NOT NULL,
  descripcion VARCHAR(255) NULL,
  editable BOOLEAN NOT NULL DEFAULT TRUE,
  id_usuario_modifica INT UNSIGNED NULL,
  fecha_modificacion DATETIME NULL,
  PRIMARY KEY (id_parametro),
  UNIQUE KEY uq_parametro_clave (clave),
  CONSTRAINT fk_parametro_usuario FOREIGN KEY (id_usuario_modifica) REFERENCES usuario(id_usuario) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE categoria (
  id_categoria INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(60) NOT NULL,
  descripcion VARCHAR(255) NULL,
  estado ENUM('activa','inactiva') NOT NULL DEFAULT 'activa',
  PRIMARY KEY (id_categoria),
  UNIQUE KEY uq_categoria_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE producto (
  id_producto INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_categoria INT UNSIGNED NOT NULL,
  codigo VARCHAR(20) NOT NULL,
  nombre VARCHAR(120) NOT NULL,
  descripcion TEXT NULL,
  porcentaje_cacao TINYINT UNSIGNED NULL,
  unidad_medida ENUM('unidad','gramo','libra') NOT NULL DEFAULT 'unidad',
  precio_venta DECIMAL(10,2) NOT NULL,
  costo_referencia DECIMAL(10,2) NULL,
  stock_minimo DECIMAL(10,3) NOT NULL DEFAULT 0,
  dias_alerta_vencimiento SMALLINT UNSIGNED NOT NULL DEFAULT 30,
  maneja_lote BOOLEAN NOT NULL DEFAULT TRUE,
  visible_tienda BOOLEAN NOT NULL DEFAULT TRUE,
  imagen_url VARCHAR(255) NULL,
  estado ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_producto),
  UNIQUE KEY uq_producto_codigo (codigo),
  KEY ix_producto_categoria (id_categoria),
  CONSTRAINT chk_producto_precio CHECK (precio_venta > 0),
  CONSTRAINT chk_producto_cacao CHECK (porcentaje_cacao IS NULL OR porcentaje_cacao BETWEEN 0 AND 100),
  CONSTRAINT chk_producto_stockmin CHECK (stock_minimo >= 0),
  CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE historial_precio (
  id_historial_precio INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_producto INT UNSIGNED NOT NULL,
  precio_anterior DECIMAL(10,2) NOT NULL,
  precio_nuevo DECIMAL(10,2) NOT NULL,
  id_usuario INT UNSIGNED NOT NULL,
  motivo VARCHAR(255) NULL,
  fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_historial_precio),
  KEY ix_hp_producto (id_producto, fecha_cambio),
  CONSTRAINT fk_hp_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT,
  CONSTRAINT fk_hp_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE bodega (
  id_bodega INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(60) NOT NULL,
  tipo ENUM('sala_venta','bodega','produccion') NOT NULL,
  direccion VARCHAR(200) NULL,
  estado ENUM('activa','inactiva') NOT NULL DEFAULT 'activa',
  PRIMARY KEY (id_bodega),
  UNIQUE KEY uq_bodega_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE lote (
  id_lote INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_producto INT UNSIGNED NOT NULL,
  codigo_lote VARCHAR(30) NOT NULL,
  fecha_produccion DATE NOT NULL,
  fecha_vencimiento DATE NOT NULL,
  cantidad_inicial DECIMAL(10,3) NOT NULL,
  estado ENUM('disponible','agotado','vencido','retirado') NOT NULL DEFAULT 'disponible',
  PRIMARY KEY (id_lote),
  UNIQUE KEY uq_lote_producto (id_producto, codigo_lote),
  KEY ix_lote_vencimiento (fecha_vencimiento, estado),
  CONSTRAINT chk_lote_cantidad CHECK (cantidad_inicial > 0),
  CONSTRAINT chk_lote_fechas CHECK (fecha_vencimiento > fecha_produccion),
  CONSTRAINT fk_lote_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE existencia (
  id_existencia INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_producto INT UNSIGNED NOT NULL,
  id_lote INT UNSIGNED NULL,
  id_bodega INT UNSIGNED NOT NULL,
  cantidad_disponible DECIMAL(10,3) NOT NULL DEFAULT 0,
  fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  lote_clave INT UNSIGNED GENERATED ALWAYS AS (COALESCE(id_lote, 0)) STORED,
  PRIMARY KEY (id_existencia),
  UNIQUE KEY uq_existencia (id_producto, lote_clave, id_bodega),
  KEY ix_existencia_lote (id_lote),
  KEY ix_existencia_bodega (id_bodega),
  CONSTRAINT chk_existencia_cantidad CHECK (cantidad_disponible >= 0),
  CONSTRAINT fk_existencia_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT,
  CONSTRAINT fk_existencia_lote FOREIGN KEY (id_lote) REFERENCES lote(id_lote) ON DELETE RESTRICT,
  CONSTRAINT fk_existencia_bodega FOREIGN KEY (id_bodega) REFERENCES bodega(id_bodega) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE tipo_movimiento (
  id_tipo_movimiento TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(40) NOT NULL,
  efecto ENUM('suma','resta') NOT NULL,
  requiere_autorizacion BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (id_tipo_movimiento),
  UNIQUE KEY uq_tipomov_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE metodo_pago (
  id_metodo_pago TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(40) NOT NULL,
  requiere_comprobante BOOLEAN NOT NULL DEFAULT FALSE,
  aplica_cambio BOOLEAN NOT NULL DEFAULT FALSE,
  estado ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
  PRIMARY KEY (id_metodo_pago),
  UNIQUE KEY uq_metodopago_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE zona_cobertura (
  id_zona SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  departamento VARCHAR(60) NOT NULL,
  municipio VARCHAR(60) NOT NULL,
  costo_envio DECIMAL(10,2) NOT NULL,
  dias_estimados TINYINT UNSIGNED NOT NULL,
  estado ENUM('activa','inactiva') NOT NULL DEFAULT 'activa',
  PRIMARY KEY (id_zona),
  UNIQUE KEY uq_zona (departamento, municipio),
  CONSTRAINT chk_zona_costo CHECK (costo_envio >= 0),
  CONSTRAINT chk_zona_dias CHECK (dias_estimados > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE transportista (
  id_transportista TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(60) NOT NULL,
  tipo ENUM('propio','externo') NOT NULL,
  telefono_contacto VARCHAR(20) NULL,
  estado ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
  PRIMARY KEY (id_transportista),
  UNIQUE KEY uq_transportista_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cliente (
  id_cliente INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(60) NOT NULL,
  apellido VARCHAR(60) NULL,
  nit VARCHAR(15) NULL,
  correo VARCHAR(120) NULL,
  telefono VARCHAR(20) NULL,
  pais VARCHAR(60) NULL,
  origen ENUM('tienda_fisica','tienda_linea','whatsapp','red_social') NOT NULL,
  contrasena_hash VARCHAR(255) NULL,
  acepta_notificaciones BOOLEAN NOT NULL DEFAULT FALSE,
  estado ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
  fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_cliente),
  UNIQUE KEY uq_cliente_correo (correo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE direccion_entrega (
  id_direccion INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_cliente INT UNSIGNED NOT NULL,
  id_zona SMALLINT UNSIGNED NOT NULL,
  direccion VARCHAR(255) NOT NULL,
  referencia VARCHAR(255) NULL,
  nombre_contacto VARCHAR(120) NOT NULL,
  telefono_contacto VARCHAR(20) NOT NULL,
  predeterminada BOOLEAN NOT NULL DEFAULT FALSE,
  estado ENUM('activa','inactiva') NOT NULL DEFAULT 'activa',
  predeterminada_clave INT UNSIGNED GENERATED ALWAYS AS (IF(predeterminada, id_cliente, NULL)) STORED,
  PRIMARY KEY (id_direccion),
  UNIQUE KEY uq_direccion_predeterminada (predeterminada_clave),
  KEY ix_direccion_cliente (id_cliente),
  CONSTRAINT fk_direccion_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
  CONSTRAINT fk_direccion_zona FOREIGN KEY (id_zona) REFERENCES zona_cobertura(id_zona) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE plan_suscripcion (
  id_plan TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(60) NOT NULL,
  descripcion VARCHAR(255) NULL,
  periodicidad ENUM('mensual','bimestral','trimestral') NOT NULL,
  precio DECIMAL(10,2) NOT NULL,
  estado ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
  PRIMARY KEY (id_plan),
  UNIQUE KEY uq_plan_nombre (nombre),
  CONSTRAINT chk_plan_precio CHECK (precio > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE suscripcion (
  id_suscripcion INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_cliente INT UNSIGNED NOT NULL,
  id_plan TINYINT UNSIGNED NOT NULL,
  id_direccion INT UNSIGNED NOT NULL,
  precio_congelado DECIMAL(10,2) NOT NULL,
  fecha_inicio DATE NOT NULL,
  fecha_proxima_entrega DATE NOT NULL,
  fecha_fin DATE NULL,
  estado ENUM('activa','pausada','cancelada','vencida') NOT NULL DEFAULT 'activa',
  motivo_cancelacion VARCHAR(255) NULL,
  PRIMARY KEY (id_suscripcion),
  KEY ix_suscripcion_proceso (estado, fecha_proxima_entrega),
  KEY ix_suscripcion_cliente (id_cliente),
  CONSTRAINT chk_suscripcion_precio CHECK (precio_congelado > 0),
  CONSTRAINT fk_suscripcion_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
  CONSTRAINT fk_suscripcion_plan FOREIGN KEY (id_plan) REFERENCES plan_suscripcion(id_plan) ON DELETE RESTRICT,
  CONSTRAINT fk_suscripcion_direccion FOREIGN KEY (id_direccion) REFERENCES direccion_entrega(id_direccion) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE carrito (
  id_carrito INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_cliente INT UNSIGNED NULL,
  token_sesion VARCHAR(64) NOT NULL,
  estado ENUM('activo','convertido','abandonado') NOT NULL DEFAULT 'activo',
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id_carrito),
  UNIQUE KEY uq_carrito_token (token_sesion),
  KEY ix_carrito_cliente (id_cliente),
  CONSTRAINT fk_carrito_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE detalle_carrito (
  id_detalle_carrito INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_carrito INT UNSIGNED NOT NULL,
  id_producto INT UNSIGNED NOT NULL,
  cantidad DECIMAL(10,3) NOT NULL,
  PRIMARY KEY (id_detalle_carrito),
  UNIQUE KEY uq_detalle_carrito (id_carrito, id_producto),
  KEY ix_dc_producto (id_producto),
  CONSTRAINT chk_dc_cantidad CHECK (cantidad > 0),
  CONSTRAINT fk_dc_carrito FOREIGN KEY (id_carrito) REFERENCES carrito(id_carrito) ON DELETE CASCADE,
  CONSTRAINT fk_dc_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pedido (
  id_pedido BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  numero_pedido VARCHAR(20) NOT NULL,
  id_cliente INT UNSIGNED NOT NULL,
  id_direccion INT UNSIGNED NOT NULL,
  id_metodo_pago TINYINT UNSIGNED NOT NULL,
  id_suscripcion INT UNSIGNED NULL,
  fecha_pedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subtotal DECIMAL(10,2) NOT NULL,
  costo_envio DECIMAL(10,2) NOT NULL DEFAULT 0,
  total DECIMAL(10,2) GENERATED ALWAYS AS (subtotal + costo_envio) STORED,
  estado ENUM('pendiente_pago','pago_verificado','en_preparacion','enviado','entregado','cancelado') NOT NULL DEFAULT 'pendiente_pago',
  comprobante_pago_url VARCHAR(255) NULL,
  fecha_verificacion_pago DATETIME NULL,
  id_usuario_verifica INT UNSIGNED NULL,
  fecha_cancelacion DATETIME NULL,
  motivo_cancelacion VARCHAR(255) NULL,
  PRIMARY KEY (id_pedido),
  UNIQUE KEY uq_pedido_numero (numero_pedido),
  KEY ix_pedido_estado (estado, fecha_pedido),
  KEY ix_pedido_cliente (id_cliente),
  KEY ix_pedido_direccion (id_direccion),
  KEY ix_pedido_metodo (id_metodo_pago),
  KEY ix_pedido_suscripcion (id_suscripcion),
  KEY ix_pedido_verifica (id_usuario_verifica),
  CONSTRAINT chk_pedido_subtotal CHECK (subtotal >= 0),
  CONSTRAINT chk_pedido_envio CHECK (costo_envio >= 0),
  CONSTRAINT chk_pago_verificado CHECK (fecha_verificacion_pago IS NULL OR id_usuario_verifica IS NOT NULL),
  CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
  CONSTRAINT fk_pedido_direccion FOREIGN KEY (id_direccion) REFERENCES direccion_entrega(id_direccion) ON DELETE RESTRICT,
  CONSTRAINT fk_pedido_metodo FOREIGN KEY (id_metodo_pago) REFERENCES metodo_pago(id_metodo_pago) ON DELETE RESTRICT,
  CONSTRAINT fk_pedido_suscripcion FOREIGN KEY (id_suscripcion) REFERENCES suscripcion(id_suscripcion) ON DELETE SET NULL,
  CONSTRAINT fk_pedido_usuario FOREIGN KEY (id_usuario_verifica) REFERENCES usuario(id_usuario) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE detalle_pedido (
  id_detalle_pedido BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_pedido BIGINT UNSIGNED NOT NULL,
  id_producto INT UNSIGNED NOT NULL,
  cantidad DECIMAL(10,3) NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  subtotal_linea DECIMAL(10,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
  PRIMARY KEY (id_detalle_pedido),
  KEY ix_dp_pedido (id_pedido),
  KEY ix_dp_producto (id_producto),
  CONSTRAINT chk_dp_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_dp_precio CHECK (precio_unitario > 0),
  CONSTRAINT fk_dp_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido) ON DELETE CASCADE,
  CONSTRAINT fk_dp_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE reserva_existencia (
  id_reserva BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_pedido BIGINT UNSIGNED NOT NULL,
  id_producto INT UNSIGNED NOT NULL,
  id_bodega INT UNSIGNED NOT NULL,
  cantidad DECIMAL(10,3) NOT NULL,
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_expiracion DATETIME NOT NULL,
  estado ENUM('activa','consumida','expirada','cancelada') NOT NULL DEFAULT 'activa',
  fecha_liberacion DATETIME NULL,
  PRIMARY KEY (id_reserva),
  KEY ix_reserva_proceso (estado, fecha_expiracion),
  KEY ix_reserva_disponibilidad (id_producto, estado),
  KEY ix_reserva_pedido (id_pedido),
  KEY ix_reserva_bodega (id_bodega),
  CONSTRAINT chk_reserva_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_reserva_ventana CHECK (fecha_expiracion > fecha_creacion),
  CONSTRAINT fk_reserva_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido) ON DELETE CASCADE,
  CONSTRAINT fk_reserva_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT,
  CONSTRAINT fk_reserva_bodega FOREIGN KEY (id_bodega) REFERENCES bodega(id_bodega) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE turno_caja (
  id_turno INT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_usuario INT UNSIGNED NOT NULL,
  id_bodega INT UNSIGNED NOT NULL,
  fecha_apertura DATETIME NOT NULL,
  monto_inicial DECIMAL(10,2) NOT NULL DEFAULT 0,
  fecha_cierre DATETIME NULL,
  monto_declarado DECIMAL(10,2) NULL,
  monto_sistema DECIMAL(10,2) NULL,
  estado ENUM('abierto','cerrado') NOT NULL DEFAULT 'abierto',
  PRIMARY KEY (id_turno),
  KEY ix_turno_usuario (id_usuario),
  KEY ix_turno_bodega (id_bodega),
  CONSTRAINT chk_turno_inicial CHECK (monto_inicial >= 0),
  CONSTRAINT fk_turno_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  CONSTRAINT fk_turno_bodega FOREIGN KEY (id_bodega) REFERENCES bodega(id_bodega) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE venta (
  id_venta BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  numero_venta VARCHAR(20) NOT NULL,
  id_cliente INT UNSIGNED NULL,
  id_usuario INT UNSIGNED NOT NULL,
  id_turno INT UNSIGNED NULL,
  id_metodo_pago TINYINT UNSIGNED NOT NULL,
  id_pedido BIGINT UNSIGNED NULL,
  canal ENUM('presencial','tienda_linea','whatsapp','red_social') NOT NULL DEFAULT 'presencial',
  fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subtotal DECIMAL(10,2) NOT NULL,
  descuento DECIMAL(10,2) NOT NULL DEFAULT 0,
  id_usuario_autoriza_descuento INT UNSIGNED NULL,
  justificacion_descuento VARCHAR(255) NULL,
  total DECIMAL(10,2) GENERATED ALWAYS AS (subtotal - descuento) STORED,
  monto_recibido DECIMAL(10,2) NULL,
  cambio DECIMAL(10,2) NULL,
  estado ENUM('pendiente','completada','anulada') NOT NULL DEFAULT 'pendiente',
  fecha_anulacion DATETIME NULL,
  id_usuario_anula INT UNSIGNED NULL,
  motivo_anulacion VARCHAR(255) NULL,
  PRIMARY KEY (id_venta),
  UNIQUE KEY uq_venta_numero (numero_venta),
  UNIQUE KEY uq_venta_pedido (id_pedido),
  KEY ix_venta_estado (estado, fecha_hora),
  KEY ix_venta_cliente (id_cliente),
  KEY ix_venta_usuario (id_usuario),
  KEY ix_venta_turno (id_turno),
  KEY ix_venta_metodo (id_metodo_pago),
  KEY ix_venta_autoriza (id_usuario_autoriza_descuento),
  KEY ix_venta_anula (id_usuario_anula),
  CONSTRAINT chk_venta_subtotal CHECK (subtotal >= 0),
  CONSTRAINT chk_venta_descuento CHECK (descuento >= 0 AND descuento <= subtotal),
  CONSTRAINT chk_descuento_autorizado CHECK (descuento = 0 OR (id_usuario_autoriza_descuento IS NOT NULL AND justificacion_descuento IS NOT NULL)),
  CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
  CONSTRAINT fk_venta_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  CONSTRAINT fk_venta_turno FOREIGN KEY (id_turno) REFERENCES turno_caja(id_turno) ON DELETE RESTRICT,
  CONSTRAINT fk_venta_metodo FOREIGN KEY (id_metodo_pago) REFERENCES metodo_pago(id_metodo_pago) ON DELETE RESTRICT,
  CONSTRAINT fk_venta_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido) ON DELETE RESTRICT,
  CONSTRAINT fk_venta_autoriza FOREIGN KEY (id_usuario_autoriza_descuento) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  CONSTRAINT fk_venta_anula FOREIGN KEY (id_usuario_anula) REFERENCES usuario(id_usuario) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE detalle_venta (
  id_detalle_venta BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_venta BIGINT UNSIGNED NOT NULL,
  id_producto INT UNSIGNED NOT NULL,
  id_lote INT UNSIGNED NULL,
  cantidad DECIMAL(10,3) NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  subtotal_linea DECIMAL(10,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
  PRIMARY KEY (id_detalle_venta),
  KEY ix_dv_venta (id_venta),
  KEY ix_dv_producto (id_producto),
  KEY ix_dv_lote (id_lote),
  CONSTRAINT chk_dv_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_dv_precio CHECK (precio_unitario > 0),
  CONSTRAINT fk_dv_venta FOREIGN KEY (id_venta) REFERENCES venta(id_venta) ON DELETE CASCADE,
  CONSTRAINT fk_dv_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT,
  CONSTRAINT fk_dv_lote FOREIGN KEY (id_lote) REFERENCES lote(id_lote) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE documento_fel (
  id_documento_fel BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_venta BIGINT UNSIGNED NOT NULL,
  tipo_documento ENUM('factura','nota_credito') NOT NULL DEFAULT 'factura',
  nit_receptor VARCHAR(15) NOT NULL DEFAULT 'CF',
  nombre_receptor VARCHAR(150) NOT NULL DEFAULT 'Consumidor Final',
  serie VARCHAR(20) NULL,
  numero_dte VARCHAR(20) NULL,
  numero_autorizacion VARCHAR(64) NULL,
  fecha_certificacion DATETIME NULL,
  monto_gravable DECIMAL(10,2) NOT NULL,
  monto_impuesto DECIMAL(10,2) NOT NULL,
  monto_total DECIMAL(10,2) NOT NULL,
  estado ENUM('pendiente','certificado','rechazado','anulado') NOT NULL DEFAULT 'pendiente',
  intentos TINYINT UNSIGNED NOT NULL DEFAULT 0,
  mensaje_error VARCHAR(255) NULL,
  ruta_xml VARCHAR(255) NULL,
  fecha_anulacion_sat DATETIME NULL,
  autorizacion_anulacion VARCHAR(64) NULL,
  fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  factura_clave BIGINT UNSIGNED GENERATED ALWAYS AS (IF(tipo_documento = 'factura', id_venta, NULL)) STORED,
  PRIMARY KEY (id_documento_fel),
  UNIQUE KEY uq_fel_factura (factura_clave),
  KEY ix_fel_estado (estado),
  KEY ix_fel_venta (id_venta),
  CONSTRAINT chk_fel_montos CHECK (monto_gravable >= 0 AND monto_impuesto >= 0 AND monto_total >= 0),
  CONSTRAINT fk_fel_venta FOREIGN KEY (id_venta) REFERENCES venta(id_venta) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE movimiento_inventario (
  id_movimiento BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_tipo_movimiento TINYINT UNSIGNED NOT NULL,
  id_producto INT UNSIGNED NOT NULL,
  id_lote INT UNSIGNED NULL,
  id_bodega INT UNSIGNED NOT NULL,
  cantidad DECIMAL(10,3) NOT NULL,
  saldo_posterior DECIMAL(10,3) NOT NULL,
  id_usuario INT UNSIGNED NOT NULL,
  id_usuario_autoriza INT UNSIGNED NULL,
  motivo VARCHAR(255) NULL,
  id_venta BIGINT UNSIGNED NULL,
  id_pedido BIGINT UNSIGNED NULL,
  fecha_hora DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id_movimiento),
  KEY ix_mi_producto (id_producto, fecha_hora),
  KEY ix_mi_tipo (id_tipo_movimiento),
  KEY ix_mi_lote (id_lote),
  KEY ix_mi_bodega (id_bodega),
  KEY ix_mi_usuario (id_usuario),
  KEY ix_mi_autoriza (id_usuario_autoriza),
  KEY ix_mi_venta (id_venta),
  KEY ix_mi_pedido (id_pedido),
  CONSTRAINT chk_mi_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_mi_saldo CHECK (saldo_posterior >= 0),
  CONSTRAINT fk_mi_tipo FOREIGN KEY (id_tipo_movimiento) REFERENCES tipo_movimiento(id_tipo_movimiento) ON DELETE RESTRICT,
  CONSTRAINT fk_mi_producto FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT,
  CONSTRAINT fk_mi_lote FOREIGN KEY (id_lote) REFERENCES lote(id_lote) ON DELETE RESTRICT,
  CONSTRAINT fk_mi_bodega FOREIGN KEY (id_bodega) REFERENCES bodega(id_bodega) ON DELETE RESTRICT,
  CONSTRAINT fk_mi_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  CONSTRAINT fk_mi_autoriza FOREIGN KEY (id_usuario_autoriza) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  CONSTRAINT fk_mi_venta FOREIGN KEY (id_venta) REFERENCES venta(id_venta) ON DELETE RESTRICT,
  CONSTRAINT fk_mi_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE envio (
  id_envio BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_pedido BIGINT UNSIGNED NOT NULL,
  id_transportista TINYINT UNSIGNED NOT NULL,
  id_usuario_despacha INT UNSIGNED NOT NULL,
  numero_guia VARCHAR(40) NULL,
  fecha_despacho DATETIME NOT NULL,
  fecha_entrega_estimada DATE NULL,
  fecha_entrega_real DATETIME NULL,
  estado ENUM('preparado','en_transito','entregado','devuelto') NOT NULL DEFAULT 'preparado',
  observacion VARCHAR(255) NULL,
  PRIMARY KEY (id_envio),
  UNIQUE KEY uq_envio_pedido (id_pedido),
  KEY ix_envio_transportista (id_transportista),
  KEY ix_envio_usuario (id_usuario_despacha),
  KEY ix_envio_estado (estado),
  CONSTRAINT fk_envio_pedido FOREIGN KEY (id_pedido) REFERENCES pedido(id_pedido) ON DELETE RESTRICT,
  CONSTRAINT fk_envio_transportista FOREIGN KEY (id_transportista) REFERENCES transportista(id_transportista) ON DELETE RESTRICT,
  CONSTRAINT fk_envio_usuario FOREIGN KEY (id_usuario_despacha) REFERENCES usuario(id_usuario) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE notificacion (
  id_notificacion BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  id_cliente INT UNSIGNED NULL,
  id_usuario INT UNSIGNED NULL,
  tipo ENUM('confirmacion_pedido','pago_verificado','pedido_enviado','pedido_entregado','recordatorio_suscripcion','existencia_baja','proximo_vencimiento','dte_rechazado') NOT NULL,
  asunto VARCHAR(150) NOT NULL,
  cuerpo TEXT NULL,
  estado ENUM('pendiente','enviada','fallida') NOT NULL DEFAULT 'pendiente',
  intentos TINYINT UNSIGNED NOT NULL DEFAULT 0,
  mensaje_error VARCHAR(255) NULL,
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fecha_envio DATETIME NULL,
  PRIMARY KEY (id_notificacion),
  KEY ix_notificacion_proceso (estado, fecha_creacion),
  KEY ix_notificacion_cliente (id_cliente),
  KEY ix_notificacion_usuario (id_usuario),
  CONSTRAINT chk_destinatario CHECK (id_cliente IS NOT NULL OR id_usuario IS NOT NULL),
  CONSTRAINT fk_notificacion_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE CASCADE,
  CONSTRAINT fk_notificacion_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
