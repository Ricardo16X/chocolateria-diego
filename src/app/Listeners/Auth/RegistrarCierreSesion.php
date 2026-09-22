<?php

namespace App\Listeners\Auth;

use App\Models\Seguridad\Bitacora;
use App\Models\Seguridad\Usuario;
use Illuminate\Auth\Events\Logout;

class RegistrarCierreSesion
{
    public function handle(Logout $event): void
    {
        /** @var Usuario|null $usuario */
        $usuario = $event->user;

        if ($usuario === null) {
            return;
        }

        Bitacora::create([
            'id_usuario' => $usuario->id_usuario,
            'usuario_intento' => $usuario->nombre_usuario,
            'evento' => 'cierre_sesion',
            'direccion_ip' => request()->ip(),
        ]);
    }
}
