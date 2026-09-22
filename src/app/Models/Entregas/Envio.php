<?php

namespace App\Models\Entregas;

use Illuminate\Database\Eloquent\Model;
use App\Models\Clientes\Pedido;
use App\Models\Seguridad\Usuario;

class Envio extends Model
{
    protected $table = 'envio';
    protected $primaryKey = 'id_envio';
    public $timestamps = false;

    protected $fillable = [
        'id_pedido',
        'id_transportista',
        'id_usuario_despacha',
        'numero_guia',
        'fecha_despacho',
        'fecha_entrega_estimada',
        'fecha_entrega_real',
        'estado',
        'observacion',
    ];

    protected $casts = [
        'fecha_despacho' => 'datetime',
        'fecha_entrega_estimada' => 'date',
        'fecha_entrega_real' => 'datetime',
    ];

    public function pedido()
    {
        return $this->belongsTo(Pedido::class, 'id_pedido', 'id_pedido');
    }

    public function transportista()
    {
        return $this->belongsTo(Transportista::class, 'id_transportista', 'id_transportista');
    }

    public function usuarioDespacha()
    {
        return $this->belongsTo(Usuario::class, 'id_usuario_despacha', 'id_usuario');
    }
}
