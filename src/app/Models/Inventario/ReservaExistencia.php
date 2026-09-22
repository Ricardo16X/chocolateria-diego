<?php

namespace App\Models\Inventario;

use Illuminate\Database\Eloquent\Model;
use App\Models\Catalogo\Producto;
use App\Models\Clientes\Pedido;

class ReservaExistencia extends Model
{
    protected $table = 'reserva_existencia';
    protected $primaryKey = 'id_reserva';
    public $timestamps = false;

    protected $fillable = [
        'id_pedido',
        'id_producto',
        'id_bodega',
        'cantidad',
        'fecha_expiracion',
        'estado',
        'fecha_liberacion',
    ];

    protected $casts = [
        'cantidad' => 'decimal:3',
        'fecha_creacion' => 'datetime',
        'fecha_expiracion' => 'datetime',
        'fecha_liberacion' => 'datetime',
    ];

    public function bodega()
    {
        return $this->belongsTo(Bodega::class, 'id_bodega', 'id_bodega');
    }

    public function pedido()
    {
        return $this->belongsTo(Pedido::class, 'id_pedido', 'id_pedido');
    }

    public function producto()
    {
        return $this->belongsTo(Producto::class, 'id_producto', 'id_producto');
    }
}
