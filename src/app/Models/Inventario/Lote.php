<?php

namespace App\Models\Inventario;

use Illuminate\Database\Eloquent\Model;
use App\Models\Catalogo\Producto;
use App\Models\PuntoVenta\DetalleVenta;

class Lote extends Model
{
    protected $table = 'lote';
    protected $primaryKey = 'id_lote';
    public $timestamps = false;

    protected $fillable = [
        'id_producto',
        'codigo_lote',
        'fecha_produccion',
        'fecha_vencimiento',
        'cantidad_inicial',
        'estado',
    ];

    protected $casts = [
        'fecha_produccion' => 'date',
        'fecha_vencimiento' => 'date',
        'cantidad_inicial' => 'decimal:3',
    ];

    public function producto()
    {
        return $this->belongsTo(Producto::class, 'id_producto', 'id_producto');
    }

    public function detallesVenta()
    {
        return $this->hasMany(DetalleVenta::class, 'id_lote', 'id_lote');
    }

    public function existencias()
    {
        return $this->hasMany(Existencia::class, 'id_lote', 'id_lote');
    }

    public function movimientosInventario()
    {
        return $this->hasMany(MovimientoInventario::class, 'id_lote', 'id_lote');
    }
}
