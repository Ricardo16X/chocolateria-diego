#!/usr/bin/env bash
# =============================================================================
# Artesanal Chocolate Diego — pruebas de rendimiento
#
# Cinco pruebas de carga sobre el sistema levantado con Docker Compose. No
# pretenden dimensionar la produccion: establecen una linea base verificable
# y detectan una regresion gruesa, del orden de magnitud, no de milisegundos.
#
# Produce tres salidas:
#   - resumen legible en la terminal, con las cifras medidas
#   - tests/resultados/resultados-rendimiento.xml en formato JUnit
#   - tests/resultados/linea-base-rendimiento.txt con las mediciones crudas
#
# Uso:
#   make probar-rendimiento
#   bash tests/rendimiento/pruebas-rendimiento.sh
#
# Codigo de salida 0 si todas pasan, 1 si alguna falla.
#
# Los umbrales son deliberadamente holgados frente a lo medido en el equipo
# de desarrollo (p95 de 8 ms en la puerta de enlace, 96 ms en una ruta con
# PHP y base de datos). Un agente hospedado de integracion continua es mas
# lento y comparte su maquina, de modo que un umbral ajustado produciria
# fallos que no corresponden a ninguna regresion real. Se pueden ajustar por
# variable de entorno sin tocar el script.
# =============================================================================
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SALIDA="${RAIZ}/tests/resultados"
XML="${SALIDA}/resultados-rendimiento.xml"
BASE="${SALIDA}/linea-base-rendimiento.txt"
URL="${URL_BASE:-http://localhost:${WEB_PORT:-8080}}"

# Parametros de carga y umbrales, ajustables sin editar el script.
PETICIONES="${PETICIONES:-200}"
CONCURRENCIA="${CONCURRENCIA:-20}"
UMBRAL_P95_GATEWAY="${UMBRAL_P95_GATEWAY:-1.000}"
UMBRAL_P95_SERVICIO="${UMBRAL_P95_SERVICIO:-3.000}"
UMBRAL_MEMORIA_MB="${UMBRAL_MEMORIA_MB:-512}"

cd "$RAIZ" || exit 1
mkdir -p "$SALIDA"

TOTAL=0; FALLIDAS=0; CASOS=""
INICIO_GLOBAL=$(date +%s)

: > "$BASE"
{
    echo "============================================================"
    echo " LINEA BASE DE RENDIMIENTO — Artesanal Chocolate Diego"
    echo " Generada: $(date '+%Y-%m-%d %H:%M:%S')"
    echo " Carga: ${PETICIONES} peticiones, ${CONCURRENCIA} concurrentes"
    echo "============================================================"
    echo
} >> "$BASE"

# -----------------------------------------------------------------------------
# Utilidades
# -----------------------------------------------------------------------------
escapar_xml() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

prueba() {
    local id="$1" grupo="$2" descripcion="$3"; shift 3
    local inicio fin duracion salida resultado
    TOTAL=$((TOTAL + 1))
    inicio=$(date +%s.%N)
    salida=$("$@" 2>&1); resultado=$?
    fin=$(date +%s.%N)
    duracion=$(awk "BEGIN {printf \"%.2f\", $fin - $inicio}")

    local nombre="${id} ${descripcion}"
    local nombre_xml; nombre_xml=$(printf '%s' "$nombre" | escapar_xml)

    if [ "$resultado" -eq 0 ]; then
        printf "  \033[32m[PASA]\033[0m  %s  %s\n" "$id" "$descripcion"
        [ -n "$salida" ] && printf '%s\n' "$salida" | sed 's/^/           /'
        CASOS+="    <testcase classname=\"rendimiento.${grupo}\" name=\"${nombre_xml}\" time=\"${duracion}\"/>"$'\n'
    else
        FALLIDAS=$((FALLIDAS + 1))
        printf "  \033[31m[FALLA]\033[0m %s  %s\n" "$id" "$descripcion"
        printf '%s\n' "$salida" | tail -5 | sed 's/^/           /'
        local detalle; detalle=$(printf '%s' "$salida" | tail -20 | escapar_xml)
        CASOS+="    <testcase classname=\"rendimiento.${grupo}\" name=\"${nombre_xml}\" time=\"${duracion}\">"$'\n'
        CASOS+="      <failure message=\"${nombre_xml}\">${detalle}</failure>"$'\n'
        CASOS+="    </testcase>"$'\n'
    fi
}

# Lanza la carga contra una ruta y escribe "<codigo> <segundos>" por linea.
# xargs -P reparte las peticiones entre procesos concurrentes; es lo que hay
# en cualquier agente de integracion continua, sin instalar una herramienta
# de carga adicional.
cargar() {
    local ruta="$1" n="$2" c="$3"
    seq 1 "$n" | xargs -P "$c" -I{} \
        curl -s -o /dev/null -w '%{http_code} %{time_total}\n' --max-time 30 "${URL}${ruta}"
}

# Calcula el percentil sobre los tiempos ya ordenados. Se ordena con sort,
# no con la funcion asort de awk, que solo existe en gawk y no en el awk por
# defecto de Ubuntu.
percentil() {
    local archivo="$1" p="$2"
    awk '{print $2}' "$archivo" | sort -n \
        | awk -v p="$p" '{t[NR]=$1} END{ if (NR==0) {print "0"; exit} i=int(NR*p); if (i<1) i=1; printf "%.3f", t[i] }'
}

# Compara dos decimales sin depender de bc, que no siempre esta instalado.
menor_o_igual() {
    awk -v a="$1" -v b="$2" 'BEGIN{ exit !(a <= b) }'
}

registrar() {
    printf '%s\n' "$1" >> "$BASE"
}

RESULTADOS_GATEWAY="$(mktemp)"
RESULTADOS_SERVICIO="$(mktemp)"
trap 'rm -f "$RESULTADOS_GATEWAY" "$RESULTADOS_SERVICIO"' EXIT

# -----------------------------------------------------------------------------
# Carga sostenida
# -----------------------------------------------------------------------------

# R01: ninguna peticion se pierde. Es la prueba mas importante del grupo: un
# 502 bajo carga significaria que la puerta de enlace agota conexiones contra
# PHP-FPM antes de que el sistema este siquiera ocupado.
p_sin_errores_bajo_carga() {
    cargar /estado "$PETICIONES" "$CONCURRENCIA" > "$RESULTADOS_GATEWAY"

    local total exitosas
    total=$(wc -l < "$RESULTADOS_GATEWAY")
    exitosas=$(awk '$1=="200"' "$RESULTADOS_GATEWAY" | wc -l)

    registrar "R01  /estado  ${total} peticiones, ${exitosas} con HTTP 200"
    if [ "$total" != "$PETICIONES" ] || [ "$exitosas" != "$PETICIONES" ]; then
        echo "De ${PETICIONES} peticiones se completaron ${total} y solo ${exitosas} con HTTP 200."
        awk '$1!="200"{print "  codigo " $1}' "$RESULTADOS_GATEWAY" | sort | uniq -c | head
        return 1
    fi
    echo "${exitosas}/${PETICIONES} respuestas HTTP 200, ${CONCURRENCIA} concurrentes"
}

# R02: latencia de la puerta de enlace sola, sin PHP de por medio.
p_p95_gateway() {
    [ -s "$RESULTADOS_GATEWAY" ] || { echo "No hay mediciones: R01 no se ejecuto."; return 1; }

    local p50 p95
    p50=$(percentil "$RESULTADOS_GATEWAY" 0.50)
    p95=$(percentil "$RESULTADOS_GATEWAY" 0.95)

    registrar "R02  /estado  p50=${p50}s  p95=${p95}s  umbral=${UMBRAL_P95_GATEWAY}s"
    menor_o_igual "$p95" "$UMBRAL_P95_GATEWAY" \
        || { echo "El p95 fue ${p95}s, por encima del umbral de ${UMBRAL_P95_GATEWAY}s."; return 1; }
    echo "p50=${p50}s  p95=${p95}s  (umbral ${UMBRAL_P95_GATEWAY}s)"
}

# R03: latencia de una ruta que si atraviesa PHP-FPM y consulta la base y
# Redis. Es la cifra que representa al sistema completo.
p_p95_microservicio() {
    cargar /api/auth/salud "$PETICIONES" "$CONCURRENCIA" > "$RESULTADOS_SERVICIO"

    local exitosas p50 p95
    exitosas=$(awk '$1=="200"' "$RESULTADOS_SERVICIO" | wc -l)
    p50=$(percentil "$RESULTADOS_SERVICIO" 0.50)
    p95=$(percentil "$RESULTADOS_SERVICIO" 0.95)

    registrar "R03  /api/auth/salud  ${exitosas}/${PETICIONES} con HTTP 200  p50=${p50}s  p95=${p95}s  umbral=${UMBRAL_P95_SERVICIO}s"
    [ "$exitosas" = "$PETICIONES" ] \
        || { echo "Solo ${exitosas} de ${PETICIONES} respondieron 200."; return 1; }
    menor_o_igual "$p95" "$UMBRAL_P95_SERVICIO" \
        || { echo "El p95 fue ${p95}s, por encima del umbral de ${UMBRAL_P95_SERVICIO}s."; return 1; }
    echo "p50=${p50}s  p95=${p95}s  (umbral ${UMBRAL_P95_SERVICIO}s)"
}

# -----------------------------------------------------------------------------
# Aislamiento bajo carga
# -----------------------------------------------------------------------------

# R04: la separacion por dominio tiene que sobrevivir a la carga. Con los
# cuatro prefijos golpeados a la vez, cada respuesta debe seguir viniendo del
# microservicio que le corresponde: si la puerta de enlace mezclara el
# enrutamiento bajo presion, este caso lo detecta.
p_enrutamiento_bajo_carga() {
    local fallos=""
    for par in "auth" "catalogo" "pedidos" "pagos"; do
        local obtenidos distintos
        obtenidos=$(seq 1 25 | xargs -P 10 -I{} \
            curl -s -o /dev/null -D - --max-time 30 "${URL}/api/${par}/salud" \
            | awk 'tolower($1)=="x-servicio:" {print $2}' | tr -d '\r' | sort -u)
        distintos=$(printf '%s\n' "$obtenidos" | grep -c .)
        if [ "$distintos" != "1" ] || [ "$obtenidos" != "$par" ]; then
            fallos+=" /api/${par} atendido por '${obtenidos//$'\n'/,}'"
        fi
    done

    registrar "R04  25 peticiones concurrentes por prefijo: enrutamiento $([ -z "$fallos" ] && echo correcto || echo incorrecto)"
    [ -z "$fallos" ] || { echo "Enrutamiento incorrecto bajo carga:${fallos}"; return 1; }
    echo "los cuatro prefijos siguen atendidos por su propio microservicio"
}

# R05: la carga no debe dejar ningun contenedor con la memoria desbocada.
# Es un techo de cordura, no un presupuesto de capacidad.
p_memoria_tras_la_carga() {
    local excedidos="" detalle=""
    while read -r nombre uso; do
        [ -n "$nombre" ] || continue
        local mb
        mb=$(printf '%s' "$uso" | awk '
            /GiB|GB/ { gsub(/[^0-9.]/,""); printf "%.0f", $0*1024; exit }
            /MiB|MB/ { gsub(/[^0-9.]/,""); printf "%.0f", $0; exit }
            /KiB|kB/ { gsub(/[^0-9.]/,""); printf "%.0f", $0/1024; exit }
            { gsub(/[^0-9.]/,""); printf "%.0f", $0/1048576 }')
        detalle+="${nombre}=${mb}MB "
        [ "${mb:-0}" -le "$UMBRAL_MEMORIA_MB" ] || excedidos+=" ${nombre}=${mb}MB"
    done < <(docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' 2>/dev/null | awk '{print $1, $2}')

    registrar "R05  memoria tras la carga: ${detalle}(umbral ${UMBRAL_MEMORIA_MB}MB)"
    [ -n "$detalle" ] || { echo "No se pudo leer el consumo de memoria."; return 1; }
    [ -z "$excedidos" ] || { echo "Contenedores por encima de ${UMBRAL_MEMORIA_MB}MB:${excedidos}"; return 1; }
    echo "ningun contenedor supera ${UMBRAL_MEMORIA_MB}MB"
}

# -----------------------------------------------------------------------------
# Ejecucion
# -----------------------------------------------------------------------------
echo "================================================================"
echo " PRUEBAS DE RENDIMIENTO — Artesanal Chocolate Diego"
echo " Destino: ${URL}"
echo " Carga:   ${PETICIONES} peticiones, ${CONCURRENCIA} concurrentes"
echo "================================================================"

echo
echo " Carga sostenida"
prueba R01 carga "La puerta de enlace atiende la carga sin un solo error"  p_sin_errores_bajo_carga
prueba R02 carga "El p95 de la puerta de enlace esta bajo el umbral"       p_p95_gateway
prueba R03 carga "El p95 de una ruta con PHP y base esta bajo el umbral"   p_p95_microservicio

echo
echo " Aislamiento bajo carga"
prueba R04 aislamiento "El enrutamiento por dominio se mantiene bajo carga" p_enrutamiento_bajo_carga
prueba R05 aislamiento "Ningun contenedor desborda su memoria tras la carga" p_memoria_tras_la_carga

DURACION=$(( $(date +%s) - INICIO_GLOBAL ))

cat > "$XML" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Artesanal Chocolate Diego" tests="${TOTAL}" failures="${FALLIDAS}" time="${DURACION}">
  <testsuite name="Pruebas de rendimiento" tests="${TOTAL}" failures="${FALLIDAS}" errors="0" time="${DURACION}" timestamp="$(date -u +%Y-%m-%dT%H:%M:%S)">
${CASOS}  </testsuite>
</testsuites>
XML

{
    echo
    echo "Resultado: ${TOTAL} pruebas, $((TOTAL - FALLIDAS)) pasan, ${FALLIDAS} fallan."
} >> "$BASE"

echo
echo "================================================================"
echo " ${TOTAL} pruebas · $((TOTAL - FALLIDAS)) pasan · ${FALLIDAS} fallan · ${DURACION} s"
echo " Resultados JUnit: tests/resultados/resultados-rendimiento.xml"
echo " Linea base:       tests/resultados/linea-base-rendimiento.txt"
echo "================================================================"

[ "$FALLIDAS" -eq 0 ]
