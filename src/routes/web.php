<?php

use App\Http\Controllers\Auth\SesionController;
use App\Http\Controllers\PanelController;
use App\Http\Controllers\PuntoVentaController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "web" middleware group. Make something great!
|
*/

Route::get('/', function () {
    return view('welcome');
});

Route::middleware('guest')->group(function () {
    Route::get('/ingreso', [SesionController::class, 'mostrarFormulario'])->name('ingreso');
    Route::post('/ingreso', [SesionController::class, 'iniciarSesion'])->name('ingreso.intentar');
});

Route::middleware('auth')->group(function () {
    Route::post('/salir', [SesionController::class, 'cerrarSesion'])->name('salir');
    Route::get('/panel', [PanelController::class, 'index'])->name('panel');
});

Route::middleware(['auth', 'permiso:ventas.registrar'])->prefix('punto-venta')->name('punto-venta.')->group(function () {
    Route::get('/', [PuntoVentaController::class, 'index'])->name('index');
    Route::post('/turno/abrir', [PuntoVentaController::class, 'abrirTurno'])->name('turno.abrir');
    Route::post('/turno/cerrar', [PuntoVentaController::class, 'cerrarTurno'])->name('turno.cerrar');
    Route::post('/carrito', [PuntoVentaController::class, 'agregarAlCarrito'])->name('carrito.agregar');
    Route::delete('/carrito/{idProducto}', [PuntoVentaController::class, 'quitarDelCarrito'])->name('carrito.quitar');
    Route::post('/confirmar', [PuntoVentaController::class, 'confirmarVenta'])->name('confirmar');
    Route::get('/comprobante/{venta}', [PuntoVentaController::class, 'comprobante'])->name('comprobante');

    Route::post('/{venta}/anular', [PuntoVentaController::class, 'anular'])
        ->name('anular')
        ->middleware('permiso:ventas.anular');
});
