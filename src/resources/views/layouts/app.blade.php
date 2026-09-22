<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('titulo', config('app.name'))</title>

    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-screen bg-gray-50 text-gray-900 antialiased">
    <div class="min-h-screen flex flex-col">
        <header class="bg-white shadow">
            <div class="mx-auto max-w-7xl px-4 py-4 sm:px-6 lg:px-8">
                <h1 class="text-lg font-semibold text-gray-800">{{ config('app.name') }}</h1>
            </div>
        </header>

        <main class="flex-1">
            <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
                @yield('contenido')
            </div>
        </main>

        <footer class="bg-white">
            <div class="mx-auto max-w-7xl px-4 py-4 text-center text-sm text-gray-500 sm:px-6 lg:px-8">
                Artesanal Chocolate Diego &copy; {{ date('Y') }}
            </div>
        </footer>
    </div>
</body>
</html>
