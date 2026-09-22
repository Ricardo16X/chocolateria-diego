<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Throwable;

// Ruta de salud de cada microservicio. El mismo controlador sirve a los
// cuatro, distinguidos por la variable de entorno SERVICIO: cada
// comprobacion va en su propio try para que una falla individual no tumbe
// las demas ni lance una excepcion sin controlar.
class SaludController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $servicio = env('SERVICIO', 'desconocido');
        $ok = true;

        $baseDatos = $this->verificarBaseDatos($servicio, $ok);
        $cache = $this->verificarCache($ok);

        $respuesta = [
            'servicio' => $servicio,
            'base_datos' => $baseDatos,
            'cache' => $cache,
        ];

        if ($servicio === 'catalogo') {
            $respuesta['kardex'] = $this->verificarKardex($ok);
        }

        if ($servicio === 'pagos') {
            $respuesta['cola'] = $this->verificarCola($ok);
        }

        return response()->json($respuesta, $ok ? 200 : 503);
    }

    private function verificarBaseDatos(string $servicio, bool &$ok): string
    {
        $tablas = config("chdiego.tablas_dominio.$servicio", []);

        try {
            if ($tablas === []) {
                return 'ok (sin tablas de dominio asignadas)';
            }

            $marcadores = implode(',', array_fill(0, count($tablas), '?'));

            $conteo = DB::selectOne(
                "SELECT COUNT(*) AS c FROM information_schema.tables
                  WHERE table_schema = DATABASE()
                    AND table_type = 'BASE TABLE'
                    AND table_name IN ($marcadores)",
                $tablas
            )->c;

            return "ok ({$conteo} tablas)";
        } catch (Throwable $e) {
            $ok = false;

            return $e->getMessage();
        }
    }

    private function verificarCache(bool &$ok): string
    {
        try {
            $clave = 'salud:' . uniqid('', true);
            Cache::put($clave, '1', 5);
            $valor = Cache::pull($clave);

            if ($valor !== '1') {
                $ok = false;

                return 'error: no se pudo confirmar la escritura en cache';
            }

            return 'ok';
        } catch (Throwable $e) {
            $ok = false;

            return $e->getMessage();
        }
    }

    private function verificarKardex(bool &$ok): string
    {
        try {
            $descuadres = DB::selectOne(
                "SELECT COUNT(*) AS c FROM (
                    SELECT e.id_existencia, e.cantidad_disponible,
                           COALESCE(k.saldo, 0) AS saldo
                      FROM existencia e
                      LEFT JOIN (
                        SELECT mi.id_producto, mi.id_bodega,
                               COALESCE(mi.id_lote, 0) AS lote_clave,
                               SUM(CASE WHEN tm.efecto = 'suma' THEN mi.cantidad
                                        ELSE -mi.cantidad END) AS saldo
                          FROM movimiento_inventario mi
                          JOIN tipo_movimiento tm
                            ON tm.id_tipo_movimiento = mi.id_tipo_movimiento
                         GROUP BY mi.id_producto, mi.id_bodega,
                                  COALESCE(mi.id_lote, 0)
                      ) k ON k.id_producto = e.id_producto
                         AND k.id_bodega = e.id_bodega
                         AND k.lote_clave = e.lote_clave
                     WHERE e.cantidad_disponible <> COALESCE(k.saldo, 0)
                ) d"
            )->c;

            if ($descuadres > 0) {
                $ok = false;

                return (string) $descuadres;
            }

            return 'cuadrado';
        } catch (Throwable $e) {
            $ok = false;

            return $e->getMessage();
        }
    }

    private function verificarCola(bool &$ok): string
    {
        try {
            return (string) Queue::size('fel');
        } catch (Throwable $e) {
            $ok = false;

            return $e->getMessage();
        }
    }
}
