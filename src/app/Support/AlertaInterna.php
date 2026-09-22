<?php

namespace App\Support;

use App\Models\Seguridad\Usuario;
use App\Models\Soporte\Notificacion;

// notificacion.chk_destinatario exige id_cliente o id_usuario: no existe la
// "alerta al sistema" sin destinatario. Para las alertas internas (stock
// bajo, vencimientos, DTE rechazado) el destinatario es cada usuario activo
// cuyo rol tenga el permiso indicado -- reutiliza Rol::permisos() de la
// Fase 3/4 en vez de una lista de correos aparte.
class AlertaInterna
{
    /**
     * Crea una notificacion por cada usuario activo con el permiso dado.
     * Devuelve cuantas se crearon.
     */
    public static function paraPermiso(string $modulo, string $accion, string $tipo, string $asunto, string $cuerpo): int
    {
        $usuarios = Usuario::where('estado', 'activo')
            ->whereHas('rol.permisos', function ($consulta) use ($modulo, $accion) {
                $consulta->where('permiso.modulo', $modulo)->where('permiso.accion', $accion);
            })
            ->get();

        foreach ($usuarios as $usuario) {
            Notificacion::create([
                'id_usuario' => $usuario->id_usuario,
                'tipo' => $tipo,
                'asunto' => $asunto,
                'cuerpo' => $cuerpo,
            ]);
        }

        return $usuarios->count();
    }
}
