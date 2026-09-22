<?php

namespace App\Models\Clientes;

use Illuminate\Database\Eloquent\Model;
use App\Models\PuntoVenta\Venta;
use App\Models\Soporte\Notificacion;
use App\Models\Suscripcion\Suscripcion;

class Cliente extends Model
{
    protected $table = 'cliente';
    protected $primaryKey = 'id_cliente';
    public $timestamps = false;

    protected $fillable = [
        'nombre',
        'apellido',
        'nit',
        'correo',
        'telefono',
        'pais',
        'origen',
        'contrasena_hash',
        'acepta_notificaciones',
        'estado',
    ];

    protected $casts = [
        'acepta_notificaciones' => 'boolean',
        'fecha_registro' => 'datetime',
    ];

    public function carritos()
    {
        return $this->hasMany(Carrito::class, 'id_cliente', 'id_cliente');
    }

    public function direccionesEntrega()
    {
        return $this->hasMany(DireccionEntrega::class, 'id_cliente', 'id_cliente');
    }

    public function notificaciones()
    {
        return $this->hasMany(Notificacion::class, 'id_cliente', 'id_cliente');
    }

    public function pedidos()
    {
        return $this->hasMany(Pedido::class, 'id_cliente', 'id_cliente');
    }

    public function suscripciones()
    {
        return $this->hasMany(Suscripcion::class, 'id_cliente', 'id_cliente');
    }

    public function ventas()
    {
        return $this->hasMany(Venta::class, 'id_cliente', 'id_cliente');
    }
}
