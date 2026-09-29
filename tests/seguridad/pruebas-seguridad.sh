#!/usr/bin/env bash
# =============================================================================
# Artesanal Chocolate Diego — pruebas de seguridad
#
# Once pruebas sobre el sistema levantado con Docker Compose, en tres grupos:
# control de acceso, endurecimiento de la plataforma y manejo de secretos.
#
# Produce dos salidas:
#   - resumen legible en la terminal
#   - tests/resultados/resultados-seguridad.xml en formato JUnit, que Azure
#     Pipelines y GitHub Actions publican como resultados de prueba
#
# Uso:
#   make probar-seguridad
#   bash tests/seguridad/pruebas-seguridad.sh
#
# Codigo de salida 0 si todas pasan, 1 si alguna falla.
#
# Las pruebas de control de acceso crean dos usuarios temporales con el
# prefijo "ps_" (prueba de seguridad) y los borran al terminar, incluso si
# una prueba falla. No modifican ningun usuario existente.
# =============================================================================
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SALIDA="${RAIZ}/tests/resultados"
XML="${SALIDA}/resultados-seguridad.xml"
URL="${URL_BASE:-http://localhost:${WEB_PORT:-8080}}"
COMPOSE="docker compose"
GALLETAS="$(mktemp -d)/galletas.txt"

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
        CASOS+="    <testcase classname=\"seguridad.${grupo}\" name=\"${nombre_xml}\" time=\"${duracion}\"/>"$'\n'
    else
        FALLIDAS=$((FALLIDAS + 1))
        printf "  \033[31m[FALLA]\033[0m %s  %s\n" "$id" "$descripcion"
        printf '%s\n' "$salida" | tail -5 | sed 's/^/           /'
        local detalle; detalle=$(printf '%s' "$salida" | tail -20 | escapar_xml)
        CASOS+="    <testcase classname=\"seguridad.${grupo}\" name=\"${nombre_xml}\" time=\"${duracion}\">"$'\n'
        CASOS+="      <failure message=\"${nombre_xml}\">${detalle}</failure>"$'\n'
        CASOS+="    </testcase>"$'\n'
    fi
}

sql() {
    printf '%s\n' "$1" | $COMPOSE exec -T db sh -c \
        'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -N -B 2>&1' \
        | grep -v "Using a password on the command line"
}

# Inicia sesion por el formulario real, con token CSRF y cookie de sesion.
# Imprime la URL a la que redirige el POST: /panel si entro, /ingreso si no.
# Ese destino es la senal, no el codigo HTTP: ambos casos responden 302.
iniciar_sesion() {
    local usuario="$1" clave="$2" token
    rm -f "$GALLETAS"
    token=$(curl -s -c "$GALLETAS" --max-time 10 "${URL}/ingreso" \
        | grep -oE 'name="_token" value="[^"]+"' | head -1 | sed 's/.*value="//;s/"$//')
    [ -n "$token" ] || { echo "No se obtuvo el token CSRF del formulario."; return 1; }
    curl -s -b "$GALLETAS" -c "$GALLETAS" -o /dev/null --max-time 10 \
        -w '%{redirect_url}' \
        -X POST -d "_token=${token}&nombre_usuario=${usuario}&password=${clave}" \
        "${URL}/ingreso"
}

# Pide una ruta con la sesion ya iniciada por iniciar_sesion().
codigo_autenticado() {
    curl -s -b "$GALLETAS" -o /dev/null -w '%{http_code}' --max-time 10 "${URL}$1"
}

# Los dos usuarios temporales reutilizan el hash del admin, que corresponde
# a la contrasena documentada. No se crean hashes nuevos ni se toca el admin.
crear_usuarios_de_prueba() {
    local hash
    hash=$(sql "SELECT contrasena_hash FROM usuario WHERE nombre_usuario='admin';")
    [ -n "$hash" ] || { echo "No se pudo leer el hash del admin."; return 1; }

    sql "DELETE FROM usuario WHERE nombre_usuario LIKE 'ps\\_%';" >/dev/null
    sql "INSERT INTO usuario (id_rol, nombre, apellido, nombre_usuario, correo, contrasena_hash, estado)
         VALUES (1, 'Prueba', 'Bloqueada', 'ps_bloqueado', 'ps_bloqueado@prueba.local', '${hash}', 'bloqueado'),
                (4, 'Prueba', 'Bodega',    'ps_bodega',    'ps_bodega@prueba.local',    '${hash}', 'activo');" >/dev/null

    local n
    n=$(sql "SELECT COUNT(*) FROM usuario WHERE nombre_usuario LIKE 'ps\\_%';")
    [ "$n" = "2" ] || { echo "Se esperaban 2 usuarios de prueba, hay ${n}."; return 1; }
}

borrar_usuarios_de_prueba() {
    sql "DELETE FROM bitacora WHERE id_usuario IN (SELECT id_usuario FROM usuario WHERE nombre_usuario LIKE 'ps\\_%');" >/dev/null 2>&1
    sql "DELETE FROM usuario WHERE nombre_usuario LIKE 'ps\\_%';" >/dev/null 2>&1
    rm -f "$GALLETAS"
}
trap borrar_usuarios_de_prueba EXIT

# -----------------------------------------------------------------------------
# Control de acceso
# -----------------------------------------------------------------------------

# Las rutas del panel y del punto de venta no pueden entregar contenido a
# quien no ha iniciado sesion.
p_rutas_protegidas() {
    local fallos=""
    for ruta in /panel /punto-venta; do
        local destino
        destino=$(curl -s -o /dev/null -w '%{redirect_url}' --max-time 10 "${URL}${ruta}")
        case "$destino" in
            */ingreso) : ;;
            *) fallos+=" ${ruta}->'${destino}'" ;;
        esac
    done
    [ -z "$fallos" ] || { echo "No redirigieron al ingreso:${fallos}"; return 1; }
}

# Un POST sin token CSRF debe ser rechazado con 419, no procesado.
p_csrf_obligatorio() {
    local codigo
    codigo=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
        -X POST -d 'nombre_usuario=admin&password=Chocolate2026' "${URL}/ingreso")
    [ "$codigo" = "419" ] || { echo "Se esperaba 419, se obtuvo ${codigo}."; return 1; }
}

# Control positivo: con credenciales validas el ingreso si funciona. Sin esta
# prueba, las tres siguientes pasarian igual si el login estuviera roto.
p_ingreso_valido() {
    local destino
    destino=$(iniciar_sesion admin Chocolate2026)
    case "$destino" in
        */panel) : ;;
        *) echo "El ingreso valido no llego al panel, redirigio a '${destino}'."; return 1 ;;
    esac
}

# Una cuenta con estado 'bloqueado' no entra aunque la contrasena sea correcta:
# lo niega App\Auth\UsuarioProvider antes de comparar el hash.
p_cuenta_bloqueada() {
    local destino
    destino=$(iniciar_sesion ps_bloqueado Chocolate2026)
    case "$destino" in
        */panel) echo "Una cuenta bloqueada llego al panel."; return 1 ;;
        */ingreso) : ;;
        *) echo "Destino inesperado: '${destino}'."; return 1 ;;
    esac
}

# Un usuario autenticado sin el permiso ventas.registrar no entra al punto de
# venta. El rol 'Personal de Bodega' no tiene ese permiso.
p_permiso_denegado() {
    local destino codigo
    destino=$(iniciar_sesion ps_bodega Chocolate2026)
    case "$destino" in
        */panel) : ;;
        *) echo "El usuario de bodega no pudo iniciar sesion, redirigio a '${destino}'."; return 1 ;;
    esac
    codigo=$(codigo_autenticado /punto-venta)
    [ "$codigo" = "403" ] || { echo "Se esperaba 403 en /punto-venta, se obtuvo ${codigo}."; return 1; }
}

# -----------------------------------------------------------------------------
# Endurecimiento de la plataforma
# -----------------------------------------------------------------------------

# La puerta de enlace no debe revelar la version del servidor: es informacion
# gratuita para quien busca una vulnerabilidad conocida (server_tokens off).
p_version_no_revelada() {
    local cabecera
    cabecera=$(curl -sI --max-time 10 "${URL}/" | awk 'tolower($1)=="server:" {print $2}' | tr -d '\r')
    [ -n "$cabecera" ] || { echo "No se recibio cabecera Server."; return 1; }
    case "$cabecera" in
        *[0-9].[0-9]*) echo "La cabecera Server revela version: '${cabecera}'."; return 1 ;;
        *) : ;;
    esac
}

p_cabeceras_de_seguridad() {
    local cabeceras faltan=""
    cabeceras=$(curl -sI --max-time 10 "${URL}/" | tr 'A-Z' 'a-z')
    for c in x-frame-options x-content-type-options referrer-policy; do
        printf '%s' "$cabeceras" | grep -q "^${c}:" || faltan+=" ${c}"
    done
    [ -z "$faltan" ] || { echo "Faltan cabeceras:${faltan}"; return 1; }
}

# Los cuatro microservicios corren como el usuario 'laravel', no como root.
# El gateway queda fuera a proposito: la imagen oficial de nginx arranca su
# proceso maestro como root y baja los trabajadores a un usuario sin
# privilegios, que es su diseno y no algo que este proyecto deba alterar.
p_sin_root_en_microservicios() {
    local fallos=""
    for s in auth catalogo pedidos pagos; do
        local usuario
        usuario=$($COMPOSE exec -T "$s" whoami 2>/dev/null | tr -d '\r')
        [ "$usuario" = "laravel" ] || fallos+=" ${s}='${usuario}'"
    done
    [ -z "$fallos" ] || { echo "No corren como laravel:${fallos}"; return 1; }
}

# -----------------------------------------------------------------------------
# Manejo de secretos
# -----------------------------------------------------------------------------

# La aplicacion no se conecta a MySQL como root: usa una cuenta con permisos
# solo sobre su propia base.
p_usuario_de_bd_sin_privilegios() {
    local usuario
    usuario=$($COMPOSE exec -T catalogo sh -c 'printf "%s" "$DB_USERNAME"' 2>/dev/null | tr -d '\r')
    [ -n "$usuario" ] || { echo "DB_USERNAME esta vacio en el contenedor."; return 1; }
    [ "$usuario" != "root" ] || { echo "La aplicacion se conecta a MySQL como root."; return 1; }
}

# Ninguna contrasena se guarda en claro: todas son hash bcrypt de 60
# caracteres. Se revisan todas las filas, no solo el admin.
p_contrasenas_hasheadas() {
    local malas
    malas=$(sql "SELECT COUNT(*) FROM usuario
                 WHERE contrasena_hash NOT LIKE '\$2y\$%' OR LENGTH(contrasena_hash) <> 60;")
    [ "$malas" = "0" ] || { echo "${malas} usuarios sin hash bcrypt valido."; return 1; }
}

# El .env no puede quedar horneado en la imagen: los secretos entran por
# variables de entorno al arrancar el contenedor, no en una capa publicable.
p_sin_env_en_la_imagen() {
    local fallos=""
    for s in auth catalogo pedidos pagos; do
        local salida
        salida=$(docker run --rm --entrypoint sh "chocolate-diego/${s}:${APP_VERSION:-dev}" \
            -c 'test -f /var/www/html/.env && echo PRESENTE || echo AUSENTE' 2>&1 | tr -d '\r')
        case "$salida" in
            *AUSENTE*) : ;;
            *) fallos+=" ${s}" ;;
        esac
    done
    [ -z "$fallos" ] || { echo "La imagen lleva un .env horneado:${fallos}"; return 1; }
}

# -----------------------------------------------------------------------------
# Ejecucion
# -----------------------------------------------------------------------------
echo "================================================================"
echo " PRUEBAS DE SEGURIDAD — Artesanal Chocolate Diego"
echo " Destino: ${URL}"
echo "================================================================"

if ! salida_preparacion=$(crear_usuarios_de_prueba 2>&1); then
    echo
    echo " No se pudieron crear los usuarios temporales de prueba:"
    printf '%s\n' "$salida_preparacion" | sed 's/^/   /'
    echo " Verifique que el sistema este levantado: make arriba"
    exit 1
fi

echo
echo " Control de acceso"
prueba S01 acceso "Las rutas protegidas no responden sin sesion"            p_rutas_protegidas
prueba S02 acceso "Un POST sin token CSRF es rechazado con 419"             p_csrf_obligatorio
prueba S03 acceso "El ingreso con credenciales validas funciona"            p_ingreso_valido
prueba S04 acceso "Una cuenta bloqueada no inicia sesion"                   p_cuenta_bloqueada
prueba S05 acceso "Sin el permiso ventas.registrar el punto de venta da 403" p_permiso_denegado

echo
echo " Endurecimiento de la plataforma"
prueba S06 plataforma "La puerta de enlace no revela la version del servidor" p_version_no_revelada
prueba S07 plataforma "La puerta de enlace envia las cabeceras de seguridad"  p_cabeceras_de_seguridad
prueba S08 plataforma "Los microservicios no corren como root"               p_sin_root_en_microservicios

echo
echo " Manejo de secretos"
prueba S09 secretos "La aplicacion no se conecta a MySQL como root"          p_usuario_de_bd_sin_privilegios
prueba S10 secretos "Todas las contrasenas son hash bcrypt de 60 caracteres" p_contrasenas_hasheadas
prueba S11 secretos "Las imagenes no llevan el archivo .env horneado"        p_sin_env_en_la_imagen

DURACION=$(( $(date +%s) - INICIO_GLOBAL ))

cat > "$XML" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Artesanal Chocolate Diego" tests="${TOTAL}" failures="${FALLIDAS}" time="${DURACION}">
  <testsuite name="Pruebas de seguridad" tests="${TOTAL}" failures="${FALLIDAS}" errors="0" time="${DURACION}" timestamp="$(date -u +%Y-%m-%dT%H:%M:%S)">
${CASOS}  </testsuite>
</testsuites>
XML

echo
echo "================================================================"
echo " ${TOTAL} pruebas · $((TOTAL - FALLIDAS)) pasan · ${FALLIDAS} fallan · ${DURACION} s"
echo " Resultados JUnit: tests/resultados/resultados-seguridad.xml"
echo "================================================================"

[ "$FALLIDAS" -eq 0 ]
