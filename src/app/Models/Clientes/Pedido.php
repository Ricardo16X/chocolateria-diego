<?php

namespace App\Models\Clientes;

use Illuminate\Database\Eloquent\Model;
use App\Models\Entregas\Envio;
use App\Models\Inventario\MovimientoInventario;
use App\Models\Inventario\ReservaExistencia;
use App\Models\PuntoVenta\MetodoPago;
use App\Models\PuntoVenta\Venta;
use App\Models\Seguridad\Usuario;
use App\Models\Suscripcion\Suscripcion;

class Pedido extends Model
{
    protected $table = 'pedido';
    protected $primaryKey = 'id_pedido';
    public $timestamps = false;

    protected $fillable = [
        'numero_pedido',
        'id_cliente',
        'id_direccion',
        'id_metodo_pago',
        'id_suscripcion',
        'subtotal',
        'costo_envio',
        'estado',
        'comprobante_pago_url',
        'fecha_verificacion_pago',
        'id_usuario_verifica',
        'fecha_cancelacion',
        'motivo_cancelacion',
    ];

    protected $casts = [
        'fecha_pedido' => 'datetime',
        'subtotal' => 'decimal:2',
        'costo_envio' => 'decimal:2',
        'total' => 'decimal:2',
        'fecha_verificacion_pago' => 'datetime',
        'fecha_cancelacion' => 'datetime',
    ];

    public function cliente()
    {
        return $this->belongsTo(Cliente::class, 'id_cliente', 'id_cliente');
    }

    public function direccion()
    {
        return $this->belongsTo(DireccionEntrega::class, 'id_direccion', 'id_direccion');
    }

    public function metodoPago()
    {
        return $this->belongsTo(MetodoPago::class, 'id_metodo_pago', 'id_metodo_pago');
    }

    public function suscripcion()
    {
        return $this->belongsTo(Suscripcion::class, 'id_suscripcion', 'id_suscripcion');
    }

    public function usuarioVerifica()
    {
        return $this->belongsTo(Usuario::class, 'id_usuario_verifica', 'id_usuario');
    }

    public function detallesPedido()
    {
        return $this->hasMany(DetallePedido::class, 'id_pedido', 'id_pedido');
    }

    public function envios()
    {
        return $this->hasMany(Envio::class, 'id_pedido', 'id_pedido');
    }

    public function movimientosInventario()
    {
        return $this->hasMany(MovimientoInventario::class, 'id_pedido', 'id_pedido');
    }

    public function reservasExistencia()
    {
        return $this->hasMany(ReservaExistencia::class, 'id_pedido', 'id_pedido');
    }

    public function ventas()
    {
        return $this->hasMany(Venta::class, 'id_pedido', 'id_pedido');
    }
}
