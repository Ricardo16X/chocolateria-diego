#!/usr/bin/env bash
# =============================================================================
# Artesanal Chocolate Diego — evidencias.sh
#
# Genera las evidencias tecnicas de la entrega DEVOPS 1 en
# docs/devops1/evidencias/, numeradas y con su indice.
#
# Requiere el sistema levantado: make arriba
# =============================================================================
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="${RAIZ}/docs/devops1/evidencias"
URL="http://localhost:${WEB_PORT:-8080}"
FECHA="$(date '+%Y-%m-%d %H:%M:%S')"

cd "$RAIZ" || exit 1
mkdir -p "$DESTINO"

capturar() {
    local numero="$1" titulo="$2"; shift 2
    local n; n=$(printf '%02d' "$numero")
    {
        echo "============================================================"
        echo " EVIDENCIA ${n} — ${titulo//-/ }"
        echo " Artesanal Chocolate Diego — Entrega DEVOPS 1"
        echo " Generada: ${FECHA}"
        echo "============================================================"
        echo
        "$@" 2>&1
    } > "${DESTINO}/${n}-${titulo}.txt"
    echo "  [${n}] ${titulo}"
}

# --- Funciones de captura ----------------------------------------------------

versiones() {
    docker --version
    docker compose version
}

# docker compose config imprime las variables ya sustituidas, contrasenas
# incluidas. Se enmascaran antes de guardar la evidencia.
composicion() {
    docker compose config \
        | sed -E 's/((PASSWORD|_KEY|LLAVE|SECRET)[A-Z_]*: *).+/\1********/' \
        | sed -E 's/(-p)[^ "]+/\1********/g'
}

imagenes() {
    docker images --filter "reference=chocolate-diego/*" \
        --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
}

etiquetas_de_dominio() {
    for s in auth catalogo pedidos pagos; do
        echo "--- chocolate-diego/${s}"
        docker inspect --format \
            'Modulo: {{index .Config.Labels "com.chocolatediego.modulo"}}{{"\n"}}Tablas: {{index .Config.Labels "com.chocolatediego.tablas"}}' \
            "chocolate-diego/${s}:${APP_VERSION:-dev}"
        echo
    done
}

enrutamiento() {
    printf "%-26s %-8s %s\n" "RUTA" "HTTP" "ATENDIDA POR"
    for ruta in /estado /api/auth/salud /api/catalogo/salud /api/pedidos/salud /api/pagos/salud /; do
        local cabeceras codigo servicio
        cabeceras=$(curl -s -o /dev/null -D - --max-time 10 "${URL}${ruta}")
        codigo=$(printf '%s\n' "$cabeceras" | awk 'NR==1 {print $2}')
        servicio=$(printf '%s\n' "$cabeceras" | awk 'tolower($1)=="x-servicio:" {print $2}' | tr -d '\r')
        printf "%-26s %-8s %s\n" "$ruta" "$codigo" "${servicio:-gateway}"
    done
}

verificacion() {
    docker compose exec -T db bash -c 'DB_HOST=localhost DB_USER=root \
        DB_PASS="$MYSQL_ROOT_PASSWORD" DB_NAME="$MYSQL_DATABASE" bash -s' \
        < scripts/verificar-esquema.sh
}

codigo() { curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${URL}$1"; }

resiliencia() {
    echo "Se detiene el microservicio pagos y se observa el resto del sistema."
    echo
    echo "--- Antes de la falla"
    echo "  /api/pagos/salud  -> HTTP $(codigo /api/pagos/salud)"
    echo "  /api/auth/salud   -> HTTP $(codigo /api/auth/salud)"
    echo
    echo "--- docker compose stop pagos"
    docker compose stop pagos
    sleep 3
    echo
    echo "--- Durante la falla"
    echo "  /api/pagos/salud  -> HTTP $(codigo /api/pagos/salud)   (esperado 502)"
    echo "  /api/auth/salud   -> HTTP $(codigo /api/auth/salud)   (auth sigue atendiendo)"
    echo "  /api/catalogo/salud -> HTTP $(codigo /api/catalogo/salud)"
    echo
    docker compose ps
    echo
    echo "--- docker compose start pagos"
    docker compose start pagos
    local c="502"
    for _ in $(seq 1 30); do
        c=$(codigo /api/pagos/salud); [ "$c" != "502" ] && break; sleep 2
    done
    echo
    echo "--- Despues de la recuperacion"
    echo "  /api/pagos/salud  -> HTTP ${c}"
    echo
    echo "La puerta de enlace no se reinicio: resuelve los nombres en cada peticion."
}

# --- Captura -----------------------------------------------------------------

echo "Generando evidencias en ${DESTINO}"
echo

capturar 1  "version-de-docker"          versiones
capturar 2  "composicion-validada"       composicion
capturar 3  "construccion-de-imagenes"   docker compose build
capturar 4  "servicios-en-ejecucion"     docker compose ps
capturar 5  "imagenes-construidas"       imagenes
capturar 6  "dominio-de-cada-servicio"   etiquetas_de_dominio
capturar 7  "registros-por-servicio"     docker compose logs --tail=40
capturar 8  "red-interna"                docker network inspect chdiego_net
capturar 9  "volumenes"                  docker volume ls --filter "name=chdiego"
capturar 10 "enrutamiento-por-dominio"   enrutamiento
capturar 11 "verificacion-de-esquema"    verificacion
capturar 12 "consumo-de-recursos"        docker stats --no-stream \
    --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
capturar 13 "tolerancia-a-fallos"        resiliencia
capturar 14 "pruebas-de-humo"            bash tests/humo/pruebas-humo.sh

cat > "${DESTINO}/README.md" <<INDICE
# Evidencias técnicas — Entrega DEVOPS 1

Artesanal Chocolate Diego · Grupo 8 · Seminario de Tecnologías de Información

Generadas el ${FECHA}.

| # | Archivo | Qué demuestra |
|---|---------|---------------|
| 01 | 01-version-de-docker.txt | Versiones de Docker y Compose |
| 02 | 02-composicion-validada.txt | La composición de nueve servicios es válida |
| 03 | 03-construccion-de-imagenes.txt | Cada microservicio se construye desde su Dockerfile |
| 04 | 04-servicios-en-ejecucion.txt | Los nueve contenedores levantan y quedan saludables |
| 05 | 05-imagenes-construidas.txt | Tamaño de las imágenes propias |
| 06 | 06-dominio-de-cada-servicio.txt | Módulo y tablas que atiende cada microservicio |
| 07 | 07-registros-por-servicio.txt | Arranque correcto de cada servicio |
| 08 | 08-red-interna.txt | Red aislada y direcciones asignadas |
| 09 | 09-volumenes.txt | Persistencia de datos fuera de los contenedores |
| 10 | 10-enrutamiento-por-dominio.txt | La puerta de enlace entrega cada prefijo a su servicio |
| 11 | 11-verificacion-de-esquema.txt | La base implementada corresponde al Octavo Documento |
| 12 | 12-consumo-de-recursos.txt | CPU, memoria y red por contenedor |
| 13 | 13-tolerancia-a-fallos.txt | La caída de un microservicio no afecta a los demás |
| 14 | 14-pruebas-de-humo.txt | Resultado de las 18 pruebas automáticas |
INDICE

echo
echo "Listo: ${DESTINO}"
