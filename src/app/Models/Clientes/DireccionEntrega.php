<?php

namespace App\Models\Clientes;

use Illuminate\Database\Eloquent\Model;
use App\Models\Entregas\ZonaCobertura;
use App\Models\Suscripcion\Suscripcion;

class DireccionEntrega extends Model
{
    protected $table = 'direccion_entrega';
    protected $primaryKey = 'id_direccion';
    public $timestamps = false;

    protected $fillable = [
        'id_cliente',
        'id_zona',
        'direccion',
        'referencia',
        'nombre_contacto',
        'telefono_contacto',
        'predeterminada',
        'estado',
    ];

    protected $casts = [
        'predeterminada' => 'boolean',
    ];

    public function cliente()
    {
        return $this->belongsTo(Cliente::class, 'id_cliente', 'id_cliente');
    }

    public function zona()
    {
        return $this->belongsTo(ZonaCobertura::class, 'id_zona', 'id_zona');
    }

    public function pedidos()
    {
        return $this->hasMany(Pedido::class, 'id_direccion', 'id_direccion');
    }

    public function suscripciones()
    {
        return $this->hasMany(Suscripcion::class, 'id_direccion', 'id_direccion');
    }
}
