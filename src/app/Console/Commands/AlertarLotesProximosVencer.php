<?php

namespace App\Console\Commands;

use App\Models\Soporte\Notificacion;
use App\Support\AlertaInterna;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

// Recorre vw_lotes_proximos_vencer (docker/mysql/init/02_rutinas.sql) y
// genera una notificacion "proximo_vencimiento" por lote, una vez por dia:
// si ya existe una notificacion de este lote creada hoy, no duplica.
class AlertarLotesProximosVencer extends Command
{
    protected $signature = 'chdiego:alertar-vencimientos';

    protected $description = 'Genera notificaciones para los lotes proximos a vencer (vw_lotes_proximos_vencer)';

    public function handle(): int
    {
        $lotes = DB::select('SELECT * FROM vw_lotes_proximos_vencer');
        $creadas = 0;

        foreach ($lotes as $lote) {
            $marcador = "[lote:{$lote->id_lote}]";

            $yaAvisado = Notificacion::where('tipo', 'proximo_vencimiento')
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
                'proximo_vencimiento',
                "Lote {$lote->codigo_lote} vence en {$lote->dias_para_vencer} dias {$marcador}",
                "El lote {$lote->codigo_lote} de {$lote->producto} ({$lote->codigo_producto}) "
                    . "vence el {$lote->fecha_vencimiento}, con {$lote->existencia_lote} unidades en existencia."
            );

            $creadas++;
        }

        $this->info("{$creadas} notificacion(es) de vencimiento generada(s), de " . count($lotes) . ' lote(s) proximos a vencer.');

        return self::SUCCESS;
    }
}
