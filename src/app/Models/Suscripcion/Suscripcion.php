<?php

namespace App\Models\Suscripcion;

use Illuminate\Database\Eloquent\Model;
use App\Models\Clientes\Cliente;
use App\Models\Clientes\DireccionEntrega;
use App\Models\Clientes\Pedido;

class Suscripcion extends Model
{
    protected $table = 'suscripcion';
    protected $primaryKey = 'id_suscripcion';
    public $timestamps = false;

    protected $fillable = [
        'id_cliente',
        'id_plan',
        'id_direccion',
        'precio_congelado',
        'fecha_inicio',
        'fecha_proxima_entrega',
        'fecha_fin',
        'estado',
        'motivo_cancelacion',
    ];

    protected $casts = [
        'precio_congelado' => 'decimal:2',
        'fecha_inicio' => 'date',
        'fecha_proxima_entrega' => 'date',
        'fecha_fin' => 'date',
    ];

    public function cliente()
    {
        return $this->belongsTo(Cliente::class, 'id_cliente', 'id_cliente');
    }

    public function direccion()
    {
        return $this->belongsTo(DireccionEntrega::class, 'id_direccion', 'id_direccion');
    }

    public function plan()
    {
        return $this->belongsTo(PlanSuscripcion::class, 'id_plan', 'id_plan');
    }

    public function pedidos()
    {
        return $this->hasMany(Pedido::class, 'id_suscripcion', 'id_suscripcion');
    }
}
