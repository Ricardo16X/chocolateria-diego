<?php

namespace App\Models\Soporte;

use Illuminate\Database\Eloquent\Model;
use App\Models\Clientes\Cliente;
use App\Models\Seguridad\Usuario;

class Notificacion extends Model
{
    protected $table = 'notificacion';
    protected $primaryKey = 'id_notificacion';
    public $timestamps = false;

    protected $fillable = [
        'id_cliente',
        'id_usuario',
        'tipo',
        'asunto',
        'cuerpo',
        'estado',
        'intentos',
        'mensaje_error',
        'fecha_envio',
    ];

    protected $casts = [
        'fecha_creacion' => 'datetime',
        'fecha_envio' => 'datetime',
    ];

    public function cliente()
    {
        return $this->belongsTo(Cliente::class, 'id_cliente', 'id_cliente');
    }

    public function usuario()
    {
        return $this->belongsTo(Usuario::class, 'id_usuario', 'id_usuario');
    }
}
