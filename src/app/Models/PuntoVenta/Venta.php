<?php

namespace App\Models\PuntoVenta;

use Illuminate\Database\Eloquent\Model;
use App\Models\Clientes\Cliente;
use App\Models\Clientes\Pedido;
use App\Models\Fel\DocumentoFel;
use App\Models\Inventario\MovimientoInventario;
use App\Models\Seguridad\Usuario;

class Venta extends Model
{
    protected $table = 'venta';
    protected $primaryKey = 'id_venta';
    public $timestamps = false;

    protected $fillable = [
        'numero_venta',
        'id_cliente',
        'id_usuario',
        'id_turno',
        'id_metodo_pago',
        'id_pedido',
        'canal',
        'subtotal',
        'descuento',
        'id_usuario_autoriza_descuento',
        'justificacion_descuento',
        'monto_recibido',
        'cambio',
        'estado',
        'fecha_anulacion',
        'id_usuario_anula',
        'motivo_anulacion',
    ];

    protected $casts = [
        'fecha_hora' => 'datetime',
        'subtotal' => 'decimal:2',
        'descuento' => 'decimal:2',
        'total' => 'decimal:2',
        'monto_recibido' => 'decimal:2',
        'cambio' => 'decimal:2',
        'fecha_anulacion' => 'datetime',
    ];

    public function cliente()
    {
        return $this->belongsTo(Cliente::class, 'id_cliente', 'id_cliente');
    }

    public function metodoPago()
    {
        return $this->belongsTo(MetodoPago::class, 'id_metodo_pago', 'id_metodo_pago');
    }

    public function pedido()
    {
        return $this->belongsTo(Pedido::class, 'id_pedido', 'id_pedido');
    }

    public function turno()
    {
        return $this->belongsTo(TurnoCaja::class, 'id_turno', 'id_turno');
    }

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'id_usuario', 'id_usuario');
    }

    public function usuarioAnula()
    {
        return $this->belongsTo(Usuario::class, 'id_usuario_anula', 'id_usuario');
    }

    public function usuarioAutorizaDescuento()
    {
        return $this->belongsTo(Usuario::class, 'id_usuario_autoriza_descuento', 'id_usuario');
    }

    public function detallesVenta()
    {
        return $this->hasMany(DetalleVenta::class, 'id_venta', 'id_venta');
    }

    public function documentosFel()
    {
        return $this->hasMany(DocumentoFel::class, 'id_venta', 'id_venta');
    }

    public function movimientosInventario()
    {
        return $this->hasMany(MovimientoInventario::class, 'id_venta', 'id_venta');
    }
}
