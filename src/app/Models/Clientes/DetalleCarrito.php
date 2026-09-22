<?php

namespace App\Models\Clientes;

use Illuminate\Database\Eloquent\Model;
use App\Models\Catalogo\Producto;

class DetalleCarrito extends Model
{
    protected $table = 'detalle_carrito';
    protected $primaryKey = 'id_detalle_carrito';
    public $timestamps = false;

    protected $fillable = [
        'id_carrito',
        'id_producto',
        'cantidad',
    ];

    protected $casts = [
        'cantidad' => 'decimal:3',
    ];

    public function carrito()
    {
        return $this->belongsTo(Carrito::class, 'id_carrito', 'id_carrito');
    }

    public function producto()
    {
        return $this->belongsTo(Producto::class, 'id_producto', 'id_producto');
    }
}
