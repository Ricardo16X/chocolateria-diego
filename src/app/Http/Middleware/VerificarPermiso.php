<?php

namespace App\Http\Middleware;

use App\Models\Seguridad\Permiso;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

// Uso: Route::middleware('permiso:catalogo.crear'). Consulta rol_permiso a
// traves de Permiso::roles() (belongsToMany, ver Fase 3) para el rol del
// usuario autenticado; 403 si no lo tiene, 401 si no hay sesion.
class VerificarPermiso
{
    public function handle(Request $request, Closure $next, string $permiso): Response
    {
        [$modulo, $accion] = array_pad(explode('.', $permiso, 2), 2, null);

        $usuario = $request->user();

        if (! $usuario) {
            abort(401);
        }

        $tienePermiso = Permiso::where('modulo', $modulo)
            ->where('accion', $accion)
            ->whereHas('roles', function ($consulta) use ($usuario) {
                $consulta->where('rol.id_rol', $usuario->id_rol);
            })
            ->exists();

        if (! $tienePermiso) {
            abort(403);
        }

        return $next($request);
    }
}
