<?php

namespace App\Contracts;

use App\Models\Fel\DocumentoFel;

// El certificador FEL-SAT real todavia no esta contratado
// (parametro_sistema.fel.certificador = "pendiente"). Cuando lo este, la
// implementacion nueva se registra contra este mismo contrato en
// AppServiceProvider::register() y CertificadorSimulado queda solo para
// pruebas locales.
interface CertificadorFel
{
    /**
     * @return array{serie:string, numero_dte:string, numero_autorizacion:string, ruta_xml:string}
     *
     * @throws \RuntimeException si el certificador rechaza o no responde.
     */
    public function certificar(DocumentoFel $documento): array;
}
