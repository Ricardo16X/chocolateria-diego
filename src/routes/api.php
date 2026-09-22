<?php

use App\Http\Controllers\SaludController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "api" middleware group. Make something great!
|
*/

Route::middleware('auth:sanctum')->get('/user', function (Request $request) {
    return $request->user();
});

// Una ruta de un dominio nunca va bajo el prefijo de otro (ver CLAUDE.md).
// Por ahora cada grupo solo trae su ruta de salud; las fases siguientes
// agregan aqui las rutas propias de cada microservicio.
//
// /salud se excluye de StartSession (no aplica en el grupo "api" por
// defecto, se deja explicito por claridad) y de ThrottleRequests: el
// limitador de "api" guarda sus contadores en el mismo store de cache que
// SaludController diagnostica, asi que con Redis caido la peticion nunca
// llegaba al controlador y Laravel devolvia una pagina de error sin JSON
// en vez del 503 que pide la Fase 2.
$sinMiddlewareDeInfraestructura = [
    \Illuminate\Session\Middleware\StartSession::class,
    \Illuminate\Routing\Middleware\ThrottleRequests::class . ':api',
];

Route::prefix('auth')->withoutMiddleware($sinMiddlewareDeInfraestructura)->group(function () {
    Route::get('salud', SaludController::class);
});

Route::prefix('catalogo')->withoutMiddleware($sinMiddlewareDeInfraestructura)->group(function () {
    Route::get('salud', SaludController::class);
});

Route::prefix('pedidos')->withoutMiddleware($sinMiddlewareDeInfraestructura)->group(function () {
    Route::get('salud', SaludController::class);
});

Route::prefix('pagos')->withoutMiddleware($sinMiddlewareDeInfraestructura)->group(function () {
    Route::get('salud', SaludController::class);
});
