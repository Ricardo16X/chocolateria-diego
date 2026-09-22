# =============================================================================
# Artesanal Chocolate Diego — imagen base de los microservicios
#
# Contiene PHP 8.1, las extensiones y el codigo de la aplicacion. Los cuatro
# servicios de dominio (auth, catalogo, pedidos, pagos) parten de esta imagen
# y solo agregan su configuracion propia.
#
# Se construye primero:
#   docker build -f docker/base/Dockerfile -t chocolate-diego/base:dev .
#
# El Makefile lo hace solo con "make construir".
# =============================================================================

# -----------------------------------------------------------------------------
# Etapa 1: dependencias de Composer
# -----------------------------------------------------------------------------
FROM composer:2.7 AS vendor

WORKDIR /app
COPY src/composer.json src/composer.loc[k] ./

RUN composer install \
        --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction \
    || echo "Sin composer.json todavia: se omite la instalacion."

# -----------------------------------------------------------------------------
# Etapa 2: imagen base
# -----------------------------------------------------------------------------
FROM php:8.1-fpm-alpine AS base

LABEL org.opencontainers.image.title="chocolate-diego-base" \
      org.opencontainers.image.description="Imagen base de los microservicios de Artesanal Chocolate Diego" \
      org.opencontainers.image.vendor="Grupo 8 — Seminario de Tecnologias de Informacion, UMG"

RUN apk add --no-cache \
        bash curl mysql-client icu-libs libzip libpng \
        freetype libjpeg-turbo oniguruma tzdata

RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS icu-dev libzip-dev libpng-dev \
        freetype-dev libjpeg-turbo-dev oniguruma-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        pdo_mysql mysqli bcmath intl zip gd exif pcntl opcache \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps \
    && rm -rf /tmp/pear

ENV TZ=America/Guatemala
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

COPY docker/base/php.ini /usr/local/etc/php/conf.d/99-chocolate-diego.ini

RUN addgroup -g 1000 laravel \
    && adduser -u 1000 -G laravel -h /var/www/html -s /bin/bash -D laravel

WORKDIR /var/www/html

COPY --from=vendor --chown=laravel:laravel /app/vendo[r] ./vendor
COPY --chown=laravel:laravel src/ ./

RUN mkdir -p storage/framework/cache storage/framework/sessions \
             storage/framework/views storage/logs bootstrap/cache \
    && chown -R laravel:laravel storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

COPY --chmod=755 docker/base/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --from=composer:2.7 /usr/bin/composer /usr/local/bin/composer

USER laravel
EXPOSE 9000

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]
