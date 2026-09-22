<?php

namespace App\Models\Fel;

use Illuminate\Database\Eloquent\Model;
use App\Models\PuntoVenta\Venta;

class DocumentoFel extends Model
{
    protected $table = 'documento_fel';
    protected $primaryKey = 'id_documento_fel';
    public $timestamps = false;

    protected $fillable = [
        'id_venta',
        'tipo_documento',
        'nit_receptor',
        'nombre_receptor',
        'serie',
        'numero_dte',
        'numero_autorizacion',
        'fecha_certificacion',
        'monto_gravable',
        'monto_impuesto',
        'monto_total',
        'estado',
        'intentos',
        'mensaje_error',
        'ruta_xml',
        'fecha_anulacion_sat',
        'autorizacion_anulacion',
    ];

    protected $casts = [
        'fecha_certificacion' => 'datetime',
        'monto_gravable' => 'decimal:2',
        'monto_impuesto' => 'decimal:2',
        'monto_total' => 'decimal:2',
        'fecha_anulacion_sat' => 'datetime',
        'fecha_registro' => 'datetime',
    ];

    public function venta()
    {
        return $this->belongsTo(Venta::class, 'id_venta', 'id_venta');
    }
}
