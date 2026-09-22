#!/usr/bin/env bash
# =============================================================================
# Artesanal Chocolate Diego — pruebas de humo
#
# Dieciocho pruebas sobre el sistema levantado con Docker Compose, en cuatro
# grupos: infraestructura, microservicios, base de datos y flujo de venta.
#
# Produce dos salidas:
#   - resumen legible en la terminal
#   - tests/resultados/resultados-humo.xml en formato JUnit, que Azure
#     Pipelines y GitHub Actions publican como resultados de prueba
#
# Uso:
#   make probar
#   bash tests/humo/pruebas-humo.sh
#
# Codigo de salida 0 si todas pasan, 1 si alguna falla.
#
# Las pruebas del flujo de venta escriben datos reales: un producto con codigo
# que empieza por "PH-", su lote, una venta y su anulacion. Son faciles de
# identificar y no alteran el cuadre del kardex.
# =============================================================================
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SALIDA="${RAIZ}/tests/resultados"
XML="${SALIDA}/resultados-humo.xml"
URL="${URL_BASE:-http://localhost:${WEB_PORT:-8080}}"
COMPOSE="docker compose"

cd "$RAIZ" || exit 1
mkdir -p "$SALIDA"

TOTAL=0; FALLIDAS=0; CASOS=""
INICIO_GLOBAL=$(date +%s)

# -----------------------------------------------------------------------------
# Utilidades
# -----------------------------------------------------------------------------
escapar_xml() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# prueba <id> <grupo> <descripcion> <comando...>
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
        CASOS+="    <testcase classname=\"humo.${grupo}\" name=\"${nombre_xml}\" time=\"${duracion}\"/>"$'\n'
    else
        FALLIDAS=$((FALLIDAS + 1))
        printf "  \033[31m[FALLA]\033[0m %s  %s\n" "$id" "$descripcion"
        printf '%s\n' "$salida" | tail -5 | sed 's/^/           /'
        local detalle; detalle=$(printf '%s' "$salida" | tail -20 | escapar_xml)
        CASOS+="    <testcase classname=\"humo.${grupo}\" name=\"${nombre_xml}\" time=\"${duracion}\">"$'\n'
        CASOS+="      <failure message=\"${nombre_xml}\">${detalle}</failure>"$'\n'
        CASOS+="    </testcase>"$'\n'
    fi
}

# Ejecuta SQL en la base, en una sola sesion, y devuelve el resultado en crudo.
sql() {
    printf '%s\n' "$1" | $COMPOSE exec -T db sh -c \
        'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -N -B 2>&1' \
        | grep -v "Using a password on the command line"
}

esperar_saludable() {
    local contenedor="$1" limite="${2:-30}"
    for _ in $(seq 1 "$limite"); do
        local estado
        estado=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$contenedor" 2>/dev/null)
        case "$estado" in healthy|running) return 0 ;; esac
        sleep 2
    done
    return 1
}

cabecera_servicio() {
    curl -s -o /dev/null -D - --max-time 10 "${URL}$1" \
        | awk 'tolower($1)=="x-servicio:" {print $2}' | tr -d '\r'
}

codigo_http() {
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${URL}$1"
}

# -----------------------------------------------------------------------------
# Definicion de las pruebas
# -----------------------------------------------------------------------------

# ---- Infraestructura --------------------------------------------------------
p_contenedores() {
    local esperados="chdiego_gateway chdiego_auth chdiego_catalogo chdiego_pedidos chdiego_pagos chdiego_db chdiego_cache chdiego_queue chdiego_scheduler"
    local faltan=""
    for c in $esperados; do
        [ "$(docker inspect --format '{{.State.Running}}' "$c" 2>/dev/null)" = "true" ] || faltan+=" $c"
    done
    [ -z "$faltan" ] || { echo "No estan en ejecucion:${faltan}"; return 1; }
}

p_db_saludable() {
    [ "$(docker inspect --format '{{.State.Health.Status}}' chdiego_db)" = "healthy" ]
}

p_redis() {
    [ "$($COMPOSE exec -T cache redis-cli ping | tr -d '\r')" = "PONG" ]
}

p_gateway() {
    local cuerpo; cuerpo=$(curl -s --max-time 10 "${URL}/estado")
    echo "$cuerpo" | grep -q '"estado":"ok"' || { echo "Respuesta: $cuerpo"; return 1; }
}

# ---- Microservicios ---------------------------------------------------------
p_ruta() {
    local prefijo="$1" esperado="$2" obtenido
    obtenido=$(cabecera_servicio "$prefijo")
    [ "$obtenido" = "$esperado" ] || { echo "Esperado ${esperado}, atendio '${obtenido}'"; return 1; }
}

p_aislamiento_puertos() {
    local expuestos=""
    for s in auth catalogo pedidos pagos; do
        [ -z "$(docker port "chdiego_${s}" 2>/dev/null)" ] || expuestos+=" ${s}"
    done
    [ -z "$expuestos" ] || { echo "Publican puertos al exterior:${expuestos}"; return 1; }
}

p_tolerancia_fallos() {
    # Se detiene pagos: su prefijo debe fallar y los demas deben seguir.
    $COMPOSE stop pagos >/dev/null 2>&1
    sleep 3
    local pagos_caido auth_vivo
    pagos_caido=$(codigo_http /api/pagos/salud)
    auth_vivo=$(codigo_http /api/auth/salud)
    $COMPOSE start pagos >/dev/null 2>&1
    local pagos_recuperado="502"
    for _ in $(seq 1 30); do
        pagos_recuperado=$(codigo_http /api/pagos/salud)
        [ "$pagos_recuperado" != "502" ] && break
        sleep 2
    done

    echo "pagos detenido=${pagos_caido}  auth durante la caida=${auth_vivo}  pagos recuperado=${pagos_recuperado}"
    [ "$pagos_caido" = "502" ] && [ "$auth_vivo" != "502" ] && [ "$pagos_recuperado" != "502" ]
}

p_extensiones() {
    local faltan=""
    for s in auth catalogo pedidos pagos; do
        local mods; mods=$($COMPOSE exec -T "$s" php -m 2>/dev/null)
        for ext in pdo_mysql redis bcmath intl; do
            echo "$mods" | grep -qi "^${ext}$" || faltan+=" ${s}:${ext}"
        done
    done
    [ -z "$faltan" ] || { echo "Extensiones faltantes:${faltan}"; return 1; }
}

# ---- Base de datos ----------------------------------------------------------
p_esquema() {
    $COMPOSE exec -T db bash -c 'DB_HOST=localhost DB_USER=root \
        DB_PASS="$MYSQL_ROOT_PASSWORD" DB_NAME="$MYSQL_DATABASE" bash -s' \
        < scripts/verificar-esquema.sh
}

p_catalogos() {
    local r
    r=$(sql "SELECT
        (SELECT COUNT(*) FROM tipo_movimiento WHERE nombre='venta' AND efecto='resta'),
        (SELECT COUNT(*) FROM tipo_movimiento WHERE nombre='devolucion' AND efecto='suma'),
        (SELECT COUNT(*) FROM usuario u JOIN rol r ON r.id_rol=u.id_rol
          WHERE u.nombre_usuario='admin' AND r.nombre='Administrador'),
        (SELECT COUNT(*) FROM zona_cobertura);")
    echo "venta, devolucion, admin, zonas = ${r}"
    [ "$(echo "$r" | awk '{print ($1>=1 && $2>=1 && $3==1 && $4>=4) ? "ok" : "no"}')" = "ok" ]
}

# ---- Flujo de venta ---------------------------------------------------------
CODIGO="PH-$(date +%s)"

p_alta_inventario() {
    local r
    r=$(sql "
        SET @cat    = (SELECT id_categoria FROM categoria WHERE nombre='Tabletas' LIMIT 1);
        SET @bod    = (SELECT id_bodega FROM bodega WHERE tipo='sala_venta' LIMIT 1);
        SET @admin  = (SELECT id_usuario FROM usuario WHERE nombre_usuario='admin');
        SET @compra = (SELECT id_tipo_movimiento FROM tipo_movimiento WHERE nombre='compra');
        CALL sp_registrar_producto(@cat, '${CODIGO}', 'Producto de prueba de humo', NULL,
             70, 'unidad', 25.00, 10.00, 0, 30, 1, 0, @prod);
        INSERT INTO lote (id_producto, codigo_lote, fecha_produccion, fecha_vencimiento, cantidad_inicial)
             VALUES (@prod, 'L-${CODIGO}', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 90 DAY), 10);
        SET @lote = LAST_INSERT_ID();
        CALL sp_ajustar_inventario(@prod, @bod, @lote, @compra, 10, @admin, NULL, 'Prueba de humo');
        SELECT fn_stock_disponible(@prod);")
    echo "Existencia tras la entrada: ${r}"
    [ "$(echo "$r" | tail -1)" = "10.000" ]
}

p_venta() {
    local r
    r=$(sql "
        SET @prod  = (SELECT id_producto FROM producto WHERE codigo='${CODIGO}');
        SET @admin = (SELECT id_usuario FROM usuario WHERE nombre_usuario='admin');
        SET @pago  = (SELECT id_metodo_pago FROM metodo_pago WHERE nombre='Efectivo');
        CALL sp_registrar_venta(@admin, NULL, NULL, @pago, 'presencial', 0, NULL, NULL,
             NULL, NULL, JSON_ARRAY(JSON_OBJECT('id_producto', @prod, 'cantidad', 3)), @venta, @fel);
        SELECT fn_stock_disponible(@prod), v.estado, v.total, df.estado, df.nit_receptor
          FROM venta v JOIN documento_fel df ON df.id_venta = v.id_venta
         WHERE v.id_venta = @venta;")
    echo "existencia, estado venta, total, estado FEL, NIT = ${r}"
    set -- $r
    [ "$1" = "7.000" ] && [ "$2" = "completada" ] && [ "$3" = "75.00" ] && [ "$4" = "pendiente" ] && [ "$5" = "CF" ]
}

p_bitacora() {
    local r
    r=$(sql "SELECT COUNT(*) FROM bitacora b
              JOIN venta v ON v.id_venta = b.id_registro AND b.tabla_afectada = 'venta'
              JOIN detalle_venta dv ON dv.id_venta = v.id_venta
              JOIN producto p ON p.id_producto = dv.id_producto
             WHERE p.codigo = '${CODIGO}' AND b.evento = 'venta';")
    echo "Asientos de venta en bitacora: ${r}"
    [ "$r" -ge 1 ]
}

p_anulacion() {
    local r
    r=$(sql "
        SET @prod  = (SELECT id_producto FROM producto WHERE codigo='${CODIGO}');
        SET @admin = (SELECT id_usuario FROM usuario WHERE nombre_usuario='admin');
        SET @venta = (SELECT dv.id_venta FROM detalle_venta dv WHERE dv.id_producto = @prod LIMIT 1);
        CALL sp_anular_venta(@venta, @admin, 'Prueba de humo');
        SELECT fn_stock_disponible(@prod), v.estado, df.estado
          FROM venta v JOIN documento_fel df ON df.id_venta = v.id_venta
         WHERE v.id_venta = @venta;")
    echo "existencia, estado venta, estado FEL = ${r}"
    set -- $r
    [ "$1" = "10.000" ] && [ "$2" = "anulada" ] && [ "$3" = "anulado" ]
}

p_kardex() {
    local r
    r=$(sql "
        SELECT COUNT(*) FROM existencia e
        LEFT JOIN (
            SELECT mi.id_producto, mi.id_bodega, COALESCE(mi.id_lote,0) AS lote_clave,
                   SUM(CASE WHEN tm.efecto='suma' THEN mi.cantidad ELSE -mi.cantidad END) AS saldo
              FROM movimiento_inventario mi
              JOIN tipo_movimiento tm ON tm.id_tipo_movimiento = mi.id_tipo_movimiento
             GROUP BY mi.id_producto, mi.id_bodega, COALESCE(mi.id_lote,0)
        ) k ON k.id_producto = e.id_producto AND k.id_bodega = e.id_bodega AND k.lote_clave = e.lote_clave
        WHERE e.cantidad_disponible <> COALESCE(k.saldo, 0);")
    echo "Registros de existencia que no cuadran con el kardex: ${r}"
    [ "$r" = "0" ]
}

# -----------------------------------------------------------------------------
# Ejecucion
# -----------------------------------------------------------------------------
echo
echo "================================================================"
echo " PRUEBAS DE HUMO — Artesanal Chocolate Diego"
echo " Destino: ${URL}"
echo "================================================================"

echo; echo " Infraestructura"
prueba H01 infraestructura "Los nueve contenedores estan en ejecucion"          p_contenedores
prueba H02 infraestructura "La base de datos reporta estado saludable"          p_db_saludable
prueba H03 infraestructura "Redis responde a PING"                              p_redis
prueba H04 infraestructura "La puerta de enlace responde en /estado"            p_gateway

echo; echo " Microservicios"
prueba H05 microservicios "La puerta de enlace enruta /api/auth a auth"         p_ruta /api/auth/salud auth
prueba H06 microservicios "La puerta de enlace enruta /api/catalogo a catalogo" p_ruta /api/catalogo/salud catalogo
prueba H07 microservicios "La puerta de enlace enruta /api/pedidos a pedidos"   p_ruta /api/pedidos/salud pedidos
prueba H08 microservicios "La puerta de enlace enruta /api/pagos a pagos"       p_ruta /api/pagos/salud pagos
prueba H09 microservicios "Los microservicios no publican puertos al exterior"  p_aislamiento_puertos
prueba H10 microservicios "Los cuatro microservicios tienen sus extensiones"    p_extensiones
prueba H11 microservicios "La caida de pagos no afecta a auth y se recupera"    p_tolerancia_fallos

echo; echo " Base de datos"
prueba H12 base_datos "El esquema corresponde al Octavo Documento"             p_esquema
prueba H13 base_datos "Los catalogos base estan cargados"                      p_catalogos

echo; echo " Flujo de venta"
prueba H14 flujo_venta "Alta de producto, lote y entrada de inventario"        p_alta_inventario
prueba H15 flujo_venta "Venta a consumidor final descuenta y genera DTE"       p_venta
prueba H16 flujo_venta "La venta queda registrada en la bitacora"              p_bitacora
prueba H17 flujo_venta "La anulacion restituye la existencia y anula el DTE"   p_anulacion
prueba H18 flujo_venta "El kardex cuadra despues del ciclo completo"           p_kardex

DURACION=$(( $(date +%s) - INICIO_GLOBAL ))

cat > "$XML" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Artesanal Chocolate Diego" tests="${TOTAL}" failures="${FALLIDAS}" time="${DURACION}">
  <testsuite name="Pruebas de humo" tests="${TOTAL}" failures="${FALLIDAS}" errors="0" time="${DURACION}" timestamp="$(date -u +%Y-%m-%dT%H:%M:%S)">
${CASOS}  </testsuite>
</testsuites>
XML

echo
echo "================================================================"
echo " ${TOTAL} pruebas · $((TOTAL - FALLIDAS)) pasan · ${FALLIDAS} fallan · ${DURACION} s"
echo " Resultados JUnit: tests/resultados/resultados-humo.xml"
echo "================================================================"

[ "$FALLIDAS" -eq 0 ]
