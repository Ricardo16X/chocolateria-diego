<?php

namespace App\Listeners\Auth;

use App\Models\Seguridad\Bitacora;
use App\Models\Seguridad\Usuario;
use App\Models\Soporte\ParametroSistema;
use Illuminate\Auth\Events\Failed;

class RegistrarIntentoFallido
{
    public function handle(Failed $event): void
    {
        /** @var Usuario|null $usuario */
        $usuario = $event->user;

        // El evento Failed se dispara aunque el usuario no exista (nombre de
        // usuario inventado): en ese caso no hay a quien bloquear, pero la
        // bitacora igual debe quedar con lo que se intento, en usuario_intento.
        if ($usuario === null) {
            Bitacora::create([
                'usuario_intento' => $event->credentials['nombre_usuario']
                    ?? $event->credentials['correo']
                    ?? null,
                'evento' => 'intento_fallido',
                'direccion_ip' => request()->ip(),
            ]);

            return;
        }

        // Una cuenta ya bloqueada no debe seguir incrementando el contador:
        // el bloqueo ya esta en efecto, solo queda dejar constancia.
        if ($usuario->estado !== 'bloqueado') {
            $usuario->intentos_fallidos++;

            $maximo = (int) (ParametroSistema::where('clave', 'seguridad.intentos_maximos')->value('valor') ?? 5);

            if ($usuario->intentos_fallidos >= $maximo) {
                $usuario->estado = 'bloqueado';
            }

            $usuario->save();
        }

        Bitacora::create([
            'id_usuario' => $usuario->id_usuario,
            'usuario_intento' => $usuario->nombre_usuario,
            'evento' => 'intento_fallido',
            'direccion_ip' => request()->ip(),
        ]);
    }
}
