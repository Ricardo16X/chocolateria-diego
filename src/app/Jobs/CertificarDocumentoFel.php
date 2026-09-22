<?php

namespace App\Jobs;

use App\Contracts\CertificadorFel;
use App\Models\Fel\DocumentoFel;
use App\Models\Soporte\ParametroSistema;
use App\Support\AlertaInterna;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Str;
use Throwable;

// Certifica un DTE fuera del ciclo de la peticion (ver CLAUDE.md): la venta
// ya quedo registrada antes de que este Job corra. El reintento con
// retroceso lo maneja el propio Job reencolandose con un delay creciente,
// no el --tries/--backoff del worker: asi fel.intentos_maximos
// (parametro_sistema, editable sin redesplegar) sigue siendo la unica
// fuente de verdad de cuantas veces reintentar, no un valor fijo en la
// linea de comandos del worker.
class CertificarDocumentoFel implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public readonly int $idDocumentoFel)
    {
        // No se declara "public $queue = 'fel'": esa propiedad ya la trae
        // el trait Queueable con un valor por defecto distinto, y PHP
        // rechaza la clase entera si los dos no coinciden (fatal error de
        // composicion de trait, no una advertencia).
        $this->onQueue('fel');
    }

    public function handle(CertificadorFel $certificador): void
    {
        $documento = DocumentoFel::find($this->idDocumentoFel);

        // Idempotente: si ya se certifico, se anulo o no existe, no hay
        // nada que hacer. Evita doble certificacion si el Job se reencolo
        // y tambien se disparo a mano.
        if (! $documento || $documento->estado !== 'pendiente') {
            return;
        }

        try {
            $resultado = $certificador->certificar($documento);

            $documento->update([
                'serie' => $resultado['serie'],
                'numero_dte' => $resultado['numero_dte'],
                'numero_autorizacion' => $resultado['numero_autorizacion'],
                'ruta_xml' => $resultado['ruta_xml'],
                'fecha_certificacion' => now(),
                'estado' => 'certificado',
            ]);
        } catch (Throwable $e) {
            $this->registrarFallo($documento, $e);
        }
    }

    private function registrarFallo(DocumentoFel $documento, Throwable $e): void
    {
        $documento->intentos++;
        $documento->mensaje_error = Str::limit($e->getMessage(), 250);

        $maximo = (int) (ParametroSistema::where('clave', 'fel.intentos_maximos')->value('valor') ?? 5);

        if ($documento->intentos >= $maximo) {
            $documento->estado = 'rechazado';
            $documento->save();

            // notificacion.chk_destinatario exige id_cliente o id_usuario:
            // se notifica a cada usuario activo con permiso fel.reintentar.
            AlertaInterna::paraPermiso(
                'fel',
                'reintentar',
                'dte_rechazado',
                "DTE rechazado tras {$documento->intentos} intentos",
                "El documento #{$documento->id_documento_fel} (venta {$documento->id_venta}) "
                    . "no se pudo certificar. Ultimo error: {$documento->mensaje_error}"
            );

            return;
        }

        $documento->save();

        self::dispatch($this->idDocumentoFel)
            ->delay(now()->addSeconds(30 * $documento->intentos));
    }
}
