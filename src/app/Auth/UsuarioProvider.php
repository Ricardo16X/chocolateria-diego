<?php

namespace App\Auth;

use Illuminate\Auth\EloquentUserProvider;
use Illuminate\Contracts\Auth\Authenticatable;

// Proveedor de autenticacion sobre la tabla usuario. La columna de la
// contrasena (contrasena_hash) ya la resuelve Usuario::getAuthPassword(),
// asi que aqui solo hace falta: (1) buscar por nombre_usuario o correo, y
// (2) negar la autenticacion si la cuenta esta bloqueada, antes incluso de
// comparar la contrasena. El resto de la Fase 4 (incrementar
// intentos_fallidos, bloquear al llegar al maximo, reiniciar el contador,
// actualizar ultimo_acceso, bitacora) vive en los listeners de
// App\Listeners\Auth sobre los eventos Login/Failed/Logout: son efectos de
// la autenticacion, no parte de decidir si unas credenciales son validas.
class UsuarioProvider extends EloquentUserProvider
{
    public function retrieveByCredentials(array $credentials)
    {
        $valor = $credentials['nombre_usuario'] ?? $credentials['correo'] ?? null;

        if ($valor === null) {
            return null;
        }

        $columna = isset($credentials['nombre_usuario']) ? 'nombre_usuario' : 'correo';

        return $this->newModelQuery()->where($columna, $valor)->first();
    }

    public function validateCredentials(Authenticatable $user, array $credentials): bool
    {
        if ($user->estado === 'bloqueado') {
            return false;
        }

        return parent::validateCredentials($user, $credentials);
    }
}
