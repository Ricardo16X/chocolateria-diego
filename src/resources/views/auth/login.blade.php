@extends('layouts.app')

@section('titulo', 'Ingreso')

@section('contenido')
    <div class="mx-auto max-w-sm">
        <h2 class="mb-6 text-xl font-semibold text-gray-800">Ingreso al sistema</h2>

        @if ($errors->any())
            <div class="mb-4 rounded border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
                {{ $errors->first() }}
            </div>
        @endif

        <form method="POST" action="{{ route('ingreso.intentar') }}" class="space-y-4">
            @csrf

            <div>
                <label for="nombre_usuario" class="block text-sm font-medium text-gray-700">Usuario</label>
                <input
                    type="text"
                    id="nombre_usuario"
                    name="nombre_usuario"
                    value="{{ old('nombre_usuario') }}"
                    required
                    autofocus
                    class="mt-1 block w-full rounded border-gray-300 shadow-sm focus:border-gray-500 focus:ring-gray-500"
                >
            </div>

            <div>
                <label for="password" class="block text-sm font-medium text-gray-700">Contraseña</label>
                <input
                    type="password"
                    id="password"
                    name="password"
                    required
                    class="mt-1 block w-full rounded border-gray-300 shadow-sm focus:border-gray-500 focus:ring-gray-500"
                >
            </div>

            <button
                type="submit"
                class="w-full rounded bg-gray-800 px-4 py-2 text-white hover:bg-gray-900"
            >
                Ingresar
            </button>
        </form>
    </div>
@endsection
