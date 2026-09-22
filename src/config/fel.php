<?php

return [

    // exito (default) | fallo | aleatorio. Solo afecta a CertificadorSimulado
    // -- ver App\Contracts\CertificadorFel. Se usa "fallo" o "aleatorio" para
    // demostrar el flujo de reintentos y rechazo de la Fase 6 sin depender
    // de un certificador real.
    'modo_simulacion' => env('FEL_SIMULACION_MODO', 'exito'),

];
