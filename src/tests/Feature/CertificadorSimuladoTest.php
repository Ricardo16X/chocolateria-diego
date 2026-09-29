<?php

namespace Tests\Feature;

use App\Fel\CertificadorSimulado;
use App\Models\Fel\DocumentoFel;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Tests\TestCase;

// Casos U14 a U17 del plan de pruebas.
//
// Mientras no haya certificador FEL-SAT contratado, CertificadorSimulado
// ocupa su lugar detras del contrato CertificadorFel. Lo que importa probar
// no es el XML en si, sino que el adaptador respete el contrato: devuelva
// las cuatro claves que el Job espera, y falle con una excepcion cuando se
// configura para fallar, para que la cola pueda reintentar.
//
// Vive en Feature y no en Unit porque necesita el contenedor de servicios
// de Laravel para config() y para el disco de almacenamiento. No toca la
// base de datos: el DocumentoFel se construye en memoria y Storage se
// reemplaza por uno falso.
class CertificadorSimuladoTest extends TestCase
{
    private function documento(): DocumentoFel
    {
        $documento = new DocumentoFel;
        $documento->id_documento_fel = 42;
        $documento->tipo_documento = 'factura';
        $documento->nit_receptor = 'CF';
        $documento->nombre_receptor = 'Consumidor Final';
        $documento->monto_gravable = '66.96';
        $documento->monto_impuesto = '8.04';
        $documento->monto_total = '75.00';

        return $documento;
    }

    /** U14 */
    public function test_U14_devuelve_las_cuatro_claves_que_el_contrato_declara(): void
    {
        Storage::fake('local');
        config(['fel.modo_simulacion' => 'exito']);

        $resultado = (new CertificadorSimulado)->certificar($this->documento());

        $this->assertSame(
            ['serie', 'numero_dte', 'numero_autorizacion', 'ruta_xml'],
            array_keys($resultado)
        );
        $this->assertSame('SIM', $resultado['serie']);
    }

    /** U15 */
    public function test_U15_rellena_el_numero_de_dte_a_diez_digitos(): void
    {
        Storage::fake('local');
        config(['fel.modo_simulacion' => 'exito']);

        $resultado = (new CertificadorSimulado)->certificar($this->documento());

        $this->assertSame('0000000042', $resultado['numero_dte']);
        $this->assertSame(10, strlen($resultado['numero_dte']));
    }

    /** U16 */
    public function test_U16_deja_el_xml_escrito_y_bien_formado_en_la_ruta_que_reporta(): void
    {
        Storage::fake('local');
        config(['fel.modo_simulacion' => 'exito']);

        $resultado = (new CertificadorSimulado)->certificar($this->documento());

        Storage::disk('local')->assertExists($resultado['ruta_xml']);

        $xml = simplexml_load_string(Storage::disk('local')->get($resultado['ruta_xml']));

        $this->assertNotFalse($xml, 'El XML generado no es bien formado.');
        $this->assertSame('SIM', (string) $xml->DatosEmision->Serie);
        $this->assertSame('0000000042', (string) $xml->DatosEmision->Numero);
        $this->assertSame('CF', (string) $xml->DatosEmision->NitReceptor);
        $this->assertSame('75.00', (string) $xml->DatosEmision->MontoTotal);
    }

    /** U17 */
    public function test_U17_lanza_excepcion_cuando_se_configura_para_fallar(): void
    {
        // Es el camino que la cola necesita para reintentar: si el
        // certificador no lanza, CertificarDocumentoFel daria la
        // certificacion por buena.
        Storage::fake('local');
        config(['fel.modo_simulacion' => 'fallo']);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('FEL_SIMULACION_MODO=fallo');

        (new CertificadorSimulado)->certificar($this->documento());
    }
}
