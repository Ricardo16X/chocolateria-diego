<?php

namespace App\Models\Inventario;

use Illuminate\Database\Eloquent\Model;
use App\Models\PuntoVenta\TurnoCaja;

class Bodega extends Model
{
    protected $table = 'bodega';
    protected $primaryKey = 'id_bodega';
    public $timestamps = false;

    protected $fillable = [
        'nombre',
        'tipo',
        'direccion',
        'estado',
    ];

    public function existencias()
    {
        return $this->hasMany(Existencia::class, 'id_bodega', 'id_bodega');
    }

    public function movimientosInventario()
    {
        return $this->hasMany(MovimientoInventario::class, 'id_bodega', 'id_bodega');
    }

    public function reservasExistencia()
    {
        return $this->hasMany(ReservaExistencia::class, 'id_bodega', 'id_bodega');
    }

    public function turnosCaja()
    {
        return $this->hasMany(TurnoCaja::class, 'id_bodega', 'id_bodega');
    }
}
