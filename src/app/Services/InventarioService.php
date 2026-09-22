<?php

namespace App\Services;

use App\Exceptions\ExcepcionNegocio;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

// Capa fina sobre sp_ajustar_inventario, para entradas, mermas y ajustes
// (todo lo que no sea una venta o su anulacion, que ya tienen VentaService).
class InventarioService
{
    use TraduceErroresDeProcedimiento;

    /**
     * @param  array{id_producto:int, id_bodega:int, id_lote:?int, id_tipo_movimiento:int,
     *     cantidad:float, id_usuario:int, id_usuario_autoriza?:int, motivo?:string} $datos
     *
     * @throws ExcepcionNegocio
     */
    public function ajustar(array $datos): void
    {
        try {
            DB::statement(
                'CALL sp_ajustar_inventario(?, ?, ?, ?, ?, ?, ?, ?)',
                [
                    $datos['id_producto'],
                    $datos['id_bodega'],
                    $datos['id_lote'] ?? null,
                    $datos['id_tipo_movimiento'],
                    $datos['cantidad'],
                    $datos['id_usuario'],
                    $datos['id_usuario_autoriza'] ?? null,
                    $datos['motivo'] ?? null,
                ]
            );
        } catch (QueryException $e) {
            throw $this->traducir($e);
        }
    }
}
