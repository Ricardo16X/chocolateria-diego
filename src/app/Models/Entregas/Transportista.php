<?php

namespace App\Models\Entregas;

use Illuminate\Database\Eloquent\Model;

class Transportista extends Model
{
    protected $table = 'transportista';
    protected $primaryKey = 'id_transportista';
    public $timestamps = false;

    protected $fillable = [
        'nombre',
        'tipo',
        'telefono_contacto',
        'estado',
    ];

    public function envios()
    {
        return $this->hasMany(Envio::class, 'id_transportista', 'id_transportista');
    }
}
