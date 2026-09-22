<?php

namespace App\Models\PuntoVenta;

use Illuminate\Database\Eloquent\Model;
use App\Models\Clientes\Pedido;

class MetodoPago extends Model
{
    protected $table = 'metodo_pago';
    protected $primaryKey = 'id_metodo_pago';
    public $timestamps = false;

    protected $fillable = [
        'nombre',
        'requiere_comprobante',
        'aplica_cambio',
        'estado',
    ];

    protected $casts = [
        'requiere_comprobante' => 'boolean',
        'aplica_cambio' => 'boolean',
    ];

    public function pedidos()
    {
        return $this->hasMany(Pedido::class, 'id_metodo_pago', 'id_metodo_pago');
    }

    public function ventas()
    {
        return $this->hasMany(Venta::class, 'id_metodo_pago', 'id_metodo_pago');
    }
}
