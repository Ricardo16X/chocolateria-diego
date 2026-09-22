<?php

namespace App\Models\Catalogo;

use Illuminate\Database\Eloquent\Model;
use App\Models\Clientes\DetalleCarrito;
use App\Models\Clientes\DetallePedido;
use App\Models\Inventario\Existencia;
use App\Models\Inventario\Lote;
use App\Models\Inventario\MovimientoInventario;
use App\Models\Inventario\ReservaExistencia;
use App\Models\PuntoVenta\DetalleVenta;

class Producto extends Model
{
    protected $table = 'producto';
    protected $primaryKey = 'id_producto';
    public $timestamps = false;

    protected $fillable = [
        'id_categoria',
        'codigo',
        'nombre',
        'descripcion',
        'porcentaje_cacao',
        'unidad_medida',
        'precio_venta',
        'costo_referencia',
        'stock_minimo',
        'dias_alerta_vencimiento',
        'maneja_lote',
        'visible_tienda',
        'imagen_url',
        'estado',
    ];

    protected $casts = [
        'precio_venta' => 'decimal:2',
        'costo_referencia' => 'decimal:2',
        'stock_minimo' => 'decimal:3',
        'maneja_lote' => 'boolean',
        'visible_tienda' => 'boolean',
        'fecha_creacion' => 'datetime',
    ];

    public function categoria()
    {
        return $this->belongsTo(Categoria::class, 'id_categoria', 'id_categoria');
    }

    public function detallesCarrito()
    {
        return $this->hasMany(DetalleCarrito::class, 'id_producto', 'id_producto');
    }

    public function detallesPedido()
    {
        return $this->hasMany(DetallePedido::class, 'id_producto', 'id_producto');
    }

    public function detallesVenta()
    {
        return $this->hasMany(DetalleVenta::class, 'id_producto', 'id_producto');
    }

    public function existencias()
    {
        return $this->hasMany(Existencia::class, 'id_producto', 'id_producto');
    }

    public function historialesPrecio()
    {
        return $this->hasMany(HistorialPrecio::class, 'id_producto', 'id_producto');
    }

    public function lotes()
    {
        return $this->hasMany(Lote::class, 'id_producto', 'id_producto');
    }

    public function movimientosInventario()
    {
        return $this->hasMany(MovimientoInventario::class, 'id_producto', 'id_producto');
    }

    public function reservasExistencia()
    {
        return $this->hasMany(ReservaExistencia::class, 'id_producto', 'id_producto');
    }
}
