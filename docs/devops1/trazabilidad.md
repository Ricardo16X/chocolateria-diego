# Trazabilidad — servicio, módulo, tablas y modelos

Generado automáticamente por `php artisan chdiego:trazabilidad` el 2026-09-21.
No editar a mano: se sobrescribe la próxima vez que se corra el comando.

| Servicio | Módulo | Tablas | Modelos |
|---|---|---|---|
| auth | Seguridad | bitacora, permiso, rol, rol_permiso, usuario | Bitacora, Permiso, Rol, RolPermiso, Usuario |
| catalogo | Catalogo | categoria, historial_precio, producto | Categoria, HistorialPrecio, Producto |
| catalogo | Inventario | bodega, existencia, lote, movimiento_inventario, reserva_existencia, tipo_movimiento | Bodega, Existencia, Lote, MovimientoInventario, ReservaExistencia, TipoMovimiento |
| pagos | Fel | documento_fel | DocumentoFel |
| pagos | PuntoVenta | detalle_venta, metodo_pago, turno_caja, venta | DetalleVenta, MetodoPago, TurnoCaja, Venta |
| pedidos | Clientes | carrito, cliente, detalle_carrito, detalle_pedido, direccion_entrega, pedido | Carrito, Cliente, DetalleCarrito, DetallePedido, DireccionEntrega, Pedido |
| pedidos | Entregas | envio, transportista, zona_cobertura | Envio, Transportista, ZonaCobertura |
| pedidos | Suscripcion | plan_suscripcion, suscripcion | PlanSuscripcion, Suscripcion |
| todos (transversal) | Soporte | notificacion, parametro_sistema | Notificacion, ParametroSistema |
