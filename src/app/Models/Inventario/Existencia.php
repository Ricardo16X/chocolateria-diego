<?php

namespace App\Models\Inventario;

use Illuminate\Database\Eloquent\Model;
use App\Models\Catalogo\Producto;

class Existencia extends Model
{
    protected $table = 'existencia';
    protected $primaryKey = 'id_existencia';
    public $timestamps = false;

    protected $fillable = [
        'id_producto',
        'id_lote',
        'id_bodega',
        'cantidad_disponible',
    ];

    protected $casts = [
        'cantidad_disponible' => 'decimal:3',
        'fecha_actualizacion' => 'datetime',
    ];

    public function bodega()
    {
        return $this->belongsTo(Bodega::class, 'id_bodega', 'id_bodega');
    }

    public function lote()
    {
        return $this->belongsTo(Lote::class, 'id_lote', 'id_lote');
    }

    public function producto()
    {
        return $this->belongsTo(Producto::class, 'id_producto', 'id_producto');
    }
}
