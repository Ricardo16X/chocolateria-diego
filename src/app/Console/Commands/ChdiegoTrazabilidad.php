<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use ReflectionClass;
use Symfony\Component\Finder\Finder;

// Recorre app/Models/<Modulo>/ y genera docs/devops1/trazabilidad.md con la
// tabla servicio del compose <-> modulo <-> tablas <-> modelos. No depende
// de una lista escrita a mano: si la Fase 4+ agrega un modelo nuevo, basta
// con correr este comando de nuevo para que la trazabilidad quede al dia.
class ChdiegoTrazabilidad extends Command
{
    protected $signature = 'chdiego:trazabilidad';

    protected $description = 'Genera docs/devops1/trazabilidad.md a partir de los modelos en app/Models';

    // Modulo -> servicio del docker-compose, tal como lo declara CLAUDE.md.
    // "Soporte" (notificacion, parametro_sistema) es transversal: lo consultan
    // los cuatro servicios, no pertenece a uno solo.
    private const SERVICIO_POR_MODULO = [
        'Seguridad' => 'auth',
        'Catalogo' => 'catalogo',
        'Inventario' => 'catalogo',
        'Clientes' => 'pedidos',
        'Entregas' => 'pedidos',
        'Suscripcion' => 'pedidos',
        'PuntoVenta' => 'pagos',
        'Fel' => 'pagos',
        'Soporte' => 'todos (transversal)',
    ];

    public function handle(): int
    {
        $directorioModelos = app_path('Models');
        $filas = [];

        foreach ((new Finder())->directories()->in($directorioModelos)->depth(0)->sortByName() as $carpeta) {
            $modulo = $carpeta->getFilename();
            $servicio = self::SERVICIO_POR_MODULO[$modulo] ?? '(sin mapear)';

            $tablas = [];
            $modelos = [];

            foreach ((new Finder())->files()->in($carpeta->getPathname())->name('*.php')->sortByName() as $archivo) {
                $clase = 'App\\Models\\' . $modulo . '\\' . $archivo->getFilenameWithoutExtension();

                if (! class_exists($clase)) {
                    continue;
                }

                $reflexion = new ReflectionClass($clase);
                if ($reflexion->isAbstract()) {
                    continue;
                }

                $instancia = $reflexion->newInstance();
                $tablas[] = $instancia->getTable();
                $modelos[] = $reflexion->getShortName();
            }

            if ($modelos === []) {
                continue;
            }

            $filas[] = [
                'servicio' => $servicio,
                'modulo' => $modulo,
                'tablas' => implode(', ', $tablas),
                'modelos' => implode(', ', $modelos),
            ];
        }

        usort($filas, fn ($a, $b) => [$a['servicio'], $a['modulo']] <=> [$b['servicio'], $b['modulo']]);

        $contenido = $this->renderizar($filas);

        // docker-compose.override.yml monta ./docs del repositorio (no solo
        // el codigo de la app) en /var/www/docs_repositorio para que este
        // comando pueda escribir alli. Es un ajuste de desarrollo: en
        // produccion ese punto de montaje no existe.
        $directorioDocs = '/var/www/docs_repositorio';

        if (! is_dir($directorioDocs)) {
            $this->warn("No esta montado {$directorioDocs} (ver docker-compose.override.yml). No se genero el archivo.");

            return self::FAILURE;
        }

        $ruta = "{$directorioDocs}/devops1/trazabilidad.md";

        if (! is_dir(dirname($ruta))) {
            mkdir(dirname($ruta), 0755, true);
        }

        file_put_contents($ruta, $contenido);

        $this->info("Trazabilidad generada: {$ruta}");
        $this->info(count($filas) . ' modulos, ' . array_sum(array_map(
            fn ($f) => substr_count($f['modelos'], ',') + 1,
            $filas
        )) . ' modelos.');

        return self::SUCCESS;
    }

    private function renderizar(array $filas): string
    {
        $fecha = now()->format('Y-m-d');
        $lineas = [
            '# Trazabilidad — servicio, módulo, tablas y modelos',
            '',
            "Generado automáticamente por `php artisan chdiego:trazabilidad` el {$fecha}.",
            'No editar a mano: se sobrescribe la próxima vez que se corra el comando.',
            '',
            '| Servicio | Módulo | Tablas | Modelos |',
            '|---|---|---|---|',
        ];

        foreach ($filas as $fila) {
            $lineas[] = "| {$fila['servicio']} | {$fila['modulo']} | {$fila['tablas']} | {$fila['modelos']} |";
        }

        $lineas[] = '';

        return implode("\n", $lineas);
    }
}
