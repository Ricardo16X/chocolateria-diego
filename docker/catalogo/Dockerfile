# =============================================================================
# Microservicio: catalogo
#
# Responsabilidad: productos, categorias, precios, lotes, existencias y kardex.
# Modulos del modelo de datos: Catalogo e Inventario.
# Tablas: categoria, producto, historial_precio, bodega, lote, existencia,
#         tipo_movimiento, movimiento_inventario, reserva_existencia.
#
# Perfil de carga: lecturas intensivas desde la tienda en linea. Es el servicio
# que mas se beneficia de la cache de codigo compilado.
# =============================================================================
ARG VERSION_BASE=dev
FROM chocolate-diego/base:${VERSION_BASE}

LABEL org.opencontainers.image.title="chocolate-diego-catalogo" \
      org.opencontainers.image.description="Catalogo de productos e inventario por lotes" \
      com.chocolatediego.modulo="Catalogo,Inventario" \
      com.chocolatediego.tablas="categoria,producto,historial_precio,bodega,lote,existencia,tipo_movimiento,movimiento_inventario,reserva_existencia"

ENV SERVICIO=catalogo \
    RUTA_SALUD=/api/catalogo/salud

COPY docker/catalogo/fpm.conf /usr/local/etc/php-fpm.d/zz-servicio.conf
COPY docker/catalogo/opcache.ini /usr/local/etc/php/conf.d/zz-opcache.ini

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD php -r 'exit(extension_loaded("pdo_mysql") && extension_loaded("redis") ? 0 : 1);'
