<?php

namespace App\Jobs;

use App\Models\Soporte\Notificacion;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Throwable;

// A diferencia de CertificarDocumentoFel, aqui no hay un intentos_maximos
// propio en parametro_sistema: el reintento con retroceso lo maneja el
// --tries/--backoff del worker (docker-compose.yml), y failed() marca
// "fallida" cuando el worker agota sus intentos.
class EnviarNotificacion implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public readonly int $idNotificacion)
    {
        // Ver el comentario equivalente en CertificarDocumentoFel: no se
        // declara "public $queue" como propiedad, choca con la del trait
        // Queueable.
        $this->onQueue('correo');
    }

    public function handle(): void
    {
        $notificacion = Notificacion::find($this->idNotificacion);

        if (! $notificacion || $notificacion->estado !== 'pendiente') {
            return;
        }

        $destinatario = $notificacion->cliente?->correo ?? $notificacion->usuario?->correo;

        // Las alertas internas (dte_rechazado, existencia_baja) no siempre
        // tienen un cliente o usuario asociado: quedan registradas para
        // consultarse en el panel, sin intentar un envio sin destinatario.
        if ($destinatario) {
            Mail::raw($notificacion->cuerpo ?? $notificacion->asunto, function ($mensaje) use ($notificacion, $destinatario) {
                $mensaje->to($destinatario)->subject($notificacion->asunto);
            });
        }

        $notificacion->update(['estado' => 'enviada', 'fecha_envio' => now()]);
    }

    public function failed(Throwable $e): void
    {
        Notificacion::where('id_notificacion', $this->idNotificacion)->update([
            'estado' => 'fallida',
            'intentos' => DB::raw('intentos + 1'),
            'mensaje_error' => Str::limit($e->getMessage(), 250),
        ]);
    }
}
