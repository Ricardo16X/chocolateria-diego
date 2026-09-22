# =============================================================================
# Microservicio: pedidos
#
# Responsabilidad: clientes, carrito, pedidos de la tienda en linea, envios a
# las cuatro zonas de cobertura y caja por suscripcion.
# Modulos del modelo de datos: Clientes, Entregas y Suscripcion.
# Tablas: cliente, direccion_entrega, pedido, detalle_pedido, carrito,
#         detalle_carrito, zona_cobertura, transportista, envio,
#         plan_suscripcion, suscripcion.
#
# Perfil de carga: sesiones largas de navegacion con carrito. Recibe la carga
# de comprobantes de pago, por lo que admite cuerpos de peticion mayores.
# =============================================================================
ARG VERSION_BASE=dev
FROM chocolate-diego/base:${VERSION_BASE}

LABEL org.opencontainers.image.title="chocolate-diego-pedidos" \
      org.opencontainers.image.description="Tienda en linea, entregas y suscripciones" \
      com.chocolatediego.modulo="Clientes,Entregas,Suscripcion" \
      com.chocolatediego.tablas="cliente,direccion_entrega,pedido,detalle_pedido,carrito,detalle_carrito,zona_cobertura,transportista,envio,plan_suscripcion,suscripcion"

ENV SERVICIO=pedidos \
    RUTA_SALUD=/api/pedidos/salud

COPY docker/pedidos/fpm.conf /usr/local/etc/php-fpm.d/zz-servicio.conf
COPY docker/pedidos/carga.ini /usr/local/etc/php/conf.d/zz-carga.ini

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD php -r 'exit(extension_loaded("pdo_mysql") && extension_loaded("redis") ? 0 : 1);'
