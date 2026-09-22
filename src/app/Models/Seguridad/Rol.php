<?php

namespace App\Models\Seguridad;

use Illuminate\Database\Eloquent\Model;

class Rol extends Model
{
    protected $table = 'rol';
    protected $primaryKey = 'id_rol';
    public $timestamps = false;

    protected $fillable = [
        'nombre',
        'descripcion',
        'estado',
    ];

    public function rolesPermiso()
    {
        return $this->hasMany(RolPermiso::class, 'id_rol', 'id_rol');
    }

    public function usuarios()
    {
        return $this->hasMany(Usuario::class, 'id_rol', 'id_rol');
    }

    // Navegacion de la relacion N:M real; rolesPermiso() arriba da acceso a
    // la fila cruda de rol_permiso cuando hace falta, p. ej. fecha_asignacion.
    public function permisos()
    {
        return $this->belongsToMany(
            Permiso::class,
            'rol_permiso',
            'id_rol',
            'id_permiso'
        )->withPivot('fecha_asignacion');
    }
}
