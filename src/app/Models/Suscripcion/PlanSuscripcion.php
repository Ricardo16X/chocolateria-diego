<?php

namespace App\Models\Suscripcion;

use Illuminate\Database\Eloquent\Model;

class PlanSuscripcion extends Model
{
    protected $table = 'plan_suscripcion';
    protected $primaryKey = 'id_plan';
    public $timestamps = false;

    protected $fillable = [
        'nombre',
        'descripcion',
        'periodicidad',
        'precio',
        'estado',
    ];

    protected $casts = [
        'precio' => 'decimal:2',
    ];

    public function suscripciones()
    {
        return $this->hasMany(Suscripcion::class, 'id_plan', 'id_plan');
    }
}
