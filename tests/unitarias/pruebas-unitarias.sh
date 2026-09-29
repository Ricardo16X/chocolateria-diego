#!/usr/bin/env bash
# =============================================================================
# Artesanal Chocolate Diego — pruebas unitarias
#
# Ejecuta PHPUnit en la imagen de pruebas (docker/pruebas/Dockerfile) y deja el
# informe en tests/resultados/resultados-unitarias.xml, en formato JUnit.
#
# Uso:
#   make probar-unitarias
#   bash tests/unitarias/pruebas-unitarias.sh
#
# Codigo de salida 0 si todas pasan, 1 si alguna falla.
#
# No necesita el sistema levantado: las unitarias no tocan la base de datos ni
# la red. Solo necesita que exista la imagen base.
#
# Antes esto corria con "docker compose exec catalogo php vendor/bin/phpunit",
# y funcionaba unicamente en el equipo de desarrollo: la imagen de produccion
# instala con --no-dev y PHPUnit es dependencia de desarrollo, asi que en
# integracion continua fallaba con "Could not open input file". Ver el
# Dockerfile de docker/pruebas/.
# =============================================================================
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SALIDA="${RAIZ}/tests/resultados"
XML="${SALIDA}/resultados-unitarias.xml"
VERSION="${APP_VERSION:-dev}"
IMAGEN="chocolate-diego/pruebas:${VERSION}"

cd "$RAIZ" || exit 1
mkdir -p "$SALIDA"
rm -f "$XML"

echo "================================================================"
echo " PRUEBAS UNITARIAS — Artesanal Chocolate Diego"
echo " Imagen: ${IMAGEN}"
echo "================================================================"
echo

if ! docker image inspect "chocolate-diego/base:${VERSION}" >/dev/null 2>&1; then
    echo " No existe la imagen chocolate-diego/base:${VERSION}." >&2
    echo " Construyala primero con: make base" >&2
    exit 1
fi

# La construccion queda en cache: solo rehace la capa de composer cuando
# cambian composer.json o composer.lock.
echo "--- Preparando la imagen de pruebas"
if ! docker build -q -f docker/pruebas/Dockerfile \
        --build-arg "VERSION_BASE=${VERSION}" \
        -t "$IMAGEN" . ; then
    echo " No se pudo construir la imagen de pruebas." >&2
    exit 1
fi
echo

# El informe se escribe dentro del contenedor y se saca con docker cp, no por
# un directorio montado. La imagen corre como el usuario laravel (uid 1000) y
# ese uid no coincide con el dueno del directorio del anfitrion: con Podman sin
# privilegios por el remapeo de uid, y en un agente de integracion continua
# porque el directorio pertenece al usuario del agente. Montar la salida fallaba
# con "Failed to open stream: Permission denied" al escribir el XML.
CONTENEDOR="chdiego_pruebas_unitarias"
docker rm -f "$CONTENEDOR" >/dev/null 2>&1
trap 'docker rm -f "$CONTENEDOR" >/dev/null 2>&1' EXIT

docker run --name "$CONTENEDOR" "$IMAGEN" \
    php vendor/bin/phpunit --log-junit /tmp/resultados-unitarias.xml
RESULTADO=$?

docker cp "${CONTENEDOR}:/tmp/resultados-unitarias.xml" "$XML" >/dev/null 2>&1 \
    || echo " No se pudo extraer el informe del contenedor." >&2

echo
if [ -f "$XML" ]; then
    echo " Resultados JUnit: tests/resultados/resultados-unitarias.xml"
else
    echo " PHPUnit no genero el informe JUnit." >&2
    RESULTADO=1
fi
echo "================================================================"

exit "$RESULTADO"
