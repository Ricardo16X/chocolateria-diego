<?php

namespace App\Providers;

use App\Contracts\CertificadorFel;
use App\Fel\CertificadorSimulado;
use App\Models\Soporte\Notificacion;
use App\Observers\NotificacionObserver;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Sin certificador contratado todavia (parametro_sistema.fel.certificador
        // = "pendiente"). Cuando lo haya, esta linea cambia a la implementacion
        // real; CertificadorFel es el unico punto que el resto del sistema conoce.
        $this->app->bind(CertificadorFel::class, CertificadorSimulado::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Notificacion::observe(NotificacionObserver::class);
    }
}
