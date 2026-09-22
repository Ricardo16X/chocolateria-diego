<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

class SesionController extends Controller
{
    public function mostrarFormulario(): View
    {
        return view('auth.login');
    }

    public function iniciarSesion(Request $request): RedirectResponse
    {
        $credenciales = $request->validate([
            'nombre_usuario' => ['required', 'string'],
            'password' => ['required', 'string'],
        ]);

        // Auth::attempt dispara los eventos Login o Failed segun el
        // resultado; los listeners de App\Listeners\Auth se encargan del
        // bloqueo de cuenta y de la bitacora (ver UsuarioProvider).
        if (Auth::attempt($credenciales)) {
            $request->session()->regenerate();

            return redirect()->intended(route('panel'));
        }

        return back()
            ->withErrors(['nombre_usuario' => 'Usuario o contraseña incorrectos, o la cuenta está bloqueada.'])
            ->onlyInput('nombre_usuario');
    }

    public function cerrarSesion(Request $request): RedirectResponse
    {
        Auth::logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('ingreso');
    }
}
