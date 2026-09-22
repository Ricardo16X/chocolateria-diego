@extends('layouts.app')

@section('titulo', 'Punto de venta')

@section('contenido')
    @if ($errors->any())
        <div class="mb-4 rounded border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {{ $errors->first() }}
        </div>
    @endif

    @unless ($turno)
        <div class="mx-auto max-w-sm rounded border border-gray-200 bg-white p-6 shadow">
            <h2 class="mb-4 text-lg font-semibold text-gray-800">Abrir turno de caja</h2>
            <form method="POST" action="{{ route('punto-venta.turno.abrir') }}" class="space-y-4">
                @csrf
                <div>
                    <label for="monto_inicial" class="block text-sm font-medium text-gray-700">Monto inicial</label>
                    <input
                        type="number" step="0.01" min="0" id="monto_inicial" name="monto_inicial"
                        required class="mt-1 block w-full rounded border-gray-300 shadow-sm"
                    >
                </div>
                <button type="submit" class="w-full rounded bg-gray-800 px-4 py-2 text-white hover:bg-gray-900">
                    Abrir turno
                </button>
            </form>
        </div>
    @else
        <div class="mb-6 flex items-center justify-between rounded border border-gray-200 bg-white px-4 py-3 shadow">
            <span class="text-sm text-gray-600">
                Turno #{{ $turno->id_turno }} abierto desde {{ $turno->fecha_apertura->format('H:i') }}
                · monto inicial Q{{ number_format($turno->monto_inicial, 2) }}
            </span>
            <form method="POST" action="{{ route('punto-venta.turno.cerrar') }}" class="flex items-center gap-2">
                @csrf
                <input
                    type="number" step="0.01" min="0" name="monto_declarado"
                    placeholder="Monto declarado" required
                    class="rounded border-gray-300 text-sm shadow-sm"
                >
                <button type="submit" class="rounded border border-gray-300 px-3 py-1.5 text-sm hover:bg-gray-100">
                    Cerrar turno
                </button>
            </form>
        </div>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <div>
                <h2 class="mb-3 text-lg font-semibold text-gray-800">Buscar producto</h2>
                <form method="GET" action="{{ route('punto-venta.index') }}" class="mb-4 flex gap-2">
                    <input
                        type="text" name="q" value="{{ $q }}" placeholder="Código o nombre"
                        class="flex-1 rounded border-gray-300 shadow-sm"
                    >
                    <button type="submit" class="rounded bg-gray-800 px-4 py-2 text-white hover:bg-gray-900">
                        Buscar
                    </button>
                </form>

                <ul class="divide-y divide-gray-200 rounded border border-gray-200 bg-white">
                    @forelse ($resultados as $producto)
                        <li class="flex items-center justify-between px-4 py-3">
                            <div>
                                <p class="font-medium text-gray-800">{{ $producto->nombre }}</p>
                                <p class="text-xs text-gray-500">
                                    {{ $producto->codigo }} · Q{{ number_format($producto->precio_venta, 2) }}
                                    · existencia: {{ $producto->stock_disponible }}
                                </p>
                            </div>
                            <form method="POST" action="{{ route('punto-venta.carrito.agregar') }}" class="flex items-center gap-2">
                                @csrf
                                <input type="hidden" name="id_producto" value="{{ $producto->id_producto }}">
                                <input
                                    type="number" step="0.001" min="0.001" name="cantidad" value="1"
                                    class="w-20 rounded border-gray-300 text-sm shadow-sm"
                                >
                                <button type="submit" class="rounded border border-gray-300 px-3 py-1.5 text-sm hover:bg-gray-100">
                                    Agregar
                                </button>
                            </form>
                        </li>
                    @empty
                        <li class="px-4 py-3 text-sm text-gray-500">
                            {{ $q === '' ? 'Escriba para buscar un producto.' : 'Sin resultados.' }}
                        </li>
                    @endforelse
                </ul>
            </div>

            <div>
                <h2 class="mb-3 text-lg font-semibold text-gray-800">Carrito</h2>
                <ul class="mb-4 divide-y divide-gray-200 rounded border border-gray-200 bg-white">
                    @forelse ($carrito as $producto)
                        <li class="flex items-center justify-between px-4 py-3">
                            <div>
                                <p class="font-medium text-gray-800">{{ $producto->nombre }}</p>
                                <p class="text-xs text-gray-500">
                                    {{ $producto->cantidad_carrito }} × Q{{ number_format($producto->precio_venta, 2) }}
                                    = Q{{ number_format($producto->subtotal_carrito, 2) }}
                                </p>
                            </div>
                            <form method="POST" action="{{ route('punto-venta.carrito.quitar', $producto->id_producto) }}">
                                @csrf
                                @method('DELETE')
                                <button type="submit" class="text-sm text-red-600 hover:underline">Quitar</button>
                            </form>
                        </li>
                    @empty
                        <li class="px-4 py-3 text-sm text-gray-500">El carrito está vacío.</li>
                    @endforelse
                </ul>

                @if ($carrito->isNotEmpty())
                    <form method="POST" action="{{ route('punto-venta.confirmar') }}" class="space-y-3 rounded border border-gray-200 bg-white p-4 shadow">
                        @csrf
                        <div>
                            <label for="id_metodo_pago" class="block text-sm font-medium text-gray-700">Método de pago</label>
                            <select id="id_metodo_pago" name="id_metodo_pago" required class="mt-1 block w-full rounded border-gray-300 shadow-sm">
                                @foreach ($metodosPago as $metodo)
                                    <option value="{{ $metodo->id_metodo_pago }}">{{ $metodo->nombre }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div>
                            <label for="nombre_receptor" class="block text-sm font-medium text-gray-700">
                                Nombre del receptor (opcional, consumidor final por defecto)
                            </label>
                            <input type="text" id="nombre_receptor" name="nombre_receptor" class="mt-1 block w-full rounded border-gray-300 shadow-sm">
                        </div>
                        <button type="submit" class="w-full rounded bg-gray-800 px-4 py-2 text-white hover:bg-gray-900">
                            Confirmar venta
                        </button>
                    </form>
                @endif
            </div>
        </div>
    @endunless
@endsection
