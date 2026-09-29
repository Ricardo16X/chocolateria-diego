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

# Quita las secuencias de color ANSI y el aviso del proveedor externo de
# compose, para que la evidencia se lea igual en un editor de texto que en la
# terminal. Con Docker Engine ese aviso no existe y el filtro no hace nada.
limpiar_salida() {
    sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
        -e '/Executing external compose provider/d' \
        -e '/how to disable this message/d'
}

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
        "$@" 2>&1 | limpiar_salida
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

# El repositorio en si es evidencia: historial, ramas, sincronia con el remoto
# y los dos archivos de integracion continua que lo respaldan.
repositorio() {
    echo "--- Remoto configurado"
    git remote -v
    echo
    echo "--- Rama actual y ramas conocidas"
    git branch -a
    echo
    echo "--- Historial (todos los commits)"
    git log --pretty=format:'%h  %ad  %an  %s' --date=short
    echo
    echo
    echo "--- Sincronia con el remoto"
    local local_hash rama upstream upstream_hash main_hash
    local_hash=$(git rev-parse --short HEAD 2>/dev/null)
    rama=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

    # Dos cosas distintas, que antes se confundian en una sola linea: si la
    # rama actual esta subida, y cuanto le falta a main para tenerla.
    upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
    if [ -z "$upstream" ]; then
        echo "La rama ${rama} no tiene rama remota asociada (nunca se subio)."
    else
        upstream_hash=$(git rev-parse --short "$upstream" 2>/dev/null)
        if [ "$local_hash" = "$upstream_hash" ]; then
            echo "Rama ${rama} subida y al dia con ${upstream}: ${local_hash}"
        else
            echo "Rama ${rama}: HEAD=${local_hash}  ${upstream}=${upstream_hash}"
            printf 'Commits sin subir a %s: %s\n' "$upstream" \
                "$(git rev-list --count "${upstream}..HEAD" 2>/dev/null)"
        fi
    fi

    main_hash=$(git rev-parse --short origin/main 2>/dev/null)
    if [ -z "$main_hash" ]; then
        echo "No hay referencia local de origin/main (falta git fetch)."
    elif [ "$local_hash" = "$main_hash" ]; then
        echo "origin/main apunta al mismo commit: ${main_hash}"
    else
        printf 'origin/main=%s, %s commits por delante sin integrar a main\n' \
            "$main_hash" "$(git rev-list --count "origin/main..HEAD" 2>/dev/null)"
    fi
    echo
    echo "--- Estado del arbol de trabajo"
    if [ -z "$(git status --porcelain)" ]; then
        echo "Limpio: no hay cambios sin confirmar."
    else
        git status --short
        echo
        echo "Nota: los archivos de docs/devops1/evidencias/ aparecen aqui porque"
        echo "este mismo script los acaba de reescribir. Se confirman en el commit"
        echo "siguiente a la captura."
    fi
    echo
    echo "--- Archivos contados por git"
    printf 'Archivos versionados: %s\n' "$(git ls-files | wc -l)"
    echo
    echo "--- Integracion continua definida en el repositorio"
    for f in .github/workflows/ci.yml azure-pipelines.yml; do
        if [ -f "$f" ]; then
            printf '%-32s %s lineas\n' "$f" "$(wc -l < "$f")"
        else
            printf '%-32s NO EXISTE\n' "$f"
        fi
    done
    echo
    echo "--- Etapas del pipeline de Azure Pipelines"
    grep -E '^\s+- stage:' azure-pipelines.yml | sed 's/^/  /'
    echo
    echo "--- Trabajos de GitHub Actions"
    awk '/^jobs:/{dentro=1; next}
         dentro && /^[a-z]/{dentro=0}
         dentro && /^  [a-z_-]+:[[:space:]]*$/{print "  " $0}' \
        .github/workflows/ci.yml
}

# Las otras tres suites del plan de pruebas. La de humo ya queda capturada en
# la evidencia 14; aqui van unitarias, seguridad y rendimiento, y al final el
# reporte HTML que une los cuatro informes JUnit.
pruebas_por_tipo() {
    echo "--- Pruebas unitarias (PHPUnit, casos U01 a U17)"
    bash tests/unitarias/pruebas-unitarias.sh
    echo
    echo "--- Pruebas de seguridad (casos S01 a S11)"
    bash tests/seguridad/pruebas-seguridad.sh
    echo
    echo "--- Pruebas de rendimiento (casos R01 a R05)"
    bash tests/rendimiento/pruebas-rendimiento.sh
    echo
    echo "--- Linea base de rendimiento medida"
    cat tests/resultados/linea-base-rendimiento.txt 2>/dev/null \
        || echo "No se genero la linea base."
    echo
    echo "--- Reporte HTML consolidado de las cuatro suites"
    python3 scripts/reporte-pruebas.py
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
capturar 15 "repositorio-y-ci"           repositorio
capturar 16 "pruebas-por-tipo"           pruebas_por_tipo

# --- Informes de ejecucion ------------------------------------------------
# tests/resultados/ esta en .gitignore por ser salida generada, pero el reporte
# de ejecucion y los informes JUnit son entregables: su copia vive aqui para
# viajar con el repositorio.
INFORMES="${DESTINO}/informes"
mkdir -p "$INFORMES"
copiados=0
for f in "${RAIZ}/tests/resultados/reporte-de-pruebas.html" \
         "${RAIZ}/tests/resultados/linea-base-rendimiento.txt" \
         "${RAIZ}"/tests/resultados/resultados-*.xml; do
    [ -f "$f" ] || continue
    cp "$f" "$INFORMES/" && copiados=$((copiados + 1))
done
echo "  [--] informes de ejecucion copiados a evidencias/informes/ (${copiados} archivos)"

cat > "${INFORMES}/README.md" <<INFORMES_INDICE
# Informes de ejecucion de pruebas

Copia de \`tests/resultados/\`, generada el ${FECHA} por
\`scripts/evidencias.sh\`. La carpeta original esta en \`.gitignore\` por ser
salida generada; esta copia se versiona porque el reporte de ejecucion es un
entregable de la entrega.

| Archivo | Contenido |
|---|---|
| reporte-de-pruebas.html | Reporte consolidado de las cuatro suites. Se abre en cualquier navegador, sin conexion |
| resultados-unitarias.xml | Informe JUnit de PHPUnit, casos U01 a U17 |
| resultados-humo.xml | Informe JUnit de sistema e integracion, casos H01 a H18 |
| resultados-seguridad.xml | Informe JUnit de seguridad, casos S01 a S11 |
| resultados-rendimiento.xml | Informe JUnit de rendimiento, casos R01 a R05 |
| linea-base-rendimiento.txt | Mediciones crudas de latencia y memoria |

Para regenerarlos: \`make probar-todo\` y luego \`make evidencias\`.
INFORMES_INDICE

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
| 15 | 15-repositorio-y-ci.txt | Historial del repositorio, sincronía con GitHub e integración continua |
| 16 | 16-pruebas-por-tipo.txt | Pruebas unitarias, de seguridad y de rendimiento, con la línea base medida |
| — | informes/ | Reporte HTML de la ejecución, los cuatro informes JUnit y la línea base |
INDICE

echo
echo "Listo: ${DESTINO}"
