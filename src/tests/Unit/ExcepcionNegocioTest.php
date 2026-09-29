<?php

namespace Tests\Unit;

use App\Exceptions\ExcepcionNegocio;
use PHPUnit\Framework\TestCase;
use RuntimeException;

// Casos U06 a U08 del plan de pruebas.
//
// ExcepcionNegocio es el punto donde un error de la base de datos se
// convierte en algo sobre lo que un controlador puede decidir. Las dos
// propiedades que importan: el codigo es comparable, y sigue siendo una
// excepcion normal de PHP para que el manejador global la capture.
class ExcepcionNegocioTest extends TestCase
{
    /** U06 */
    public function test_U06_expone_el_codigo_y_el_mensaje_por_separado(): void
    {
        $e = new ExcepcionNegocio('VENTA_TURNO_CERRADO', 'El turno de caja esta cerrado.');

        $this->assertSame('VENTA_TURNO_CERRADO', $e->codigo);
        $this->assertSame('El turno de caja esta cerrado.', $e->getMessage());
    }

    /** U07 */
    public function test_U07_compara_el_codigo_sin_depender_del_texto_del_mensaje(): void
    {
        // Esta es la razon de existir de la clase: el controlador decide por
        // codigo, de modo que reformular el mensaje para el usuario no rompe
        // ninguna decision de logica.
        $e = new ExcepcionNegocio('VENTA_SIN_ITEMS', 'Cualquier texto, incluso reformulado.');

        $this->assertTrue($e->esCodigo('VENTA_SIN_ITEMS'));
        $this->assertFalse($e->esCodigo('VENTA_YA_ANULADA'));
        $this->assertFalse($e->esCodigo('venta_sin_items'), 'La comparacion distingue mayusculas.');
    }

    /** U08 */
    public function test_U08_sigue_siendo_una_excepcion_de_php_capturable(): void
    {
        $this->expectException(RuntimeException::class);

        throw new ExcepcionNegocio('INVENTARIO_LOTE_VENCIDO', 'El lote esta vencido.');
    }
}
