<?php

namespace App\Console\Commands;

use App\Models\Inventario\ReservaExistencia;
use Illuminate\Console\Command;

// reserva_existencia no descuenta cantidad_disponible (ningun procedimiento
// la toca): es un libro de reservas aparte, para cuando la tienda en linea
// aparte stock durante el checkout. Expirar solo cambia su estado; no hay
// movimiento de inventario que revertir.
class ExpirarReservas extends Command
{
    protected $signature = 'chdiego:expirar-reservas';

    protected $description = 'Marca como expiradas las reservas de existencia vencidas';

    public function handle(): int
    {
        $expiradas = ReservaExistencia::where('estado', 'activa')
            ->where('fecha_expiracion', '<', now())
            ->update([
                'estado' => 'expirada',
                'fecha_liberacion' => now(),
            ]);

        $this->info("{$expiradas} reserva(s) expirada(s).");

        return self::SUCCESS;
    }
}
