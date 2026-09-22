<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * Define the application's command schedule.
     */
    protected function schedule(Schedule $schedule): void
    {
        $schedule->command('chdiego:alertar-vencimientos')->daily();
        $schedule->command('chdiego:alertar-stock-bajo')->daily();
        $schedule->command('chdiego:expirar-reservas')->everyFifteenMinutes();
        $schedule->command('chdiego:recordar-suscripciones')->daily();
    }

    /**
     * Register the commands for the application.
     */
    protected function commands(): void
    {
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');
    }
}
