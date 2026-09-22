<?php

namespace App\Http\Controllers;

use App\Exceptions\ExcepcionNegocio;
use App\Models\Catalogo\Producto;
use App\Models\Inventario\Bodega;
use App\Models\PuntoVenta\MetodoPago;
use App\Models\PuntoVenta\TurnoCaja;
use App\Models\PuntoVenta\Venta;
use App\Services\VentaService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

// Punto de venta de mostrador. El carrito vive en la sesion (clave
// "carrito_pos"): es el carrito de caja, no el de la tienda en linea
// (carrito/detalle_carrito, modulo Clientes). sp_registrar_venta no separa
// por bodega -- FEFO recorre toda la existencia del producto -- asi que la
// unica bodega que hace falta aqui es la del turno de caja.
class PuntoVentaController extends Controller
{
    private const CLAVE_CARRITO = 'carrito_pos';

    public function index(Request $request): View
    {
        $turno = $this->turnoAbierto($request);

        $resultados = collect();
        $q = trim((string) $request->query('q', ''));

        if ($turno && $q !== '') {
            $resultados = Producto::where('estado', 'activo')
                ->where(function ($consulta) use ($q) {
                    $consulta->where('codigo', 'like', "%{$q}%")
                        ->orWhere('nombre', 'like', "%{$q}%");
                })
                ->orderBy('nombre')
                ->limit(15)
                ->get()
                ->map(function (Producto $producto) {
                    $producto->stock_disponible = DB::selectOne(
                        'SELECT fn_stock_disponible(?) AS stock',
                        [$producto->id_producto]
                    )->stock;

                    return $producto;
                });
        }

        return view('punto-venta.index', [
            'turno' => $turno,
            'q' => $q,
            'resultados' => $resultados,
            'carrito' => $this->carritoConDetalle($request),
            'metodosPago' => MetodoPago::where('estado', 'activo')->orderBy('nombre')->get(),
        ]);
    }

    public function abrirTurno(Request $request): RedirectResponse
    {
        $datos = $request->validate([
            'monto_inicial' => ['required', 'numeric', 'min:0'],
        ]);

        if ($this->turnoAbierto($request)) {
            return back()->withErrors(['turno' => 'Ya hay un turno abierto para este usuario.']);
        }

        $bodega = Bodega::where('tipo', 'sala_venta')->where('estado', 'activa')->firstOrFail();

        $turno = TurnoCaja::create([
            'id_usuario' => $request->user()->id_usuario,
            'id_bodega' => $bodega->id_bodega,
            'fecha_apertura' => now(),
            'monto_inicial' => $datos['monto_inicial'],
            'estado' => 'abierto',
        ]);

        $request->session()->put('turno_pos', $turno->id_turno);

        return redirect()->route('punto-venta.index');
    }

    public function cerrarTurno(Request $request): RedirectResponse
    {
        $datos = $request->validate([
            'monto_declarado' => ['required', 'numeric', 'min:0'],
        ]);

        $turno = $this->turnoAbierto($request);

        if (! $turno) {
            return back()->withErrors(['turno' => 'No hay un turno abierto.']);
        }

        $montoSistema = (float) $turno->monto_inicial + (float) Venta::where('id_turno', $turno->id_turno)
            ->where('estado', 'completada')
            ->sum('total');

        $turno->update([
            'fecha_cierre' => now(),
            'monto_declarado' => $datos['monto_declarado'],
            'monto_sistema' => $montoSistema,
            'estado' => 'cerrado',
        ]);

        $request->session()->forget(self::CLAVE_CARRITO);
        $request->session()->forget('turno_pos');

        return redirect()->route('punto-venta.index');
    }

    public function agregarAlCarrito(Request $request): RedirectResponse
    {
        $datos = $request->validate([
            'id_producto' => ['required', 'integer', 'exists:producto,id_producto'],
            'cantidad' => ['required', 'numeric', 'min:0.001'],
        ]);

        $carrito = $request->session()->get(self::CLAVE_CARRITO, []);
        $idProducto = (int) $datos['id_producto'];

        $carrito[$idProducto] = ($carrito[$idProducto] ?? 0) + (float) $datos['cantidad'];

        $request->session()->put(self::CLAVE_CARRITO, $carrito);

        return back();
    }

    public function quitarDelCarrito(Request $request, int $idProducto): RedirectResponse
    {
        $carrito = $request->session()->get(self::CLAVE_CARRITO, []);
        unset($carrito[$idProducto]);
        $request->session()->put(self::CLAVE_CARRITO, $carrito);

        return back();
    }

    public function confirmarVenta(Request $request, VentaService $ventas): RedirectResponse
    {
        $datos = $request->validate([
            'id_metodo_pago' => ['required', 'integer', 'exists:metodo_pago,id_metodo_pago'],
            'nit_receptor' => ['nullable', 'string', 'max:15'],
            'nombre_receptor' => ['nullable', 'string', 'max:150'],
        ]);

        $turno = $this->turnoAbierto($request);
        $carrito = $request->session()->get(self::CLAVE_CARRITO, []);

        if (! $turno) {
            return back()->withErrors(['turno' => 'No hay un turno abierto.']);
        }

        if ($carrito === []) {
            return back()->withErrors(['carrito' => 'El carrito esta vacio.']);
        }

        $items = collect($carrito)
            ->map(fn ($cantidad, $idProducto) => ['id_producto' => (int) $idProducto, 'cantidad' => $cantidad])
            ->values()
            ->all();

        try {
            $resultado = $ventas->registrarVenta([
                'id_usuario' => $request->user()->id_usuario,
                'id_cliente' => null, // la venta a consumidor final no exige cliente registrado
                'id_turno' => $turno->id_turno,
                'id_metodo_pago' => $datos['id_metodo_pago'],
                'canal' => 'presencial',
                'nit_receptor' => $datos['nit_receptor'] ?? null,
                'nombre_receptor' => $datos['nombre_receptor'] ?? null,
                'items' => $items,
            ]);
        } catch (ExcepcionNegocio $e) {
            return back()->withErrors(['venta' => $e->getMessage()]);
        }

        $request->session()->forget(self::CLAVE_CARRITO);

        return redirect()->route('punto-venta.comprobante', $resultado['id_venta']);
    }

    public function comprobante(Venta $venta): View
    {
        $venta->load(['detallesVenta.producto', 'metodoPago', 'documentosFel', 'usuario']);

        return view('punto-venta.comprobante', ['venta' => $venta]);
    }

    public function anular(Request $request, Venta $venta, VentaService $ventas): RedirectResponse
    {
        $datos = $request->validate([
            'motivo' => ['required', 'string', 'max:255'],
        ]);

        try {
            $ventas->anularVenta($venta->id_venta, $request->user()->id_usuario, $datos['motivo']);
        } catch (ExcepcionNegocio $e) {
            return back()->withErrors(['anulacion' => $e->getMessage()]);
        }

        return redirect()->route('punto-venta.comprobante', $venta->id_venta);
    }

    private function turnoAbierto(Request $request): ?TurnoCaja
    {
        return TurnoCaja::where('id_usuario', $request->user()->id_usuario)
            ->where('estado', 'abierto')
            ->latest('id_turno')
            ->first();
    }

    private function carritoConDetalle(Request $request)
    {
        $carrito = $request->session()->get(self::CLAVE_CARRITO, []);

        if ($carrito === []) {
            return collect();
        }

        return Producto::whereIn('id_producto', array_keys($carrito))
            ->get()
            ->map(function (Producto $producto) use ($carrito) {
                $producto->cantidad_carrito = $carrito[$producto->id_producto];
                $producto->subtotal_carrito = round($producto->cantidad_carrito * (float) $producto->precio_venta, 2);

                return $producto;
            });
    }
}
