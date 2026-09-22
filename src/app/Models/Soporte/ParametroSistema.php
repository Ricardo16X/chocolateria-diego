<?php

namespace App\Models\Soporte;

use Illuminate\Database\Eloquent\Model;
use App\Models\Seguridad\Usuario;

class ParametroSistema extends Model
{
    protected $table = 'parametro_sistema';
    protected $primaryKey = 'id_parametro';
    public $timestamps = false;

    protected $fillable = [
        'clave',
        'valor',
        'tipo_dato',
        'descripcion',
        'editable',
        'id_usuario_modifica',
        'fecha_modificacion',
    ];

    protected $casts = [
        'editable' => 'boolean',
        'fecha_modificacion' => 'datetime',
    ];

    public function usuarioModifica()
    {
        return $this->belongsTo(Usuario::class, 'id_usuario_modifica', 'id_usuario');
    }
}
