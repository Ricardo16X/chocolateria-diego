@extends('layouts.app')

@section('titulo', 'Panel')

@section('contenido')
    <div class="flex items-center justify-between">
        <div>
            <h2 class="text-xl font-semibold text-gray-800">
                Bienvenido, {{ $usuario->nombre }} {{ $usuario->apellido }}
            </h2>
            <p class="text-sm text-gray-500">
                Usuario: {{ $usuario->nombre_usuario }} · Rol: {{ $usuario->rol->nombre }}
            </p>
        </div>

        <form method="POST" action="{{ route('salir') }}">
            @csrf
            <button
                type="submit"
                class="rounded border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
            >
                Cerrar sesión
            </button>
        </form>
    </div>
@endsection
