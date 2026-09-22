#!/bin/bash
# =============================================================================
# Punto de entrada comun de los microservicios.
# Espera a sus dependencias, prepara la aplicacion y cede el control.
# La variable SERVICIO identifica al microservicio en los registros.
# =============================================================================
set -euo pipefail

SERVICIO="${SERVICIO:-desconocido}"

esperar() {
    local nombre="$1" host="$2" puerto="$3" intentos=60
    echo "[${SERVICIO}] Esperando a ${nombre} en ${host}:${puerto}..."
    while ! timeout 1 bash -c "cat < /dev/null > /dev/tcp/${host}/${puerto}" 2>/dev/null; do
        intentos=$((intentos - 1))
        if [ "$intentos" -le 0 ]; then
            echo "[${SERVICIO}] ERROR: ${nombre} no respondio a tiempo." >&2
            exit 1
        fi
        sleep 2
    done
    echo "[${SERVICIO}] ${nombre} disponible."
}

esperar "MySQL" "${DB_HOST:-db}" "${DB_PORT:-3306}"
esperar "Redis" "${REDIS_HOST:-cache}" "${REDIS_PORT:-6379}"

if [ -f /var/www/html/artisan ]; then
    mkdir -p storage/framework/cache storage/framework/sessions \
             storage/framework/views storage/logs bootstrap/cache

    if [ -f .env ] && ! grep -q '^APP_KEY=base64:' .env; then
        echo "[${SERVICIO}] Generando APP_KEY..."
        php artisan key:generate --force --no-interaction || true
    fi

    if [ "${APP_ENV:-local}" = "production" ]; then
        php artisan config:cache --no-interaction || true
        php artisan route:cache  --no-interaction || true
        php artisan view:cache   --no-interaction || true
    else
        php artisan config:clear --no-interaction || true
    fi
else
    echo "[${SERVICIO}] Todavia no hay aplicacion Laravel en src/."
    echo "[${SERVICIO}] Ejecute: make instalar-laravel"
fi

echo "[${SERVICIO}] Iniciando: $*"
exec "$@"
