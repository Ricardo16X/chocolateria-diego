# =============================================================================
# Microservicio: pagos
#
# Responsabilidad: punto de venta, turnos de caja, metodos de pago y
# facturacion electronica FEL ante la SAT.
# Modulos del modelo de datos: Punto de venta y FEL.
# Tablas: venta, detalle_venta, metodo_pago, turno_caja, documento_fel.
#
# Este servicio NO certifica el DTE dentro de la peticion: encola el trabajo
# en la cola "fel" y responde de inmediato. Si el certificador no responde, la
# venta ya quedo registrada y el documento espera con su contador de intentos.
# Por eso el worker corre en su propio contenedor.
# =============================================================================
ARG VERSION_BASE=dev
FROM chocolate-diego/base:${VERSION_BASE}

LABEL org.opencontainers.image.title="chocolate-diego-pagos" \
      org.opencontainers.image.description="Punto de venta y facturacion electronica FEL" \
      com.chocolatediego.modulo="PuntoVenta,Fel" \
      com.chocolatediego.tablas="venta,detalle_venta,metodo_pago,turno_caja,documento_fel"

ENV SERVICIO=pagos \
    RUTA_SALUD=/api/pagos/salud

COPY docker/pagos/fpm.conf /usr/local/etc/php-fpm.d/zz-servicio.conf

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD php -r 'exit(extension_loaded("pdo_mysql") && extension_loaded("redis") ? 0 : 1);'
