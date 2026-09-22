<?php

namespace App\Models\Entregas;

use Illuminate\Database\Eloquent\Model;
use App\Models\Clientes\DireccionEntrega;

class ZonaCobertura extends Model
{
    protected $table = 'zona_cobertura';
    protected $primaryKey = 'id_zona';
    public $timestamps = false;

    protected $fillable = [
        'departamento',
        'municipio',
        'costo_envio',
        'dias_estimados',
        'estado',
    ];

    protected $casts = [
        'costo_envio' => 'decimal:2',
    ];

    public function direccionesEntrega()
    {
        return $this->hasMany(DireccionEntrega::class, 'id_zona', 'id_zona');
    }
}
