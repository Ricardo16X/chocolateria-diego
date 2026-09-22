@extends('layouts.app')

@section('titulo', 'Comprobante')

@section('contenido')
    @if ($errors->any())
        <div class="mb-4 rounded border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
            {{ $errors->first() }}
        </div>
    @endif

    <div class="mx-auto max-w-lg rounded border border-gray-200 bg-white p-6 shadow">
        <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-gray-800">{{ $venta->numero_venta }}</h2>
            <span class="rounded px-2 py-1 text-xs font-medium
                {{ $venta->estado === 'anulada' ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700' }}">
                {{ $venta->estado }}
            </span>
        </div>

        <p class="mb-4 text-sm text-gray-500">
            {{ $venta->fecha_hora->format('d/m/Y H:i') }} · {{ $venta->metodoPago->nombre }}
            · atendió {{ $venta->usuario->nombre_usuario }}
        </p>

        <table class="mb-4 w-full text-sm">
            <thead>
                <tr class="border-b border-gray-200 text-left text-gray-500">
                    <th class="py-1">Producto</th>
                    <th class="py-1 text-right">Cant.</th>
                    <th class="py-1 text-right">Precio</th>
                    <th class="py-1 text-right">Subtotal</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($venta->detallesVenta as $detalle)
                    <tr class="border-b border-gray-100">
                        <td class="py-1">{{ $detalle->producto->nombre }}</td>
                        <td class="py-1 text-right">{{ $detalle->cantidad }}</td>
                        <td class="py-1 text-right">Q{{ number_format($detalle->precio_unitario, 2) }}</td>
                        <td class="py-1 text-right">Q{{ number_format($detalle->subtotal_linea, 2) }}</td>
                    </tr>
                @endforeach
            </tbody>
        </table>

        <div class="space-y-1 text-right text-sm">
            <p>Subtotal: Q{{ number_format($venta->subtotal, 2) }}</p>
            @if ($venta->descuento > 0)
                <p>Descuento: Q{{ number_format($venta->descuento, 2) }}</p>
            @endif
            <p class="text-base font-semibold">Total: Q{{ number_format($venta->total, 2) }}</p>
        </div>

        @if ($venta->documentosFel->isNotEmpty())
            <p class="mt-4 text-xs text-gray-500">
                DTE: {{ $venta->documentosFel->first()->estado }}
                @if ($venta->documentosFel->first()->numero_autorizacion)
                    · autorización {{ $venta->documentosFel->first()->numero_autorizacion }}
                @endif
            </p>
        @endif

        @if ($venta->estado === 'completada')
            <form method="POST" action="{{ route('punto-venta.anular', $venta) }}" class="mt-6 flex items-center gap-2">
                @csrf
                <input
                    type="text" name="motivo" placeholder="Motivo de la anulación" required
                    class="flex-1 rounded border-gray-300 text-sm shadow-sm"
                >
                <button type="submit" class="rounded border border-red-300 px-3 py-2 text-sm text-red-700 hover:bg-red-50">
                    Anular venta
                </button>
            </form>
        @endif

        <a href="{{ route('punto-venta.index') }}" class="mt-6 block text-center text-sm text-gray-600 hover:underline">
            Volver al punto de venta
        </a>
    </div>
@endsection
