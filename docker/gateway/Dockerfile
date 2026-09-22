# =============================================================================
# Puerta de enlace
#
# Unico punto de entrada HTTP del sistema. Enruta cada prefijo al
# microservicio que le corresponde y sirve los archivos estaticos. Los cuatro
# servicios de dominio no se exponen fuera de la red interna.
# =============================================================================
FROM nginx:1.27-alpine

LABEL org.opencontainers.image.title="chocolate-diego-gateway" \
      org.opencontainers.image.description="Puerta de enlace de los microservicios" \
      org.opencontainers.image.vendor="Grupo 8 — Seminario de Tecnologias de Informacion, UMG"

RUN rm /etc/nginx/conf.d/default.conf

# gateway.conf.template se procesa con envsubst al arrancar el contenedor
# (mecanismo propio de la imagen oficial de nginx): sustituye RESOLVER_ADDR
# y nada mas, para no tocar las variables propias de nginx ($microservicio,
# $request_uri, etc.). 127.0.0.11 es el DNS embebido de Docker Engine; un
# entorno con otro motor de contenedores la sobreescribe por variable de
# entorno sin modificar este Dockerfile ni la plantilla.
ENV RESOLVER_ADDR=127.0.0.11
ENV NGINX_ENVSUBST_FILTER=^RESOLVER_ADDR$
COPY docker/gateway/gateway.conf.template /etc/nginx/templates/chocolate-diego.conf.template
COPY src/publi[c] /var/www/html/public

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget --quiet --spider http://127.0.0.1/estado || exit 1
