<?php

// Tablas de negocio que atiende cada microservicio de dominio, tal como
// las declara CLAUDE.md. SaludController las usa para reportar el conteo
// de tablas del dominio; la Fase 3 reutiliza este mapa para el comando
// chdiego:trazabilidad.

return [

    'tablas_dominio' => [
        'auth' => [
            'rol', 'permiso', 'rol_permiso', 'usuario', 'bitacora',
        ],
        'catalogo' => [
            'categoria', 'producto', 'historial_precio',
            'bodega', 'lote', 'existencia', 'tipo_movimiento',
            'movimiento_inventario', 'reserva_existencia',
        ],
        'pedidos' => [
            'cliente', 'direccion_entrega', 'pedido', 'detalle_pedido',
            'carrito', 'detalle_carrito', 'zona_cobertura', 'transportista',
            'envio', 'plan_suscripcion', 'suscripcion',
        ],
        'pagos' => [
            'venta', 'detalle_venta', 'metodo_pago', 'turno_caja',
            'documento_fel',
        ],
    ],

];
