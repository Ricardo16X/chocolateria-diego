<?php

namespace Tests\Unit;

use App\Exceptions\ExcepcionNegocio;
use App\Services\TraduceErroresDeProcedimiento;
use Illuminate\Database\QueryException;
use PHPUnit\Framework\TestCase;

// Casos U01 a U05 del plan de pruebas.
//
// El contrato que se verifica aqui es el de CLAUDE.md: los 25
// SIGNAL SQLSTATE '45000' de docker/mysql/init/02_rutinas.sql llevan un
// codigo en mayusculas antes de los dos puntos, y ese codigo es estable.
// El texto que sigue es para mostrar al usuario y puede reformularse sin
// romper nada. Si alguien invierte ese orden, o pierde el recorte de
// espacios, estas pruebas fallan.
//
// No tocan la base de datos: construyen la QueryException a mano.
class TraduceErroresDeProcedimientoTest extends TestCase
{
    private function traductor(): object
    {
        // El metodo traducir() es privado en el trait. La clase que lo
        // compone si puede alcanzarlo, y es asi como lo usan VentaService e
        // InventarioService. Este doble expone lo mismo que ellos consumen.
        return new class
        {
            use TraduceErroresDeProcedimiento;

            public function traducirPublico(QueryException $e): ExcepcionNegocio|QueryException
            {
                return $this->traducir($e);
            }
        };
    }

    private function excepcion(string $sqlstate, string $mensaje): QueryException
    {
        // QueryException toma su codigo de $previous->getCode(), no de
        // errorInfo (ver Illuminate\Database\QueryException::__construct).
        // El constructor de PDOException recibe el codigo como entero, asi
        // que el SQLSTATE en texto solo se puede fijar desde una subclase.
        $previa = new class($mensaje, $sqlstate) extends \PDOException
        {
            public function __construct(string $mensaje, string $sqlstate)
            {
                parent::__construct($mensaje);
                $this->code = $sqlstate;
                $this->errorInfo = [$sqlstate, 1644, $mensaje];
            }
        };

        return new QueryException('mysql', 'CALL sp_registrar_venta(?)', [], $previa);
    }

    /** U01 */
    public function test_U01_traduce_un_signal_45000_a_excepcion_de_negocio_separando_codigo_y_texto(): void
    {
        $e = $this->excepcion('45000', 'VENTA_SIN_ITEMS: La venta no tiene lineas de detalle.');

        $resultado = $this->traductor()->traducirPublico($e);

        $this->assertInstanceOf(ExcepcionNegocio::class, $resultado);
        $this->assertSame('VENTA_SIN_ITEMS', $resultado->codigo);
        $this->assertSame('La venta no tiene lineas de detalle.', $resultado->getMessage());
    }

    /** U02 */
    public function test_U02_deja_pasar_sin_traducir_un_error_que_no_es_signal_45000(): void
    {
        // Una conexion caida o una tabla inexistente no son errores de
        // negocio: deben seguir propagandose tal cual para que el manejador
        // de excepciones los trate como fallo de infraestructura.
        $e = $this->excepcion('42S02', "Table 'chocolate_diego.inexistente' doesn't exist");

        $resultado = $this->traductor()->traducirPublico($e);

        $this->assertInstanceOf(QueryException::class, $resultado);
        $this->assertSame($e, $resultado);
    }

    /** U03 */
    public function test_U03_usa_codigo_desconocido_cuando_el_mensaje_no_trae_los_dos_puntos(): void
    {
        $e = $this->excepcion('45000', 'Un mensaje sin codigo delante');

        $resultado = $this->traductor()->traducirPublico($e);

        $this->assertInstanceOf(ExcepcionNegocio::class, $resultado);
        $this->assertSame('ERROR_DESCONOCIDO', $resultado->codigo);
        $this->assertSame('Un mensaje sin codigo delante', $resultado->getMessage());
    }

    /** U04 */
    public function test_U04_recorta_los_espacios_alrededor_del_codigo_y_del_texto(): void
    {
        $e = $this->excepcion('45000', '  INVENTARIO_EXISTENCIA_NEGATIVA  :   No hay existencia suficiente.  ');

        $resultado = $this->traductor()->traducirPublico($e);

        $this->assertSame('INVENTARIO_EXISTENCIA_NEGATIVA', $resultado->codigo);
        $this->assertSame('No hay existencia suficiente.', $resultado->getMessage());
    }

    /** U05 */
    public function test_U05_conserva_los_dos_puntos_que_aparecen_dentro_del_texto(): void
    {
        // El corte es en el PRIMER separador, no en todos: un texto de
        // usuario puede contener dos puntos legitimamente.
        $e = $this->excepcion('45000', 'VENTA_YA_ANULADA: La venta ya fue anulada el 2026-09-28 a las 10:30:00.');

        $resultado = $this->traductor()->traducirPublico($e);

        $this->assertSame('VENTA_YA_ANULADA', $resultado->codigo);
        $this->assertSame('La venta ya fue anulada el 2026-09-28 a las 10:30:00.', $resultado->getMessage());
    }
}
