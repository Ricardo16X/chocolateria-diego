<?php

namespace App\Models\Catalogo;

use Illuminate\Database\Eloquent\Model;
use App\Models\Seguridad\Usuario;

class HistorialPrecio extends Model
{
    protected $table = 'historial_precio';
    protected $primaryKey = 'id_historial_precio';
    public $timestamps = false;

    protected $fillable = [
        'id_producto',
        'precio_anterior',
        'precio_nuevo',
        'id_usuario',
        'motivo',
    ];

    protected $casts = [
        'precio_anterior' => 'decimal:2',
        'precio_nuevo' => 'decimal:2',
        'fecha_cambio' => 'datetime',
    ];

    public function producto()
    {
        return $this->belongsTo(Producto::class, 'id_producto', 'id_producto');
    }

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'id_usuario', 'id_usuario');
    }
}
