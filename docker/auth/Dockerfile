# =============================================================================
# Microservicio: auth
#
# Responsabilidad: identidad, roles, permisos y auditoria.
# Modulo del modelo de datos: Seguridad.
# Tablas: rol, permiso, rol_permiso, usuario, bitacora.
#
# Perfil de carga: peticiones cortas y frecuentes (validacion de token en cada
# peticion de los demas servicios). Pocos procesos, reciclaje rapido.
# =============================================================================
ARG VERSION_BASE=dev
FROM chocolate-diego/base:${VERSION_BASE}

LABEL org.opencontainers.image.title="chocolate-diego-auth" \
      org.opencontainers.image.description="Identidad, roles y permisos" \
      com.chocolatediego.modulo="Seguridad" \
      com.chocolatediego.tablas="rol,permiso,rol_permiso,usuario,bitacora"

ENV SERVICIO=auth \
    RUTA_SALUD=/api/auth/salud

COPY docker/auth/fpm.conf /usr/local/etc/php-fpm.d/zz-servicio.conf

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD php -r 'exit(extension_loaded("pdo_mysql") && extension_loaded("redis") ? 0 : 1);'
