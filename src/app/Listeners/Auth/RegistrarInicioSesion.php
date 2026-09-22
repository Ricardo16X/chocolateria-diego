<?php

namespace App\Listeners\Auth;

use App\Models\Seguridad\Bitacora;
use App\Models\Seguridad\Usuario;
use Illuminate\Auth\Events\Login;

class RegistrarInicioSesion
{
    public function handle(Login $event): void
    {
        /** @var Usuario $usuario */
        $usuario = $event->user;

        $usuario->intentos_fallidos = 0;
        $usuario->ultimo_acceso = now();
        $usuario->save();

        Bitacora::create([
            'id_usuario' => $usuario->id_usuario,
            'usuario_intento' => $usuario->nombre_usuario,
            'evento' => 'inicio_sesion',
            'direccion_ip' => request()->ip(),
        ]);
    }
}
