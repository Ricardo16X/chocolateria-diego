<?php

namespace App\Models\Seguridad;

use App\Models\Catalogo\HistorialPrecio;
use App\Models\Clientes\Pedido;
use App\Models\Entregas\Envio;
use App\Models\Inventario\MovimientoInventario;
use App\Models\PuntoVenta\TurnoCaja;
use App\Models\PuntoVenta\Venta;
use App\Models\Soporte\Notificacion;
use App\Models\Soporte\ParametroSistema;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

// Autenticacion: la contrasena vive en la columna contrasena_hash, no en
// "password". getAuthPassword() se lo indica al guard; el bloqueo de
// cuenta (intentos_fallidos/estado) lo aplica el proveedor de auth en la
// Fase 4, no este modelo.
class Usuario extends Authenticatable
{
    use HasApiTokens;

    protected $table = 'usuario';
    protected $primaryKey = 'id_usuario';
    public $timestamps = false;

    protected $fillable = [
        'id_rol',
        'nombre',
        'apellido',
        'nombre_usuario',
        'correo',
        'contrasena_hash',
        'estado',
        'intentos_fallidos',
        'ultimo_acceso',
    ];

    protected $hidden = [
        'contrasena_hash',
    ];

    protected $casts = [
        'ultimo_acceso' => 'datetime',
        'fecha_creacion' => 'datetime',
    ];

    public function getAuthPassword()
    {
        return $this->contrasena_hash;
    }

    public function rol()
    {
        return $this->belongsTo(Rol::class, 'id_rol', 'id_rol');
    }

    public function bitacoras()
    {
        return $this->hasMany(Bitacora::class, 'id_usuario', 'id_usuario');
    }

    public function envios()
    {
        return $this->hasMany(Envio::class, 'id_usuario_despacha', 'id_usuario');
    }

    public function historialesPrecio()
    {
        return $this->hasMany(HistorialPrecio::class, 'id_usuario', 'id_usuario');
    }

    public function movimientosInventario()
    {
        return $this->hasMany(MovimientoInventario::class, 'id_usuario', 'id_usuario');
    }

    public function movimientosInventarioAutoriza()
    {
        return $this->hasMany(MovimientoInventario::class, 'id_usuario_autoriza', 'id_usuario');
    }

    public function notificaciones()
    {
        return $this->hasMany(Notificacion::class, 'id_usuario', 'id_usuario');
    }

    public function parametrosSistema()
    {
        return $this->hasMany(ParametroSistema::class, 'id_usuario_modifica', 'id_usuario');
    }

    public function pedidos()
    {
        return $this->hasMany(Pedido::class, 'id_usuario_verifica', 'id_usuario');
    }

    public function turnosCaja()
    {
        return $this->hasMany(TurnoCaja::class, 'id_usuario', 'id_usuario');
    }

    public function ventas()
    {
        return $this->hasMany(Venta::class, 'id_usuario', 'id_usuario');
    }

    public function ventasAnula()
    {
        return $this->hasMany(Venta::class, 'id_usuario_anula', 'id_usuario');
    }

    public function ventasAutorizaDescuento()
    {
        return $this->hasMany(Venta::class, 'id_usuario_autoriza_descuento', 'id_usuario');
    }
}
