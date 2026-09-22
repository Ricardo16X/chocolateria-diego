<?php

namespace App\Models\Inventario;

use Illuminate\Database\Eloquent\Model;

class TipoMovimiento extends Model
{
    protected $table = 'tipo_movimiento';
    protected $primaryKey = 'id_tipo_movimiento';
    public $timestamps = false;

    protected $fillable = [
        'nombre',
        'efecto',
        'requiere_autorizacion',
    ];

    protected $casts = [
        'requiere_autorizacion' => 'boolean',
    ];

    public function movimientosInventario()
    {
        return $this->hasMany(MovimientoInventario::class, 'id_tipo_movimiento', 'id_tipo_movimiento');
    }
}
