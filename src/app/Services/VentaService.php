<?php

namespace App\Services;

use App\Exceptions\ExcepcionNegocio;
use App\Jobs\CertificarDocumentoFel;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

// Capa fina sobre sp_registrar_venta y sp_anular_venta. No valida existencia
// ni descuenta inventario aqui: eso vive en el procedimiento, dentro de su
// propia transaccion (ver CLAUDE.md). Por eso este servicio NO envuelve las
// llamadas en DB::transaction(): un START TRANSACTION dentro del
// procedimiento, si ya hubiera una transaccion abierta desde PHP, la
// confirmaria de forma implicita antes de empezar la suya.
class VentaService
{
    use TraduceErroresDeProcedimiento;

    /**
     * @param  array{id_usuario:int, id_cliente:?int, id_turno:int, id_metodo_pago:int,
     *     canal?:string, descuento?:float, id_usuario_autoriza_descuento?:int,
     *     justificacion_descuento?:string, nit_receptor?:string, nombre_receptor?:string,
     *     items: array<int, array{id_producto:int, cantidad:float}>} $datos
     * @return array{id_venta:int, id_documento_fel:int}
     *
     * @throws ExcepcionNegocio
     */
    public function registrarVenta(array $datos): array
    {
        try {
            DB::statement(
                'CALL sp_registrar_venta(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, @id_venta, @id_documento_fel)',
                [
                    $datos['id_usuario'],
                    $datos['id_cliente'] ?? null,
                    $datos['id_turno'],
                    $datos['id_metodo_pago'],
                    $datos['canal'] ?? 'presencial',
                    $datos['descuento'] ?? null,
                    $datos['id_usuario_autoriza_descuento'] ?? null,
                    $datos['justificacion_descuento'] ?? null,
                    $datos['nit_receptor'] ?? null,
                    $datos['nombre_receptor'] ?? null,
                    json_encode(array_values($datos['items'])),
                ]
            );
        } catch (QueryException $e) {
            throw $this->traducir($e);
        }

        $salida = DB::selectOne('SELECT @id_venta AS id_venta, @id_documento_fel AS id_documento_fel');
        $idDocumentoFel = (int) $salida->id_documento_fel;

        // La venta ya quedo registrada (la transaccion del procedimiento ya
        // hizo commit): la certificacion corre aparte, en la cola "fel", y
        // nunca dentro del ciclo de esta peticion (ver CLAUDE.md).
        CertificarDocumentoFel::dispatch($idDocumentoFel);

        return [
            'id_venta' => (int) $salida->id_venta,
            'id_documento_fel' => $idDocumentoFel,
        ];
    }

    /**
     * @throws ExcepcionNegocio
     */
    public function anularVenta(int $idVenta, int $idUsuarioSolicitante, string $motivo): void
    {
        try {
            DB::statement('CALL sp_anular_venta(?, ?, ?)', [$idVenta, $idUsuarioSolicitante, $motivo]);
        } catch (QueryException $e) {
            throw $this->traducir($e);
        }
    }
}
