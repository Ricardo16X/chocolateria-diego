<?php

namespace App\Models\Inventario;

use Illuminate\Database\Eloquent\Model;
use App\Models\Catalogo\Producto;
use App\Models\Clientes\Pedido;
use App\Models\PuntoVenta\Venta;
use App\Models\Seguridad\Usuario;

class MovimientoInventario extends Model
{
    protected $table = 'movimiento_inventario';
    protected $primaryKey = 'id_movimiento';
    public $timestamps = false;

    protected $fillable = [
        'id_tipo_movimiento',
        'id_producto',
        'id_lote',
        'id_bodega',
        'cantidad',
        'saldo_posterior',
        'id_usuario',
        'id_usuario_autoriza',
        'motivo',
        'id_venta',
        'id_pedido',
    ];

    protected $casts = [
        'cantidad' => 'decimal:3',
        'saldo_posterior' => 'decimal:3',
        'fecha_hora' => 'datetime',
    ];

    public function bodega()
    {
        return $this->belongsTo(Bodega::class, 'id_bodega', 'id_bodega');
    }

    public function lote()
    {
        return $this->belongsTo(Lote::class, 'id_lote', 'id_lote');
    }

    public function pedido()
    {
        return $this->belongsTo(Pedido::class, 'id_pedido', 'id_pedido');
    }

    public function producto()
    {
        return $this->belongsTo(Producto::class, 'id_producto', 'id_producto');
    }

    public function tipoMovimiento()
    {
        return $this->belongsTo(TipoMovimiento::class, 'id_tipo_movimiento', 'id_tipo_movimiento');
    }

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'id_usuario', 'id_usuario');
    }

    public function usuarioAutoriza()
    {
        return $this->belongsTo(Usuario::class, 'id_usuario_autoriza', 'id_usuario');
    }

    public function venta()
    {
        return $this->belongsTo(Venta::class, 'id_venta', 'id_venta');
    }
}
