<?php

namespace App\Console\Commands;

use App\Models\Soporte\Notificacion;
use App\Support\AlertaInterna;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

// Recorre vw_stock_bajo y genera una notificacion "existencia_baja" por
// producto, una vez por dia.
class AlertarStockBajo extends Command
{
    protected $signature = 'chdiego:alertar-stock-bajo';

    protected $description = 'Genera notificaciones para los productos con existencia bajo el minimo (vw_stock_bajo)';

    public function handle(): int
    {
        $productos = DB::select('SELECT * FROM vw_stock_bajo');
        $creadas = 0;

        foreach ($productos as $producto) {
            $marcador = "[producto:{$producto->id_producto}]";

            $yaAvisado = Notificacion::where('tipo', 'existencia_baja')
                ->where('asunto', 'like', "%{$marcador}")
                ->whereDate('fecha_creacion', now()->toDateString())
                ->exists();

            if ($yaAvisado) {
                continue;
            }

            // notificacion.chk_destinatario exige id_cliente o id_usuario:
            // se notifica a cada usuario activo con permiso inventario.ajustar.
            AlertaInterna::paraPermiso(
                'inventario',
                'ajustar',
                'existencia_baja',
                "Existencia baja: {$producto->producto} {$marcador}",
                "{$producto->producto} ({$producto->codigo_producto}) tiene {$producto->existencia_total} "
                    . "unidades, por debajo del minimo de {$producto->stock_minimo}. "
                    . "Faltan {$producto->faltante_para_minimo} para el minimo."
            );

            $creadas++;
        }

        $this->info("{$creadas} notificacion(es) de stock bajo generada(s), de " . count($productos) . ' producto(s) bajo el minimo.');

        return self::SUCCESS;
    }
}
