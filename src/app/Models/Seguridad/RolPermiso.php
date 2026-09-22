<?php

namespace App\Models\Seguridad;

use Illuminate\Database\Eloquent\Model;

class RolPermiso extends Model
{
    protected $table = 'rol_permiso';
    // Clave compuesta: Eloquent no la soporta de forma nativa.
    // Columnas reales: id_rol, id_permiso. Usar where() para consultas
    // puntuales; para navegar la relacion, usar belongsToMany en Rol y Permiso.
    protected $primaryKey = 'id_rol';
    public $incrementing = false;
    public $timestamps = false;

    protected $fillable = [
        'id_rol',
        'id_permiso',
    ];

    protected $casts = [
        'fecha_asignacion' => 'datetime',
    ];

    public function permiso()
    {
        return $this->belongsTo(Permiso::class, 'id_permiso', 'id_permiso');
    }

    public function rol()
    {
        return $this->belongsTo(Rol::class, 'id_rol', 'id_rol');
    }
}
