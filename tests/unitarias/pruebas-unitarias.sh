#!/usr/bin/env bash
# =============================================================================
# Artesanal Chocolate Diego — pruebas unitarias
#
# Ejecuta PHPUnit dentro del contenedor del microservicio catalogo y trae el
# informe a tests/resultados/resultados-unitarias.xml, en formato JUnit.
#
# Uso:
#   make probar-unitarias
#   bash tests/unitarias/pruebas-unitarias.sh
#
# Codigo de salida 0 si todas pasan, 1 si alguna falla.
#
# El informe se saca del contenedor con cat y no se escribe directo al disco
# del equipo porque /var/www/html/storage es un volumen de Docker, no un
# montaje al repositorio: un archivo escrito ahi dentro no aparece en el
# repositorio.
#
# Las pruebas unitarias no tocan la base de datos ni la red: por eso corren
# en cualquier contenedor de aplicacion, y catalogo es solo el que esta a
# mano. Ver docs/devops1/plan-de-pruebas.md, casos U01 a U17.
# =============================================================================
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SALIDA="${RAIZ}/tests/resultados"
XML="${SALIDA}/resultados-unitarias.xml"
COMPOSE="docker compose"
SERVICIO="${SERVICIO_PRUEBAS:-catalogo}"
XML_INTERNO="/tmp/resultados-unitarias.xml"

cd "$RAIZ" || exit 1
mkdir -p "$SALIDA"

echo "================================================================"
echo " PRUEBAS UNITARIAS — Artesanal Chocolate Diego"
echo " Contenedor: ${SERVICIO}"
echo "================================================================"
echo

$COMPOSE exec -T "$SERVICIO" php vendor/bin/phpunit --log-junit "$XML_INTERNO"
RESULTADO=$?

if $COMPOSE exec -T "$SERVICIO" test -f "$XML_INTERNO"; then
    $COMPOSE exec -T "$SERVICIO" cat "$XML_INTERNO" > "$XML"
    $COMPOSE exec -T "$SERVICIO" rm -f "$XML_INTERNO"
    echo
    echo " Resultados JUnit: tests/resultados/resultados-unitarias.xml"
else
    echo
    echo " PHPUnit no genero el informe JUnit." >&2
    RESULTADO=1
fi

echo "================================================================"

exit "$RESULTADO"
