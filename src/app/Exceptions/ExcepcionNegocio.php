<?php

namespace App\Exceptions;

use RuntimeException;

// Traduce un SIGNAL SQLSTATE '45000' de docker/mysql/init/02_rutinas.sql a
// una excepcion de PHP. $codigo es el contrato estable (VENTA_SIN_ITEMS,
// INVENTARIO_EXISTENCIA_NEGATIVA, ...) para decidir logica en el
// controlador; getMessage() trae el texto en espanol, listo para mostrar
// al usuario. Ver CLAUDE.md: el codigo antecede a los dos puntos, el texto
// puede reformularse sin avisar.
class ExcepcionNegocio extends RuntimeException
{
    public function __construct(public readonly string $codigo, string $mensaje)
    {
        parent::__construct($mensaje);
    }

    public function esCodigo(string $codigo): bool
    {
        return $this->codigo === $codigo;
    }
}
