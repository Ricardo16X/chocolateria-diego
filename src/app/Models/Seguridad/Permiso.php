<?php

namespace App\Models\Seguridad;

use Illuminate\Database\Eloquent\Model;

class Permiso extends Model
{
    protected $table = 'permiso';
    protected $primaryKey = 'id_permiso';
    public $timestamps = false;

    protected $fillable = [
        'modulo',
        'accion',
        'descripcion',
    ];

    public function rolesPermiso()
    {
        return $this->hasMany(RolPermiso::class, 'id_permiso', 'id_permiso');
    }

    // Navegacion de la relacion N:M real; rolesPermiso() arriba da acceso a
    // la fila cruda de rol_permiso cuando hace falta, p. ej. fecha_asignacion.
    public function roles()
    {
        return $this->belongsToMany(
            Rol::class,
            'rol_permiso',
            'id_permiso',
            'id_rol'
        )->withPivot('fecha_asignacion');
    }
}
