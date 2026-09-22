-- ============================================================================
-- Artesanal Chocolate Diego — Entrega 8
-- 03_datos_iniciales.sql — Catalogos base del sistema
--
-- Sin estos registros el sistema no opera: sp_registrar_venta exige un
-- tipo_movimiento llamado "venta" con efecto "resta", y sp_anular_venta uno
-- llamado "devolucion" con efecto "suma".
--
-- La contrasena del usuario administrador es "Chocolate2026" en bcrypt.
-- Debe cambiarse en el primer inicio de sesion.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------
INSERT INTO rol (nombre, descripcion) VALUES
  ('Administrador',      'Acceso total al sistema, incluye anulacion de ventas'),
  ('Gerencia',           'Consulta de indicadores, reportes y autorizacion de descuentos'),
  ('Personal de Ventas', 'Operacion del punto de venta y atencion de pedidos'),
  ('Personal de Bodega', 'Movimientos de inventario, lotes y despacho de envios');

-- ---------------------------------------------------------------------------
-- Permisos por modulo
-- ---------------------------------------------------------------------------
INSERT INTO permiso (modulo, accion, descripcion) VALUES
  ('usuarios',    'crear',      'Registrar usuarios del sistema'),
  ('usuarios',    'editar',     'Modificar usuarios y roles'),
  ('usuarios',    'consultar',  'Consultar usuarios'),
  ('catalogo',    'crear',      'Registrar productos y categorias'),
  ('catalogo',    'editar',     'Modificar productos, precios y categorias'),
  ('catalogo',    'consultar',  'Consultar el catalogo'),
  ('inventario',  'ajustar',    'Registrar entradas y salidas de inventario'),
  ('inventario',  'autorizar',  'Autorizar movimientos que lo requieren'),
  ('inventario',  'consultar',  'Consultar existencias, lotes y kardex'),
  ('ventas',      'registrar',  'Registrar ventas en el punto de venta'),
  ('ventas',      'anular',     'Anular ventas registradas'),
  ('ventas',      'descuento',  'Autorizar descuentos sobre una venta'),
  ('ventas',      'consultar',  'Consultar ventas y turnos de caja'),
  ('pedidos',     'gestionar',  'Verificar pagos y preparar pedidos en linea'),
  ('pedidos',     'consultar',  'Consultar pedidos de la tienda en linea'),
  ('envios',      'despachar',  'Despachar y dar seguimiento a envios'),
  ('fel',         'consultar',  'Consultar el estado de los documentos FEL'),
  ('fel',         'reintentar', 'Reintentar la certificacion de un DTE'),
  ('suscripciones','gestionar', 'Administrar planes y suscripciones'),
  ('reportes',    'consultar',  'Consultar reportes e indicadores'),
  ('bitacora',    'consultar',  'Consultar la bitacora de auditoria'),
  ('parametros',  'editar',     'Modificar parametros de configuracion');

-- Administrador: todos los permisos
INSERT INTO rol_permiso (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
  FROM rol r CROSS JOIN permiso p
 WHERE r.nombre = 'Administrador';

-- Gerencia: consulta, reportes y autorizaciones
INSERT INTO rol_permiso (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
  FROM rol r CROSS JOIN permiso p
 WHERE r.nombre = 'Gerencia'
   AND (p.accion IN ('consultar','autorizar','descuento')
        OR (p.modulo = 'catalogo' AND p.accion = 'editar'));

-- Personal de Ventas: punto de venta, pedidos y consulta
INSERT INTO rol_permiso (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
  FROM rol r CROSS JOIN permiso p
 WHERE r.nombre = 'Personal de Ventas'
   AND ((p.modulo = 'ventas'    AND p.accion IN ('registrar','consultar'))
     OR (p.modulo = 'pedidos'   AND p.accion IN ('gestionar','consultar'))
     OR (p.modulo = 'catalogo'  AND p.accion = 'consultar')
     OR (p.modulo = 'inventario'AND p.accion = 'consultar')
     OR (p.modulo = 'fel'       AND p.accion = 'consultar'));

-- Personal de Bodega: inventario, lotes y envios
INSERT INTO rol_permiso (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
  FROM rol r CROSS JOIN permiso p
 WHERE r.nombre = 'Personal de Bodega'
   AND ((p.modulo = 'inventario' AND p.accion IN ('ajustar','consultar'))
     OR (p.modulo = 'envios'     AND p.accion = 'despachar')
     OR (p.modulo = 'catalogo'   AND p.accion = 'consultar')
     OR (p.modulo = 'pedidos'    AND p.accion = 'consultar'));

-- ---------------------------------------------------------------------------
-- Usuario administrador inicial
-- ---------------------------------------------------------------------------
INSERT INTO usuario (id_rol, nombre, apellido, nombre_usuario, correo, contrasena_hash)
SELECT r.id_rol, 'Administrador', 'del Sistema', 'admin',
       'admin@chocolatediego.com',
       '$2y$10$lPbe8fFcBXs.sKdyJb1VwuuSdj0HXKRaIbubvZapIpfhT1/LLjDAC'
  FROM rol r WHERE r.nombre = 'Administrador';

-- ---------------------------------------------------------------------------
-- Tipos de movimiento de inventario
-- Los nombres "venta" y "devolucion" son obligatorios: los procedimientos
-- almacenados los buscan por nombre.
-- ---------------------------------------------------------------------------
INSERT INTO tipo_movimiento (nombre, efecto, requiere_autorizacion) VALUES
  ('compra',          'suma',  0),
  ('produccion',      'suma',  0),
  ('devolucion',      'suma',  0),
  ('ajuste_positivo', 'suma',  1),
  ('venta',           'resta', 0),
  ('merma',           'resta', 1),
  ('vencimiento',     'resta', 1),
  ('traslado_salida', 'resta', 1),
  ('ajuste_negativo', 'resta', 1);

-- ---------------------------------------------------------------------------
-- Metodos de pago
-- ---------------------------------------------------------------------------
INSERT INTO metodo_pago (nombre, requiere_comprobante, aplica_cambio) VALUES
  ('Efectivo',              0, 1),
  ('Tarjeta',               1, 0),
  ('Transferencia',         1, 0),
  ('Deposito bancario',     1, 0),
  ('Pago contra entrega',   0, 1);

-- ---------------------------------------------------------------------------
-- Bodegas
-- ---------------------------------------------------------------------------
INSERT INTO bodega (nombre, tipo, direccion) VALUES
  ('Sala de venta', 'sala_venta', 'San Pedro La Laguna, Solola'),
  ('Bodega principal', 'bodega',  'San Pedro La Laguna, Solola'),
  ('Area de produccion', 'produccion', 'San Pedro La Laguna, Solola');

-- ---------------------------------------------------------------------------
-- Categorias de producto
-- ---------------------------------------------------------------------------
INSERT INTO categoria (nombre, descripcion) VALUES
  ('Tabletas',          'Tabletas de chocolate artesanal'),
  ('Bombones',          'Bombones y trufas rellenas'),
  ('Cacao en polvo',    'Cacao molido y mezclas para bebida'),
  ('Cajas de regalo',   'Presentaciones surtidas para obsequio'),
  ('Caja de suscripcion','Productos destinados a la caja periodica');

-- ---------------------------------------------------------------------------
-- Transportistas
-- ---------------------------------------------------------------------------
INSERT INTO transportista (nombre, tipo, telefono_contacto) VALUES
  ('Reparto propio', 'propio',  '00000000'),
  ('Cargo Expreso',  'externo', '23791000'),
  ('Guatex',         'externo', '22850505');

-- ---------------------------------------------------------------------------
-- Zonas de cobertura: Solola, Chimaltenango, Sacatepequez y Guatemala
-- ---------------------------------------------------------------------------
INSERT INTO zona_cobertura (departamento, municipio, costo_envio, dias_estimados) VALUES
  ('Solola',        'San Pedro La Laguna',  0.00, 1),
  ('Solola',        'Panajachel',          25.00, 1),
  ('Solola',        'Solola',              25.00, 1),
  ('Solola',        'Santiago Atitlan',    30.00, 2),
  ('Solola',        'San Marcos La Laguna',30.00, 2),
  ('Chimaltenango', 'Chimaltenango',       40.00, 2),
  ('Chimaltenango', 'Tecpan Guatemala',    40.00, 2),
  ('Chimaltenango', 'Patzun',              45.00, 3),
  ('Sacatepequez',  'Antigua Guatemala',   40.00, 2),
  ('Sacatepequez',  'Jocotenango',         40.00, 2),
  ('Sacatepequez',  'Ciudad Vieja',        45.00, 3),
  ('Guatemala',     'Guatemala',           50.00, 3),
  ('Guatemala',     'Mixco',               50.00, 3),
  ('Guatemala',     'Villa Nueva',         55.00, 3),
  ('Guatemala',     'San Miguel Petapa',   55.00, 3),
  ('Guatemala',     'Santa Catarina Pinula',55.00, 3);

-- ---------------------------------------------------------------------------
-- Planes de suscripcion
-- ---------------------------------------------------------------------------
INSERT INTO plan_suscripcion (nombre, descripcion, periodicidad, precio) VALUES
  ('Caja Degustacion', 'Seleccion mensual de tabletas y bombones',  'mensual',    250.00),
  ('Caja Origen',      'Tabletas de origen unico cada dos meses',   'bimestral',  420.00),
  ('Caja Coleccion',   'Surtido trimestral con edicion especial',   'trimestral', 600.00);

-- ---------------------------------------------------------------------------
-- Parametros del sistema
-- ---------------------------------------------------------------------------
INSERT INTO parametro_sistema (clave, valor, tipo_dato, descripcion, editable) VALUES
  ('empresa.nombre',          'Artesanal Chocolate Diego', 'texto',   'Nombre comercial',                         0),
  ('empresa.nit',             'CF',                        'texto',   'NIT del emisor ante la SAT',               1),
  ('empresa.direccion',       'San Pedro La Laguna, Solola','texto',  'Direccion fiscal',                         1),
  ('fel.tasa_iva',            '0.12',                      'numero',  'Tasa de IVA aplicada al DTE. Editable: sp_registrar_venta la lee en cada venta.', 1),
  ('fel.intentos_maximos',    '5',                         'numero',  'Reintentos antes de marcar el DTE fallido',1),
  ('fel.certificador',        'pendiente',                 'texto',   'Certificador autorizado contratado',       1),
  ('inventario.dias_alerta',  '30',                        'numero',  'Dias de anticipacion de la alerta de vencimiento', 1),
  ('reserva.minutos_vigencia','60',                        'numero',  'Vigencia de una reserva de existencia',    1),
  ('seguridad.intentos_maximos','5',                       'numero',  'Intentos fallidos antes de bloquear la cuenta', 1),
  ('tienda.monto_envio_gratis','400.00',                   'numero',  'Monto a partir del cual el envio es gratuito', 1);
