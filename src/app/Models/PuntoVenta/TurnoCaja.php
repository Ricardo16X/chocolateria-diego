<?php

namespace App\Models\PuntoVenta;

use Illuminate\Database\Eloquent\Model;
use App\Models\Inventario\Bodega;
use App\Models\Seguridad\Usuario;

class TurnoCaja extends Model
{
    protected $table = 'turno_caja';
    protected $primaryKey = 'id_turno';
    public $timestamps = false;

    protected $fillable = [
        'id_usuario',
        'id_bodega',
        'fecha_apertura',
        'monto_inicial',
        'fecha_cierre',
        'monto_declarado',
        'monto_sistema',
        'estado',
    ];

    protected $casts = [
        'fecha_apertura' => 'datetime',
        'monto_inicial' => 'decimal:2',
        'fecha_cierre' => 'datetime',
        'monto_declarado' => 'decimal:2',
        'monto_sistema' => 'decimal:2',
    ];

    public function bodega()
    {
        return $this->belongsTo(Bodega::class, 'id_bodega', 'id_bodega');
    }

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'id_usuario', 'id_usuario');
    }

    public function ventas()
    {
        return $this->hasMany(Venta::class, 'id_turno', 'id_turno');
    }
}
