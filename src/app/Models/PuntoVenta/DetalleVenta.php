<?php

namespace App\Models\PuntoVenta;

use Illuminate\Database\Eloquent\Model;
use App\Models\Catalogo\Producto;
use App\Models\Inventario\Lote;

class DetalleVenta extends Model
{
    protected $table = 'detalle_venta';
    protected $primaryKey = 'id_detalle_venta';
    public $timestamps = false;

    protected $fillable = [
        'id_venta',
        'id_producto',
        'id_lote',
        'cantidad',
        'precio_unitario',
    ];

    protected $casts = [
        'cantidad' => 'decimal:3',
        'precio_unitario' => 'decimal:2',
        'subtotal_linea' => 'decimal:2',
    ];

    public function lote()
    {
        return $this->belongsTo(Lote::class, 'id_lote', 'id_lote');
    }

    public function producto()
    {
        return $this->belongsTo(Producto::class, 'id_producto', 'id_producto');
    }

    public function venta()
    {
        return $this->belongsTo(Venta::class, 'id_venta', 'id_venta');
    }
}
