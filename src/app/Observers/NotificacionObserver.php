<?php

namespace App\Observers;

use App\Jobs\EnviarNotificacion;
use App\Models\Soporte\Notificacion;

// Cualquier Notificacion::create(...), venga de un controlador, un Job o
// una tarea programada, termina encolando su propio envio. Asi ningun
// punto del sistema que genera una notificacion tiene que acordarse de
// despacharla a mano.
class NotificacionObserver
{
    public function created(Notificacion $notificacion): void
    {
        EnviarNotificacion::dispatch($notificacion->id_notificacion);
    }
}
