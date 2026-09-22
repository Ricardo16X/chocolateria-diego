<?php

namespace App\Console\Commands;

use App\Models\Soporte\Notificacion;
use App\Models\Suscripcion\Suscripcion;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

// Recorre vw_suscripciones_activas y genera un recordatorio para las que
// entregan en los proximos 3 dias. No hay un parametro_sistema para esta
// ventana todavia (a diferencia de fel.tasa_iva o seguridad.intentos_maximos);
// si el negocio pide ajustarla sin redesplegar, se agrega como
// "suscripcion.dias_aviso_entrega" siguiendo el mismo patron.
class RecordarSuscripciones extends Command
{
    private const DIAS_AVISO = 3;

    protected $signature = 'chdiego:recordar-suscripciones';

    protected $description = 'Genera recordatorios para suscripciones con entrega proxima (vw_suscripciones_activas)';

    public function handle(): int
    {
        $suscripciones = DB::select(
            'SELECT * FROM vw_suscripciones_activas WHERE dias_para_entrega BETWEEN 0 AND ?',
            [self::DIAS_AVISO]
        );
        $creadas = 0;

        foreach ($suscripciones as $suscripcion) {
            $marcador = "[suscripcion:{$suscripcion->id_suscripcion}]";

            $yaAvisado = Notificacion::where('tipo', 'recordatorio_suscripcion')
                ->where('asunto', 'like', "%{$marcador}")
                ->whereDate('fecha_creacion', now()->toDateString())
                ->exists();

            if ($yaAvisado) {
                continue;
            }

            // La vista no expone id_cliente (solo el nombre concatenado);
            // se recupera aqui para que EnviarNotificacion pueda resolver
            // el correo por la relacion Notificacion::cliente().
            $idCliente = Suscripcion::where('id_suscripcion', $suscripcion->id_suscripcion)->value('id_cliente');

            Notificacion::create([
                'id_cliente' => $idCliente,
                'tipo' => 'recordatorio_suscripcion',
                'asunto' => "Entrega en {$suscripcion->dias_para_entrega} dias: {$suscripcion->plan} {$marcador}",
                'cuerpo' => "La suscripcion de {$suscripcion->cliente} al plan {$suscripcion->plan} entrega el "
                    . "{$suscripcion->fecha_proxima_entrega} en {$suscripcion->municipio}, {$suscripcion->departamento}.",
            ]);

            $creadas++;
        }

        $this->info("{$creadas} recordatorio(s) generado(s), de " . count($suscripciones) . ' suscripcion(es) con entrega proxima.');

        return self::SUCCESS;
    }
}
