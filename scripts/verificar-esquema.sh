#!/usr/bin/env bash
# ============================================================================
# Artesanal Chocolate Diego — verificar-esquema.sh
#
# Comprueba que la base de datos implementada corresponde exactamente a lo
# declarado en el Octavo Documento de Proyecto. La salida de este script es
# la evidencia de trazabilidad entre el documento y la implementacion.
#
# Uso:
#   ./verificar-esquema.sh
#   DB_HOST=db DB_USER=root DB_PASS=secreto ./verificar-esquema.sh
#
# Codigo de salida 0 si todo coincide, 1 si alguna cifra difiere.
# ============================================================================
set -uo pipefail

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-}"
DB_NAME="${DB_NAME:-chocolate_diego}"

# Valores declarados en el Octavo Documento de Proyecto
ESPERADO_TABLAS=32
ESPERADO_COLUMNAS=274
ESPERADO_FK=56
ESPERADO_CHECK=28
ESPERADO_FUNCIONES=5
ESPERADO_DISPARADORES=3
ESPERADO_PROCEDIMIENTOS=5
ESPERADO_VISTAS=10

# Tablas de infraestructura creadas por Laravel. No pertenecen al modelo de
# negocio y se excluyen del conteo para que coincida con el documento.
EXCLUIDAS="'migrations','personal_access_tokens','failed_jobs','password_reset_tokens','jobs','job_batches','cache','cache_locks','sessions'"

consulta() {
  mysql --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" \
        ${DB_PASS:+--password="$DB_PASS"} \
        --batch --skip-column-names --silent -e "$1" 2>/dev/null
}

if ! consulta "SELECT 1" >/dev/null; then
  echo "ERROR: no se pudo conectar a MySQL en ${DB_HOST}:${DB_PORT}"
  exit 1
fi

echo "============================================================"
echo " VERIFICACION DE ESQUEMA — Artesanal Chocolate Diego"
echo " Base de datos : ${DB_NAME}"
echo " Servidor      : $(consulta "SELECT VERSION()")"
echo " Fecha         : $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo

OBT_TABLAS=$(consulta "SELECT COUNT(*) FROM information_schema.tables
  WHERE table_schema='${DB_NAME}' AND table_type='BASE TABLE'
    AND table_name NOT IN (${EXCLUIDAS});")

OBT_COLUMNAS=$(consulta "SELECT COUNT(*) FROM information_schema.columns c
  JOIN information_schema.tables t
    ON t.table_schema=c.table_schema AND t.table_name=c.table_name
  WHERE c.table_schema='${DB_NAME}' AND t.table_type='BASE TABLE'
    AND c.table_name NOT IN (${EXCLUIDAS});")

OBT_FK=$(consulta "SELECT COUNT(*) FROM information_schema.table_constraints
  WHERE constraint_schema='${DB_NAME}' AND constraint_type='FOREIGN KEY'
    AND table_name NOT IN (${EXCLUIDAS});")

OBT_CHECK=$(consulta "SELECT COUNT(*) FROM information_schema.table_constraints
  WHERE constraint_schema='${DB_NAME}' AND constraint_type='CHECK'
    AND table_name NOT IN (${EXCLUIDAS});")

OBT_FUNCIONES=$(consulta "SELECT COUNT(*) FROM information_schema.routines
  WHERE routine_schema='${DB_NAME}' AND routine_type='FUNCTION';")

OBT_PROCEDIMIENTOS=$(consulta "SELECT COUNT(*) FROM information_schema.routines
  WHERE routine_schema='${DB_NAME}' AND routine_type='PROCEDURE';")

OBT_DISPARADORES=$(consulta "SELECT COUNT(*) FROM information_schema.triggers
  WHERE trigger_schema='${DB_NAME}';")

OBT_VISTAS=$(consulta "SELECT COUNT(*) FROM information_schema.views
  WHERE table_schema='${DB_NAME}';")

FALLAS=0
printf "%-28s %10s %10s %10s\n" "OBJETO" "DOCUMENTO" "MYSQL" "RESULTADO"
printf "%s\n" "------------------------------------------------------------"

comparar() {
  local etiqueta="$1" esperado="$2" obtenido="$3"
  local marca="OK"
  if [ "$esperado" != "$obtenido" ]; then
    marca="DIFIERE"
    FALLAS=$((FALLAS + 1))
  fi
  printf "%-28s %10s %10s %10s\n" "$etiqueta" "$esperado" "$obtenido" "$marca"
}

comparar "Tablas"                  "$ESPERADO_TABLAS"          "$OBT_TABLAS"
comparar "Columnas"                "$ESPERADO_COLUMNAS"        "$OBT_COLUMNAS"
comparar "Llaves foraneas"         "$ESPERADO_FK"              "$OBT_FK"
comparar "Restricciones CHECK"     "$ESPERADO_CHECK"           "$OBT_CHECK"
comparar "Funciones"               "$ESPERADO_FUNCIONES"       "$OBT_FUNCIONES"
comparar "Disparadores"            "$ESPERADO_DISPARADORES"    "$OBT_DISPARADORES"
comparar "Procedimientos"          "$ESPERADO_PROCEDIMIENTOS"  "$OBT_PROCEDIMIENTOS"
comparar "Vistas"                  "$ESPERADO_VISTAS"          "$OBT_VISTAS"

echo
echo "------------------------------------------------------------"
echo " OBJETOS POR NOMBRE"
echo "------------------------------------------------------------"

verificar_nombres() {
  local titulo="$1" consulta_sql="$2" esperados="$3"
  local encontrados
  encontrados=$(consulta "$consulta_sql" | tr '\n' ' ')
  echo
  echo "${titulo}:"
  for nombre in $esperados; do
    if echo " $encontrados " | grep -q " $nombre "; then
      printf "  [OK]      %s\n" "$nombre"
    else
      printf "  [FALTA]   %s\n" "$nombre"
      FALLAS=$((FALLAS + 1))
    fi
  done
}

verificar_nombres "Funciones" \
  "SELECT routine_name FROM information_schema.routines WHERE routine_schema='${DB_NAME}' AND routine_type='FUNCTION' ORDER BY routine_name;" \
  "fn_bajo_stock_minimo fn_calcular_total_venta fn_rol_usuario fn_stock_disponible fn_valor_inventario"

verificar_nombres "Disparadores" \
  "SELECT trigger_name FROM information_schema.triggers WHERE trigger_schema='${DB_NAME}' ORDER BY trigger_name;" \
  "trg_producto_historial_precio trg_venta_bitacora_anulacion trg_venta_bitacora_insert"

verificar_nombres "Procedimientos almacenados" \
  "SELECT routine_name FROM information_schema.routines WHERE routine_schema='${DB_NAME}' AND routine_type='PROCEDURE' ORDER BY routine_name;" \
  "sp_ajustar_inventario sp_anular_venta sp_registrar_cliente sp_registrar_producto sp_registrar_venta"

verificar_nombres "Vistas" \
  "SELECT table_name FROM information_schema.views WHERE table_schema='${DB_NAME}' ORDER BY table_name;" \
  "vw_clientes_compras vw_envios_pendientes vw_estado_fel vw_existencias_actuales vw_lotes_proximos_vencer vw_pedidos_pendientes vw_resumen_ventas_diarias vw_stock_bajo vw_suscripciones_activas vw_ventas_detalladas"

echo
echo "------------------------------------------------------------"
echo " CUADRE DEL KARDEX"
echo "------------------------------------------------------------"
DESCUADRES=$(consulta "
  SELECT COUNT(*) FROM (
    SELECT e.id_existencia
      FROM existencia e
      LEFT JOIN (
        SELECT mi.id_producto, mi.id_bodega, COALESCE(mi.id_lote,0) AS lote_clave,
               SUM(CASE WHEN tm.efecto='suma' THEN mi.cantidad ELSE -mi.cantidad END) AS saldo
          FROM movimiento_inventario mi
          JOIN tipo_movimiento tm ON tm.id_tipo_movimiento = mi.id_tipo_movimiento
         GROUP BY mi.id_producto, mi.id_bodega, COALESCE(mi.id_lote,0)
      ) k ON k.id_producto = e.id_producto
         AND k.id_bodega   = e.id_bodega
         AND k.lote_clave  = e.lote_clave
     WHERE e.cantidad_disponible <> COALESCE(k.saldo, 0)
  ) d;")

if [ "${DESCUADRES:-0}" -eq 0 ]; then
  echo "  [OK]      La existencia cuadra con la suma de movimientos"
else
  echo "  [DIFIERE] ${DESCUADRES} registros de existencia no cuadran con el kardex"
  FALLAS=$((FALLAS + 1))
fi

echo
echo "============================================================"
if [ "$FALLAS" -eq 0 ]; then
  echo " RESULTADO: la implementacion corresponde al documento."
  exit 0
else
  echo " RESULTADO: ${FALLAS} discrepancias encontradas."
  exit 1
fi
