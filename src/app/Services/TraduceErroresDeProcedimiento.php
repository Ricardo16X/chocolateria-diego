<?php

namespace App\Services;

use App\Exceptions\ExcepcionNegocio;
use Illuminate\Database\QueryException;
use Illuminate\Support\Str;

// Comparten esto VentaService e InventarioService: ambos invocan
// procedimientos almacenados que solo pueden fallar con SIGNAL SQLSTATE
// '45000' (ver 02_rutinas.sql) o con un error real de infraestructura
// (conexion caida, etc.), que no es un ExcepcionNegocio y debe seguir
// propagandose tal cual.
trait TraduceErroresDeProcedimiento
{
    private function traducir(QueryException $e): ExcepcionNegocio|QueryException
    {
        if ($e->getCode() !== '45000') {
            return $e;
        }

        $mensaje = $e->errorInfo[2] ?? $e->getMessage();

        if (! Str::contains($mensaje, ':')) {
            return new ExcepcionNegocio('ERROR_DESCONOCIDO', $mensaje);
        }

        [$codigo, $texto] = explode(':', $mensaje, 2);

        return new ExcepcionNegocio(trim($codigo), trim($texto));
    }
}
