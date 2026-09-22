<?php

namespace App\Fel;

use App\Contracts\CertificadorFel;
use App\Models\Fel\DocumentoFel;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

// Adaptador de demostracion mientras no hay certificador contratado (ver
// CertificadorFel). El modo se fija por variable de entorno
// (FEL_SIMULACION_MODO, config/fel.php) porque es una decision del entorno
// de despliegue -- que tan realista debe verse la demo --, no un parametro
// de negocio: no compite con parametro_sistema.
class CertificadorSimulado implements CertificadorFel
{
    public function certificar(DocumentoFel $documento): array
    {
        $modo = config('fel.modo_simulacion');

        $falla = match ($modo) {
            'fallo' => true,
            'aleatorio' => random_int(1, 100) <= 30,
            default => false,
        };

        if ($falla) {
            throw new RuntimeException('El certificador simulado (FEL_SIMULACION_MODO=' . $modo . ') rechazo la certificacion.');
        }

        $serie = 'SIM';
        $numeroDte = str_pad((string) $documento->id_documento_fel, 10, '0', STR_PAD_LEFT);
        $autorizacion = (string) \Illuminate\Support\Str::uuid();

        $rutaXml = "fel/{$numeroDte}.xml";
        Storage::disk('local')->put($rutaXml, $this->construirXml($documento, $serie, $numeroDte, $autorizacion));

        return [
            'serie' => $serie,
            'numero_dte' => $numeroDte,
            'numero_autorizacion' => $autorizacion,
            'ruta_xml' => $rutaXml,
        ];
    }

    private function construirXml(DocumentoFel $documento, string $serie, string $numeroDte, string $autorizacion): string
    {
        $xml = new \SimpleXMLElement('<GTDocumento/>');
        $xml->addAttribute('Version', '0.1-simulado');

        $datos = $xml->addChild('DatosEmision');
        $datos->addChild('Serie', $serie);
        $datos->addChild('Numero', $numeroDte);
        $datos->addChild('Autorizacion', $autorizacion);
        $datos->addChild('TipoDocumento', $documento->tipo_documento);
        $datos->addChild('NitReceptor', htmlspecialchars($documento->nit_receptor));
        $datos->addChild('NombreReceptor', htmlspecialchars($documento->nombre_receptor));
        $datos->addChild('MontoGravable', (string) $documento->monto_gravable);
        $datos->addChild('MontoImpuesto', (string) $documento->monto_impuesto);
        $datos->addChild('MontoTotal', (string) $documento->monto_total);

        return $xml->asXML();
    }
}
