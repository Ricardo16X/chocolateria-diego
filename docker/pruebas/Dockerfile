# =============================================================================
# Imagen de pruebas unitarias
#
# La imagen de produccion instala las dependencias con --no-dev, y PHPUnit es
# una dependencia de desarrollo: vendor/bin/phpunit no existe ahi. Correr las
# unitarias dentro de un microservicio funcionaba solo en el equipo de
# desarrollo, donde docker-compose.override.yml monta ./src encima y trae el
# vendor completo del anfitrion. En integracion continua fallaba con
# "Could not open input file: vendor/bin/phpunit".
#
# Esta imagen parte de la misma base y agrega las dependencias de desarrollo.
# No se publica ni se usa en produccion: existe solo para ejecutar PHPUnit.
#
# Se construye sola desde tests/unitarias/pruebas-unitarias.sh. La base tiene
# que existir primero:
#   docker build -f docker/base/Dockerfile -t chocolate-diego/base:dev .
# =============================================================================
ARG VERSION_BASE=dev
FROM chocolate-diego/base:${VERSION_BASE}

LABEL org.opencontainers.image.title="chocolate-diego-pruebas" \
      org.opencontainers.image.description="Imagen de pruebas unitarias con dependencias de desarrollo" \
      com.chocolatediego.publicable="no"

# Las unitarias no tocan la base de datos ni la red, asi que no hace falta
# levantar nada: esta imagen se ejecuta sola. El entorno de pruebas ya lo
# fija phpunit.xml (APP_ENV=testing, drivers en array).
ENV SERVICIO=pruebas

# Reinstala con las dependencias de desarrollo y regenera el autoloader para
# que incluya el espacio de nombres Tests\ de phpunit.xml.
USER root
RUN composer install --prefer-dist --no-interaction --no-scripts \
    && composer dump-autoload --optimize --no-interaction \
    && chown -R laravel:laravel vendor
USER laravel

# Sin el punto de entrada de la base, que espera a MySQL y a Redis y arranca
# php-fpm: aca no hay nada que esperar ni ningun servidor que levantar.
ENTRYPOINT []
CMD ["php", "vendor/bin/phpunit"]
