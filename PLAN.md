# Plan de ejecución — Aplicación Laravel

Artesanal Chocolate Diego · Grupo 8 · Seminario de Tecnologías de Información

Este documento se ejecuta con Claude Code, una fase por sesión. Cada fase trae
el objetivo, el trabajo concreto y un criterio de aceptación verificable. **No
avanzar a la siguiente fase sin que la anterior pase su criterio.**

Antes de empezar, leer `CLAUDE.md`, que contiene las reglas que aplican a todo
el proyecto.

## Plan cerrado (2026-09-21)

Las 8 fases quedaron cerradas y verificadas (detalle de cada una abajo).
No queda ninguna fase pendiente en este documento. Lo que sigue no es
parte de PLAN.md:

### Preparación para GitHub / Windows (2026-09-21, post-plan)

Otra integrante (Estefanía) va a crear el repositorio en GitHub y subir el
proyecto desde Windows. Se hicieron tres ajustes para que lo pueda montar
sin depender de Linux ni de herramientas que no tiene instaladas:

- **`make activos`** (Makefile nuevo): compila Tailwind/Vite con un
  contenedor de Node descartable, igual que `make instalar-laravel` usa uno
  de Composer — no hace falta Node en el equipo. Hacía falta: el CSS
  compilado en el repo era de la Fase 1, previo a las vistas de
  login/panel/punto-venta de las Fases 4 y 5, así que sus clases de
  Tailwind nunca se habían compilado — se habría visto sin estilos.
  Documentado en el README (`## Requisitos` y `## Puesta en marcha`).
- **`.gitattributes`** (nuevo, raíz del repo): fija `eol=lf` para
  `.sh`/`.sql`/`.yml`/Dockerfile/Makefile. Sin esto, un `git checkout` en
  Windows con `core.autocrlf=true` convierte esos archivos a CRLF, y
  `entrypoint.sh` (el `ENTRYPOINT` de la imagen base) falla con
  `bad interpreter: ...^M` dentro del contenedor Linux.
- **`src/.env` se filtraba en el `.tar.gz`/`.zip`**: las exclusiones de
  todas las corridas anteriores solo cubrían `.env` (raíz), no
  `src/.env` (el de Laravel, con el `APP_KEY` real de esta máquina).
  Corregido en ambos archivos exportados; ver
  [[project-estructura-repo]] en la memoria para la exclusión correcta si
  se regeneran a mano en el futuro.

`chocolate-diego-windows.zip`, junto a `chocolate-diego-devops1.tar.gz`, en
la raíz de "Proyecto DOCKER Tarea Canvas". Mismo contenido; el `.zip`
incluye además `src/public/build/` ya compilado, para que la aplicación se
vea bien desde la primera vez que se levante, sin correr `make activos`
de entrada (aunque conviene correrlo igual si se edita algo).

- **Contratar el certificador FEL-SAT real** y reemplazar el binding de
  `AppServiceProvider::register()` (hoy apunta a `CertificadorSimulado`)
  por la implementación real de `App\Contracts\CertificadorFel`.
- **Completar `docs/devops1/documento-devops1.md`**: la tabla de
  integrantes quedó con el porcentaje de participación pendiente a
  propósito (ver Fase 8), y falta generar el `.docx` de esa entrega —
  deliberadamente no incluido aquí, "para no gastar esfuerzo en formato
  sobre un texto que aún va a cambiar" (ver el propio texto de la Fase 8).
- **Inicializar el repositorio git real** (`git init`, commits siguiendo
  la convención de `CLAUDE.md`) cuando el grupo lo decida — esta carpeta
  no es todavía un repositorio git.
- Aprovisionar los servicios de Azure descritos en la Fase 8 (App
  Service, Database for MySQL Flexible Server, Blob Storage) cuando
  corresponda desplegar de verdad.

Para retomar cualquiera de estos pendientes, o para volver a ejecutar el
sistema completo, los contenedores están arriba; si se retoma otro día y
aparecen detenidos, para levantar de nuevo en esta máquina (Podman
rootless, Fedora):

```bash
docker compose -f docker-compose.yml -f docker-compose.override.yml \
  -f docker-compose.podman-local.yml up -d
```

`docker-compose.podman-local.yml` es exclusivo de esta máquina (gitignored,
no viene en el `.tar.gz`); en Docker Engine real basta `make arriba`.

El usuario `admin` / `Chocolate2026` funciona para pruebas manuales del
login en `http://localhost:8080/ingreso`. Si se corrió la prueba de bloqueo
de cuenta y quedó bloqueado, `make limpiar` lo restaura (o
`UPDATE usuario SET estado='activo', intentos_fallidos=0 WHERE nombre_usuario='admin'`).
Hay productos y documentos FEL de prueba (algunos deliberadamente
`rechazado`, de probar el camino de fallo de la Fase 6) en la base; no
afectan nada, `make limpiar` empieza limpio si se prefiere. Si se prueba el
camino de rechazo FEL a mano, recordar volver `FEL_SIMULACION_MODO=exito`
en `src/.env` (o no tocarlo: ya queda así).

## Estado actual

Lo que ya está hecho y no debe rehacerse:

| Entregado | Dónde |
|---|---|
| Estructura del repositorio, `.gitignore`, `.dockerignore` | raíz |
| Imagen base común PHP 8.1 FPM, multietapa | `docker/base/Dockerfile` |
| Cuatro microservicios de dominio | `docker/{auth,catalogo,pedidos,pagos}/Dockerfile` |
| Puerta de enlace con enrutamiento por prefijo | `docker/gateway/` |
| Orquestación de nueve servicios | `docker-compose.yml` |
| Ajustes de desarrollo | `docker-compose.override.yml` |
| Esquema de 32 tablas | `docker/mysql/init/01_esquema.sql` |
| 5 funciones, 3 disparadores, 5 procedimientos, 10 vistas | `docker/mysql/init/02_rutinas.sql` |
| Catálogos base y usuario administrador | `docker/mysql/init/03_datos_iniciales.sql` |
| Verificación de trazabilidad | `scripts/verificar-esquema.sh` |
| Generación de evidencias | `scripts/evidencias.sh` |
| 18 pruebas de humo con resultados JUnit | `tests/humo/pruebas-humo.sh` |
| Casos para Azure Test Plans | `tests/casos/casos-de-prueba-azure.csv` |
| Integración continua | `.github/workflows/ci.yml`, `azure-pipelines.yml` |
| Tareas frecuentes | `Makefile` |
| IVA dinámico: `sp_registrar_venta` lee `parametro_sistema.fel.tasa_iva` en cada venta, ya no queda fijo en el procedimiento | `docker/mysql/init/02_rutinas.sql`, `03_datos_iniciales.sql` |
| Códigos de error de dominio en los 25 `SIGNAL SQLSTATE '45000'` (prefijo `MODULO_MOTIVO:` antes del mensaje en español) | `docker/mysql/init/02_rutinas.sql` |
| **Fase 1 — Laravel 10 instalado y configurado**, ver detalle abajo | `src/`, `docker-compose*.yml` |
| **Fase 2 — Rutas de salud de los cuatro microservicios**, ver detalle abajo | `src/app/Http/Controllers/SaludController.php`, `src/routes/api.php`, `src/config/chdiego.php` |
| **Fase 3 — 32 modelos Eloquent y comando de trazabilidad**, ver detalle abajo | `src/app/Models/`, `src/app/Console/Commands/ChdiegoTrazabilidad.php`, `docs/devops1/trazabilidad.md` |
| **Fase 4 — Autenticación, bloqueo de cuenta y permisos**, ver detalle abajo | `src/app/Auth/UsuarioProvider.php`, `src/app/Listeners/Auth/`, `src/app/Http/Middleware/VerificarPermiso.php`, `src/resources/views/auth/`, `src/resources/views/panel.blade.php` |
| **Fase 5 — Punto de venta**, ver detalle abajo | `src/app/Services/VentaService.php`, `src/app/Services/InventarioService.php`, `src/app/Exceptions/ExcepcionNegocio.php`, `src/app/Http/Controllers/PuntoVentaController.php`, `src/resources/views/punto-venta/` |
| **Fase 6 — Cola FEL y tareas programadas**, ver detalle abajo | `src/app/Jobs/`, `src/app/Contracts/CertificadorFel.php`, `src/app/Fel/CertificadorSimulado.php`, `src/app/Support/AlertaInterna.php`, `src/app/Console/Commands/{Alertar*,ExpirarReservas,RecordarSuscripciones}.php` |
| **Fase 7 — Diagrama de contenedores**, ver detalle abajo | `docs/arquitectura/diagrama-contenedores.{puml,png,svg}` |
| **Fase 8 — Documento de la entrega DEVOPS 1**, ver detalle abajo | `docs/devops1/documento-devops1.md`, `docs/devops1/evidencias/` |

Lo que falta es el resto de la aplicación que corre dentro de esos
contenedores (fases 2 a 6), el diagrama de arquitectura y el documento de la
entrega.

### Fase 1 completada (2026-09-21)

Ejecutada y verificada de punta a punta contra los contenedores reales
(`make construir`, `make arriba`, `make verificar`, `docker compose exec`).
Ningún criterio de aceptación se declaró cumplido sin correr el comando real.

- Laravel 10.50.3 instalado en `src/` vía `make instalar-laravel`.
- `config/database.php`: conexión mysql con `strict=true`, `engine=InnoDB`,
  `charset=utf8mb4`, `collation=utf8mb4_0900_ai_ci`.
- `config/app.php`: `timezone` y `locale` leen `APP_TIMEZONE`/`APP_LOCALE` de
  `.env` (`America/Guatemala` / `es` por defecto).
- Redis como driver de sesión, caché y cola (`src/.env`); el worker de colas
  ya escucha `fel,correo,default` (definido en `docker-compose.yml`).
- Sanctum publicado; único conjunto de migraciones permitido:
  `password_reset_tokens`, `failed_jobs`, `personal_access_tokens`,
  `job_batches`. `create_users_table` eliminada. `php artisan migrate`
  corrido sin tocar el modelo de negocio — `make verificar` sigue en 32
  tablas, 274 columnas, 56 FK, 28 CHECK, 5/3/5/10 rutinas.
- Tailwind CSS 3 + Vite configurados; `npm run build` compila
  `resources/css/app.css` sin errores. `resources/views/layouts/app.blade.php`
  creado en español.
- `composer.json` fija `config.platform.php` a `8.1.34`: `composer
  create-project` había resuelto dependencias (Collision, PHPUnit, Ignition)
  que exigen PHP ≥8.2, incompatibles con la imagen base (PHP 8.1 fijo por
  `CLAUDE.md`). Cualquier `composer update` futuro debe mantener esa fijación
  o repetirá el mismo choque de versiones.

**Ajustes de infraestructura de esta máquina de desarrollo** (Podman rootless
+ SELinux en Fedora, en vez de Docker Engine real):

- `docker-compose.yml`: los bind mounts de `docker/mysql/init` y
  `docker/mysql/conf.d` llevan `:Z` (SELinux, montaje exclusivo de un solo
  contenedor).
- `docker-compose.override.yml`: el bind mount de `./src` lleva `:z`
  (minúscula — SELinux compartido) porque seis contenedores lo montan a la
  vez; con `:Z` solo el último contenedor en arrancar conservaba acceso y el
  resto fallaba con "Permission denied" / "Could not open input file: artisan".
- `docker-compose.podman-local.yml` (nuevo, gitignored, nunca se versiona):
  fija `userns_mode: keep-id` en los seis servicios que montan `./src`, para
  que el UID 1000 del host coincida con el usuario `laravel` del contenedor.
  Sin esto, Podman remapea UIDs y el contenedor no puede escribir en
  `bootstrap/cache` ni leer el código montado.
- `docker-compose.yml`: el healthcheck de `gateway` usa `http://127.0.0.1/estado`
  en vez de `http://localhost/estado` — este es un fix portable (no específico
  de Podman), porque `wget` dentro del contenedor Alpine intentaba primero
  `::1` y fallaba con "Connection refused" aunque el servicio respondía bien
  por IPv4.
- Quien repita este entorno en Docker Engine real no necesita
  `docker-compose.podman-local.yml`; los otros tres ajustes son inofensivos
  ahí también.

**Riesgo de Fase 2 resuelto (2026-09-21):** `docker/gateway/gateway.conf` fijaba
`resolver 127.0.0.11 valid=5s ipv6=off;` en duro, la dirección del DNS embebido
de Docker. Bajo Podman rootless (esta máquina) el DNS vive en `10.89.0.1`, así
que toda petición a través del `gateway` devolvía 502 aunque los
microservicios respondieran bien directamente. Se resolvió sin tocar el
comportamiento en Docker real:

- `docker/gateway/gateway.conf` → `docker/gateway/gateway.conf.template`, con
  `resolver ${RESOLVER_ADDR} valid=5s ipv6=off;`. La plantilla vive en
  `/etc/nginx/templates/` y el propio entrypoint de la imagen oficial de nginx
  la procesa con `envsubst` al arrancar.
- `docker/gateway/Dockerfile` fija `ENV RESOLVER_ADDR=127.0.0.11` (el valor
  correcto para Docker Engine, el motor que pide el README) y
  `ENV NGINX_ENVSUBST_FILTER=^RESOLVER_ADDR$`, para que `envsubst` sustituya
  únicamente esa variable y no toque `$microservicio`, `$request_uri` ni el
  resto de variables propias de nginx.
- `docker-compose.podman-local.yml` (gitignored) sobreescribe
  `RESOLVER_ADDR: "10.89.0.1"` solo para el servicio `gateway`, solo en esta
  máquina.

Verificado con los cuatro servicios: antes del fix, `curl` a
`/api/<servicio>/salud` a través del gateway devolvía 502 (nginx no podía
resolver el nombre del contenedor). Después del fix devuelve 404 — nginx
resuelve y conecta correctamente con Laravel; el 404 era porque las rutas
`/salud` de la Fase 2 todavía no existían. La cabecera `X-Servicio` también se
confirmó correcta por servicio.

### Fase 2 completada (2026-09-21)

Verificada con el criterio de aceptación exacto de PLAN.md: los cuatro
`curl http://localhost:8080/api/<servicio>/salud` devuelven su propio
nombre, y `make probar` da 18/18.

- `src/config/chdiego.php`: mapa `tablas_dominio` (las mismas tablas por
  módulo que declara este archivo, arriba) — lo reutiliza `SaludController`
  y lo reutilizará el comando `chdiego:trazabilidad` de la Fase 3.
- `src/app/Http/Controllers/SaludController.php`: un solo controlador
  invocable para los cuatro servicios, distinguido por `env('SERVICIO')`.
  Cada comprobación (`base_datos`, `cache`, `kardex` solo en `catalogo`,
  `cola` solo en `pagos`) va en su propio `try/catch`; responde 200 si todo
  pasa, 503 si algo falla, siempre en JSON.
- `src/routes/api.php`: cuatro grupos con prefijo `auth`, `catalogo`,
  `pedidos`, `pagos`, cada uno con su `GET salud`. Las fases siguientes
  agregan aquí las rutas de negocio de cada dominio.

**Bug real encontrado y corregido durante la verificación**: con Redis
caído, la petición nunca llegaba al controlador — `ThrottleRequests`
(middleware `throttle:api`, aplicado por defecto a todo el grupo `api`)
usa el mismo store de caché para contar peticiones, así que al intentar
leer el contador también lanzaba `RedisException`, **antes** de que
`SaludController` pudiera atraparla. El resultado era una página de error
HTML de Laravel con código 500, no el `503` en JSON que pide la Fase 2. Se
corrigió excluyendo `ThrottleRequests` (además de `StartSession`, que no
aplicaba pero se deja explícito) de las cuatro rutas `/salud` con
`->withoutMiddleware(...)`. Verificado deteniendo `chdiego_cache` y
`chdiego_db` por separado con el stack corriendo: ambos casos ahora
devuelven `503` con el mensaje de error real en el campo correspondiente,
y se recuperan a `200` al reiniciar el contenedor. Una ruta de salud no
puede depender de la infraestructura que está diagnosticando para
responder — cualquier ruta de salud futura (si se agregara alguna) debe
excluirse del throttling de la misma manera.

### Fase 3 completada (2026-09-21)

Verificada con el criterio exacto de PLAN.md: los nueve módulos responden
sin error de mapeo (`Rol::count()`, `Producto::count()`, etc.) y
`chdiego:trazabilidad` genera el archivo. `make verificar` y `make probar`
siguen en verde (32 tablas, 18/18 pruebas) — los modelos no tocaron el
esquema de negocio.

- Los 32 modelos (`src/app/Models/<Módulo>/`) se generaron con un script de
  introspección (no a mano): consulta `information_schema.columns` y
  `information_schema.key_column_usage` de la base ya cargada, y a partir de
  ahí arma `$table`, `$primaryKey`, `$fillable` (excluyendo las 7 columnas
  generadas — `venta.total`, `pedido.total`, los dos `subtotal_linea`,
  `lote_clave`, `predeterminada_clave`, `factura_clave`, confirmado contra
  `information_schema.columns.generation_expression`), `$casts` (fechas,
  decimales, booleanos — solo `tinyint(1)` cuenta como booleano; los demás
  `tinyint unsigned` son ids/contadores) y las relaciones `belongsTo`/
  `hasMany` de las 56 FK. El script no forma parte del repositorio, es
  una herramienta de una sola vez.
- `Usuario` extiende `Authenticatable` (no `Model`), usa `HasApiTokens` de
  Sanctum, sobreescribe `getAuthPassword()` para apuntar a
  `contrasena_hash`, y oculta esa columna con `$hidden`. Verificado con
  `$usuario->tokens()`, `$usuario->rol`, `getAuthPassword()` y que
  `contrasena_hash` no aparece al serializar.
- `rol_permiso` tiene clave compuesta (`id_rol`, `id_permiso`), que Eloquent
  no soporta de forma nativa: el modelo `RolPermiso` documenta la
  limitación en un comentario; la navegación real de la relación N:M es
  `Rol::permisos()` / `Permiso::roles()` (`belongsToMany` con
  `withPivot('fecha_asignacion')`), no el modelo `RolPermiso` directamente.
- `src/config/chdiego.php` (creado en la Fase 2) sirve de referencia para
  el mapa de tablas por módulo, pero el comando de trazabilidad no lo lee:
  recorre `app/Models/` con reflexión, así que un modelo nuevo aparece en
  `trazabilidad.md` sin tocar configuración aparte.

**Ajuste de infraestructura para que el comando pudiera escribir en el
repositorio real** (no solo dentro del contenedor): `docker-compose.override.yml`
monta `./docs:/var/www/docs_repositorio:z`, agregado al ancla
`codigo-montado` que ya comparten `auth`, `catalogo`, `pedidos`, `pagos`,
`queue` y `scheduler`. Es un ajuste de desarrollo (no existe en producción);
el comando lo detecta con `is_dir()` y termina con un mensaje claro en vez
de fallar si no está montado.

### Fase 4 completada (2026-09-21)

Verificada con el criterio exacto de PLAN.md: login correcto con `admin` y
`bitacora` con `inicio_sesion` e `intento_fallido`. Probado además, más allá
del criterio mínimo: 5 intentos fallidos bloquean la cuenta
(`seguridad.intentos_maximos` de `parametro_sistema`), un intento con
contraseña correcta sobre una cuenta ya bloqueada se rechaza sin seguir
incrementando el contador, un usuario inexistente también queda en
`bitacora` (con `usuario_intento`, `id_usuario` en `NULL`), y `cierre_sesion`
se registra al salir.

- `App\Auth\UsuarioProvider` (extiende `EloquentUserProvider`): busca por
  `nombre_usuario` o `correo`, y niega el acceso si `estado = 'bloqueado'`
  antes de comparar la contraseña. Registrado como driver `chdiego` en
  `AuthServiceProvider::boot()`; `config/auth.php` lo usa en el provider
  `users` (guards `web` y `sanctum` comparten ese provider, apuntando a
  `App\Models\Seguridad\Usuario`).
- El incremento de `intentos_fallidos`, el bloqueo al llegar al máximo, el
  reinicio del contador, `ultimo_acceso` y la bitácora **no** viven en el
  provider: son listeners de los eventos `Login`/`Failed`/`Logout` de
  Laravel (`app/Listeners/Auth/`), que es donde corresponden esos efectos
  secundarios, no en la lógica de validar credenciales.
- Middleware `permiso:<modulo>.<accion>` (`App\Http\Middleware\VerificarPermiso`,
  alias `permiso` en el Kernel): usa `Permiso::roles()` (`belongsToMany`,
  Fase 3) para el rol del usuario autenticado. 401 sin sesión, 403 sin el
  permiso.
- Vistas Blade `auth/login` y `panel`, en español, sobre el layout de la
  Fase 1. Rutas `GET/POST /ingreso`, `POST /salir`, `GET /panel` en
  `routes/web.php`.
- Se eliminaron `app/Models/User.php` y `database/factories/UserFactory.php`
  (el esqueleto de Laravel), reemplazados por `Usuario` (Fase 3) en todo el
  sistema de autenticación.

**Tres bugs reales encontrados y corregidos, ninguno introducido por esta
fase — ya estaban en la infraestructura "ya construida" o en Fase 1/3, y
Fase 4 fue la primera en ejercitarlos de punta a punta:**

1. **El hash de la contraseña del admin en `03_datos_iniciales.sql` no
   correspondía a "Chocolate2026"** pese a que el comentario del archivo lo
   afirmaba (`password_verify()` daba `false`). Se regeneró el hash real
   dentro del contenedor (`password_hash('Chocolate2026', PASSWORD_BCRYPT)`)
   y se reemplazó en el script. Verificado con `make limpiar` + `make arriba`
   (carga fresca del volumen) que el login funciona con la contraseña
   documentada.
2. **`.env` (raíz) volvía a pisar `src/.env`**, esta vez de forma grave: el
   `env_file: .env` de `docker-compose.yml` inyecta variables de entorno
   reales en el contenedor, y `phpdotenv` nunca sobreescribe una variable
   que el proceso ya trae puesta. Como `.env.example` (raíz) traía
   `APP_KEY=` vacío junto a `APP_NAME`, `APP_ENV`, `APP_DEBUG`, `APP_URL`,
   `APP_TIMEZONE`, `APP_LOCALE` —ninguna de las cuales usa
   `docker-compose.yml` para nada, solo `APP_VERSION`—, la aplicación
   arrancaba sin clave de cifrado real y cualquier ruta que tocara sesión o
   sesión cifrada (osea, cualquier vista) tiraba
   `MissingAppKeyException`. Se recortó el bloque "Aplicación" de `.env` y
   `.env.example` (raíz) a solo `APP_VERSION`; toda la configuración de
   Laravel vive exclusivamente en `src/.env`. Mismo patrón que el hallazgo
   de `FEL_INTENTOS_MAXIMOS` de antes de la Fase 1, pero esta vez rompía la
   aplicación en vez de quedar como una ambigüedad silenciosa.
3. **El volumen con nombre `app_public` (`docker-compose.yml`, pensado para
   producción: PHP-FPM lo llena, nginx lo sirve de solo lectura) se monta
   sobre `./src/public` en desarrollo** y congela esa carpeta en lo que
   traiga la imagen, así que Laravel nunca veía
   `public/build/manifest.json` generado por `npm run build` en el host:
   `@vite()` fallaba con `Vite manifest not found`. Se agregó
   `./src/public:/var/www/html/public:z` al ancla `codigo-montado` de
   `docker-compose.override.yml` — el mismo ajuste que `gateway` ya tenía
   para su propio mount de `public/`. Sin este fix, ninguna vista Blade con
   `@vite()` puede renderizar en desarrollo, en ninguna fase futura.

### Fase 5 completada (2026-09-21)

Verificada con el criterio exacto de PLAN.md, de punta a punta vía HTTP (no
solo `tinker`): login → abrir turno → buscar producto → agregar al carrito →
confirmar venta → `kardex: cuadrado` → anular → `kardex: cuadrado` otra vez
y la existencia de vuelta a su valor inicial (20.000 antes y después).
También probado, más allá del mínimo: un 403 real para un usuario sin
`ventas.registrar`, y que vender más de la existencia disponible devuelve el
mensaje de dominio en español (`Existencia insuficiente para completar la
venta.`) sin página de error 500.

- `App\Exceptions\ExcepcionNegocio` + el trait
  `App\Services\TraduceErroresDeProcedimiento` (compartido por
  `VentaService` e `InventarioService`): capturan `QueryException`, y si el
  SQLSTATE es `45000` separan el código del texto por los dos puntos
  (`VENTA_EXISTENCIA_INSUFICIENTE: Existencia insuficiente...` → código +
  mensaje), tal como quedó decidido antes de la Fase 1. Cualquier otro
  `QueryException` (conexión caída, etc.) se relanza sin tocar.
- `VentaService::registrarVenta()` / `anularVenta()` llaman
  `sp_registrar_venta` / `sp_anular_venta` con `DB::statement()` +
  variables de sesión (`@id_venta`, `@id_documento_fel`) para los `OUT`,
  **sin** envolver en `DB::transaction()`: el procedimiento ya abre su
  propia transacción, y un `START TRANSACTION` de Laravel alrededor
  confirmaría de forma implícita cualquier transacción previa antes de
  tiempo. `InventarioService::ajustar()` es el mismo patrón sobre
  `sp_ajustar_inventario`.
- `PuntoVentaController`: el carrito de caja vive en la sesión
  (`carrito_pos`), no en las tablas `carrito`/`detalle_carrito` — esas son
  del módulo `Clientes` (tienda en línea), un carrito distinto. La venta a
  consumidor final no pide cliente (`id_cliente = null`).
  `sp_registrar_venta` no recibe bodega (el `FEFO` recorre toda la
  existencia del producto), así que el punto de venta tampoco la pide; solo
  la usa la apertura de turno (`turno_caja.id_bodega`, fijada a la primera
  bodega `tipo = 'sala_venta'`).
- Rutas bajo `/punto-venta`, protegidas con `permiso:ventas.registrar`
  (grupo) y `permiso:ventas.anular` (anular, además). Vistas Blade en
  español: búsqueda de producto por código o nombre, carrito, confirmación,
  comprobante con botón de anulación.

Sin bugs nuevos: el fix de `app_public` de la Fase 4 (`docker-compose.override.yml`)
ya cubría estas vistas nuevas sin ajuste adicional.

### Fase 6 completada (2026-09-21)

Verificada con los tres comandos exactos del criterio de PLAN.md:
`docker compose logs queue` muestra `CertificarDocumentoFel` y
`EnviarNotificacion` corriendo y terminando; `schedule:list` lista las
cuatro tareas; `documento_fel` agrupado por estado muestra documentos que
pasaron de `pendiente` a `certificado` (3) y, de la prueba deliberada del
camino de rechazo, a `rechazado` (2) — el flujo completo, no solo el
camino feliz, quedó demostrado de punta a punta por la cola real (no solo
con llamadas directas a `handle()`), incluyendo el reencolado con
retroceso creciente y la notificación por correo llegando a Mailpit.

- `App\Jobs\CertificarDocumentoFel` (cola `fel`): idempotente (si el
  documento ya no está `pendiente`, no hace nada — cubre reencolados
  redundantes). Ante fallo, incrementa `intentos` y guarda
  `mensaje_error`; si no llegó a `fel.intentos_maximos`
  (`parametro_sistema`), se reencola a sí mismo con
  `delay(30 * intentos)` en vez de depender del `--tries`/`--backoff` fijo
  del worker — así el máximo configurable en `parametro_sistema` sigue
  siendo la única fuente de verdad, no un valor fijo en la línea de
  comandos. Al llegar al máximo, pasa a `rechazado` y genera una
  notificación.
- `App\Contracts\CertificadorFel` + `App\Fel\CertificadorSimulado`: el
  adaptador de simulación que pide la fase, con el modo (`exito` / `fallo`
  / `aleatorio`) por `FEL_SIMULACION_MODO` en `src/.env` — una decisión del
  entorno de despliegue, no un parámetro de negocio, así que no compite
  con `parametro_sistema`. Cuando exista un certificador real,
  `AppServiceProvider::register()` es el único punto que cambia.
- `App\Jobs\EnviarNotificacion` (cola `correo`): a diferencia de FEL, no
  tiene un máximo propio en `parametro_sistema` — el plan no lo pedía para
  notificaciones — así que usa el `--tries`/`--backoff` del worker y
  `failed()` para marcar `fallida`. Se dispara solo: `NotificacionObserver`
  (registrado en `AppServiceProvider::boot()`) lo encola en el evento
  `created` de cualquier `Notificacion`, sin que cada punto que genera una
  (controlador, Job, tarea programada) tenga que acordarse de despacharlo.
- Cuatro comandos (`chdiego:alertar-vencimientos`, `chdiego:alertar-stock-bajo`,
  `chdiego:expirar-reservas`, `chdiego:recordar-suscripciones`) sobre las
  vistas `vw_lotes_proximos_vencer`, `vw_stock_bajo`, `vw_suscripciones_activas`
  y la tabla `reserva_existencia`, programados en `app/Console/Kernel.php`.
  Cada uno evita duplicar una alerta ya generada el mismo día para el
  mismo lote/producto/suscripción (un `marcador` embebido en `asunto`).
- `App\Support\AlertaInterna::paraPermiso()`: helper compartido por las
  tres alertas internas (vencimientos, stock bajo, DTE rechazado) —
  notifica a cada usuario activo cuyo rol tenga el permiso indicado
  (reutiliza `Rol::permisos()` de la Fase 3/4), no a un correo fijo.

**Dos bugs reales encontrados y corregidos, ninguno introducido por esta
fase — ya estaban en el esquema o son un error de PHP fácil de repetir:**

1. **`notificacion.tipo` no tenía un valor para "DTE rechazado".** El enum
   ya traía `existencia_baja`, `proximo_vencimiento` y
   `recordatorio_suscripcion` —las otras tres alertas de esta misma
   fase—, lo que confirma que fue un olvido y no una exclusión a propósito.
   Se agregó `dte_rechazado` en `01_esquema.sql` (requiere `make limpiar`
   para tomar efecto, como cualquier cambio de esquema).
2. **`notificacion` tiene `CONSTRAINT chk_destinatario CHECK (id_cliente IS
   NOT NULL OR id_usuario IS NOT NULL)`**: no existe una "alerta al
   sistema" sin destinatario en este modelo de datos. El primer intento de
   `dte_rechazado`/`existencia_baja`/`proximo_vencimiento` con ambos en
   `NULL` fallaba con *Check constraint 'chk_destinatario' is violated*.
   Se corrigió con `AlertaInterna::paraPermiso()` en vez de crear la
   notificación sin destinatario.
3. **`public $queue = 'fel';` en un Job es un error fatal de PHP**, no una
   simple advertencia: `Illuminate\Bus\Queueable` (el trait que traen
   todos los Jobs) ya declara esa misma propiedad con un valor por
   defecto distinto, y PHP rechaza la composición de la clase completa en
   cuanto alguien la instancia o el autoloader la toca. Se corrigió
   fijando la cola con `$this->onQueue('fel')` dentro del constructor, el
   patrón que espera Laravel. Vale la pena recordarlo para cualquier Job
   nuevo en las fases que faltan.

### Fase 7 completada (2026-09-21)

Los tres archivos existen en `docs/arquitectura/` y el PNG se abre
correctamente (verificado leyendo el archivo, no solo comprobando que
existe). `docker/gateway/`, los cuatro microservicios con sus tablas
(tomadas de `docs/devops1/trazabilidad.md`, Fase 3), `db`, `cache`,
`queue`, `scheduler`, la red `chdiego_net`, los cuatro volúmenes
nombrados, el único puerto publicado (`gateway`, `:8080`) y, fuera del
límite del sistema, el certificador FEL-SAT y SendGrid (correo en
producción, ver `docker-compose.override.yml`: en desarrollo lo reemplaza
Mailpit).

- `docs/arquitectura/diagrama-contenedores.puml` en PlantUML plano (sin
  `!include` externo — nada que dependa de la red al renderizar), con
  `!pragma layout smetana` para el motor de layout embebido en la imagen
  oficial de PlantUML.
- Renderizado con el contenedor `plantuml/plantuml`:
  `docker run --rm --userns=keep-id -v ".../docs/arquitectura:/data:z" plantuml/plantuml -Sdpi=170 -tpng ...`
  y lo mismo con `-tsvg`. `--userns=keep-id` y `:z` son el mismo ajuste de
  Podman rootless de siempre (ver Fase 1) — nada especial de PlantUML.
- No se generó ningún cambio en `docker/` ni `src/`: esta fase es
  documentación pura, como anticipa PLAN.md ("no depende de la aplicación
  funcionando").

### Fase 8 completada (2026-09-21) — PLAN.md cerrado

El documento existe (`docs/devops1/documento-devops1.md`), cubre los
cuatro puntos del desarrollo, y la tabla de trazabilidad no tiene celdas
vacías (verificado con `grep`, no solo a simple vista). No se generó el
archivo Word, como pide el criterio.

- `make evidencias` se corrió de nuevo antes de escribir el documento,
  para referenciar las 14 evidencias reales (no una lista supuesta):
  incluye la corrida de tolerancia a fallos (detiene `pagos`, confirma que
  `auth`/`catalogo` siguen respondiendo, y que `pagos` se recupera sin
  reiniciar el gateway) y las 18 pruebas de humo en verde.
- **Control de versiones**: el proyecto todavía no es un repositorio git
  (sin historial de commits que describir). Se documentó la estructura de
  carpetas (real) y la convención de commits que ya manda `CLAUDE.md`, y
  la estrategia de ramas `main`/`develop` que **ya estaba** codificada en
  el disparador de `azure-pipelines.yml` desde antes de esta fase — no se
  inventó, se hizo explícita.
- **Trazabilidad**: la tabla usa los nueve módulos como unidad de
  requerimiento (en vez de una lista de requerimientos funcionales sueltos
  no documentados en ninguna entrega anterior), porque son la unidad que
  ya tiene tablas, servicio y evidencia verificable asignados sin
  ambigüedad — así ninguna celda queda vacía ni inventada.
- **Porcentaje de participación**: se dejó pendiente en la portada a
  pedido explícito del usuario, en vez de inventar una cifra para cada
  integrante.

### Decisiones registradas (2026-09-21)

- **Parámetros de negocio, no de despliegue.** La tasa de IVA y los reintentos
  de FEL viven en `parametro_sistema` (`fel.tasa_iva`, `fel.intentos_maximos`),
  no en `.env`. `.env.example` ya no trae `FEL_INTENTOS_MAXIMOS`: esa carpeta es
  solo para credenciales de conexión, nunca fuente de verdad para parámetros
  de negocio, ni siquiera como referencia para el despliegue final.
- **Códigos de error estables.** Cada `SIGNAL SQLSTATE '45000'` empieza con un
  código en mayúsculas (`MODULO_MOTIVO:`) antes del texto en español, por
  ejemplo `VENTA_EXISTENCIA_INSUFICIENTE: Existencia insuficiente para
  completar la venta.`. La Fase 5 debe mapear excepciones de dominio por ese
  código —con `SUBSTRING_INDEX(mensaje, ':', 1)`—, nunca por el texto completo
  del mensaje, que puede reformularse sin avisar.
- **Sin pruebas de humo adicionales para Fase 5.** El criterio de aceptación
  de la fase (el `curl` a `/api/catalogo/salud` verificando `kardex`) es
  suficiente; no se agregan pruebas HTTP extra al conjunto de 18 para no
  sobrecargar la suite.

## Orden de las fases

| Fase | Objetivo | Depende de |
|---|---|---|
| 1 | Instalación y configuración de Laravel 10 | — |
| 2 | Rutas de salud de los cuatro microservicios | 1 |
| 3 | Modelos Eloquent de los nueve módulos | 1 |
| 4 | Autenticación con Sanctum y control de roles | 3 |
| 5 | Punto de venta sobre los procedimientos almacenados | 3, 4 |
| 6 | Cola de facturación FEL y tareas programadas | 5 |
| 7 | Diagrama de contenedores en PlantUML | — |
| 8 | Documento de la entrega DEVOPS 1 | 1 a 7 |

Las fases 7 y 8 no dependen de la aplicación funcionando y pueden adelantarse
si el tiempo aprieta.

---

## Fase 1 — Instalación y configuración de Laravel 10

**Objetivo.** Dejar una aplicación Laravel 10 operando dentro del contenedor,
conectada a MySQL y Redis, sin tocar el esquema de negocio.

**Trabajo.**

1. Crear el proyecto en `src/` con `make instalar-laravel`. Si ya existe
   contenido, detenerse y reportar en lugar de sobrescribir.
2. Configurar `config/database.php`: conexión MySQL con `strict => true`,
   `engine => 'InnoDB'`, `charset => 'utf8mb4'`,
   `collation => 'utf8mb4_0900_ai_ci'`.
3. Fijar en `config/app.php` la zona horaria `America/Guatemala` y la
   configuración regional `es`.
4. Configurar Redis como controlador de sesión, caché y cola. Definir las colas
   `fel`, `correo` y `default`.
5. Instalar Sanctum y publicar su migración. Ejecutar **únicamente** las
   migraciones de infraestructura del framework. Eliminar del directorio de
   migraciones cualquier archivo que cree tablas de negocio, en particular
   `create_users_table`, `create_password_reset_tokens_table` puede quedarse.
6. Instalar Tailwind CSS y configurar Vite.
7. Crear el archivo de estilo `resources/css/app.css` y una plantilla base
   `resources/views/layouts/app.blade.php` en español.

**Criterio de aceptación.**

```bash
docker compose exec catalogo php artisan --version          # Laravel 10.x
docker compose exec catalogo php artisan tinker --execute="echo DB::connection()->getPdo() ? 'db ok' : 'db falla';"
docker compose exec catalogo php artisan tinker --execute="Cache::put('p','v',10); echo Cache::get('p');"
make verificar                                          # sigue en 32 tablas
```

La última línea es la importante: si el conteo de tablas cambió, una migración
tocó el modelo de negocio y hay que revertirla.

---

## Fase 2 — Rutas de salud de los microservicios

**Objetivo.** Que cada microservicio responda por su prefijo y diga en un
vistazo si está sano. Estas rutas las consultan las pruebas de humo y las
evidencias.

**Trabajo.**

1. En `routes/api.php`, cuatro grupos de rutas con prefijo `auth`, `catalogo`,
   `pedidos` y `pagos`. Laravel ya antepone `/api`.
2. En cada grupo, la ruta `GET salud` atendida por un único controlador
   `SaludController`, que devuelve JSON con:
   - `servicio`: el valor de la variable de entorno `SERVICIO`
   - `base_datos`: `ok` o el error, más el conteo de tablas del dominio
   - `cache`: `ok` o el error
   - `kardex`: solo en `catalogo`, `cuadrado` o la cantidad de registros que
     no cuadran con la suma de movimientos
   - `cola`: solo en `pagos`, trabajos pendientes en la cola `fel`
3. Responde 200 cuando todo está bien y 503 cuando algo falla, sin lanzar
   excepción: cada comprobación va en su propio `try`.
4. Excluir estas rutas del middleware de sesión.

**Criterio de aceptación.**

```bash
for s in auth catalogo pedidos pagos; do
  curl -s http://localhost:8080/api/$s/salud; echo
done
make probar
```

Cada ruta devuelve su propio nombre en `servicio`, y las 18 pruebas de humo
pasan. Si una ruta devuelve el nombre de otro servicio, el enrutamiento de la
puerta de enlace o la variable `SERVICIO` están mal.

---

## Fase 3 — Modelos Eloquent

**Objetivo.** Un modelo por tabla de negocio, mapeado al esquema existente, con
las relaciones derivadas de las 56 llaves foráneas.

**Trabajo.**

Generar 32 modelos en `app/Models/`, agrupados en subcarpetas por módulo:

| Subcarpeta | Tablas |
|---|---|
| `Seguridad` | `rol`, `permiso`, `rol_permiso`, `usuario`, `bitacora` |
| `Catalogo` | `categoria`, `producto`, `historial_precio` |
| `Inventario` | `bodega`, `lote`, `existencia`, `tipo_movimiento`, `movimiento_inventario`, `reserva_existencia` |
| `PuntoVenta` | `venta`, `detalle_venta`, `metodo_pago`, `turno_caja` |
| `Fel` | `documento_fel` |
| `Clientes` | `cliente`, `direccion_entrega`, `pedido`, `detalle_pedido`, `carrito`, `detalle_carrito` |
| `Entregas` | `zona_cobertura`, `transportista`, `envio` |
| `Suscripcion` | `plan_suscripcion`, `suscripcion` |
| `Soporte` | `notificacion`, `parametro_sistema` |

Cada modelo declara `$table`, `$primaryKey`, `$timestamps = false`, `$fillable`
con las columnas escribibles, `$casts` para fechas, decimales y booleanos, y
las relaciones Eloquent. Las columnas generadas quedan fuera de `$fillable`.

El modelo `Usuario` extiende `Authenticatable` y usa `HasApiTokens` de Sanctum,
apuntando a la tabla `usuario` con llave `id_usuario` y contraseña en la
columna `contrasena_hash`.

Crear el comando `php artisan chdiego:trazabilidad`, que recorre los modelos y
genera `docs/devops1/trazabilidad.md` con una tabla de servicio del compose,
módulo, tablas involucradas y modelos correspondientes.

**Criterio de aceptación.**

```bash
docker compose exec catalogo php artisan tinker --execute="
foreach ([
  'Seguridad\\Rol','Catalogo\\Producto','Inventario\\Existencia',
  'PuntoVenta\\Venta','Fel\\DocumentoFel','Clientes\\Cliente',
  'Entregas\\ZonaCobertura','Suscripcion\\PlanSuscripcion','Soporte\\ParametroSistema'
] as \$m) { \$c = 'App\\\\Models\\\\'.\$m; echo \$m.': '.\$c::count().PHP_EOL; }
"
docker compose exec catalogo php artisan chdiego:trazabilidad
```

Los nueve módulos responden sin error de mapeo y el archivo de trazabilidad se
genera.

---

## Fase 4 — Autenticación y control de roles

**Objetivo.** Inicio de sesión funcional con los roles y permisos del esquema.

**Trabajo.**

1. Proveedor de autenticación personalizado que use la tabla `usuario` y la
   columna `contrasena_hash`.
2. Middleware `permiso:<modulo>.<accion>` que consulte `rol_permiso` y responda
   403 cuando el usuario no lo tenga.
3. Bloqueo de cuenta: incrementar `usuario.intentos_fallidos` en cada intento
   fallido y pasar `estado` a `bloqueado` al llegar al valor del parámetro
   `seguridad.intentos_maximos`. Reiniciar el contador en el ingreso correcto y
   actualizar `ultimo_acceso`.
4. Registrar en `bitacora` el inicio de sesión, el intento fallido y el cierre
   de sesión, con la dirección IP.
5. Vistas Blade de ingreso y panel, en español.

**Criterio de aceptación.**

Ingreso correcto con el usuario `admin`, y consulta de la bitácora:

```bash
docker compose exec db mysql -u root -p"$DB_ROOT_PASSWORD" chocolate_diego \
  -e "SELECT evento, direccion_ip, fecha_hora FROM bitacora ORDER BY id_bitacora DESC LIMIT 5;"
```

Aparecen los eventos `inicio_sesion` e `intento_fallido`.

---

## Fase 5 — Punto de venta

**Objetivo.** Registrar y anular ventas a través de los procedimientos
almacenados, no reimplementando su lógica en PHP.

**Trabajo.**

1. Servicio `VentaService` que invoque `sp_registrar_venta` con los parámetros
   de salida, y `sp_anular_venta`. Traducir el `SQLSTATE 45000` de los
   procedimientos a excepciones de dominio a partir del código que antecede
   al mensaje (por ejemplo `VENTA_EXISTENCIA_INSUFICIENTE`), no del texto
   completo: `SUBSTRING_INDEX($mensaje, ':', 1)`. El texto que sigue a los
   dos puntos es para mostrarlo al usuario, no para comparar.
2. Controlador y rutas del punto de venta: apertura y cierre de turno, carrito,
   confirmación de venta, comprobante.
3. La venta a consumidor final no exige cliente registrado.
4. Servicio `InventarioService` sobre `sp_ajustar_inventario` para entradas,
   mermas y ajustes.
5. Vistas Blade del punto de venta, con búsqueda de producto por código o
   nombre.

No duplicar en PHP la validación de existencia ni el descuento de inventario:
eso vive en el procedimiento, dentro de una transacción.

**Criterio de aceptación.**

Registrar una venta de prueba y comprobar que el kardex cuadra:

```bash
curl -s http://localhost:8080/api/catalogo/salud | python3 -c "import sys,json; print(json.load(sys.stdin)['kardex'])"
```

Devuelve `cuadrado`. Después anular esa venta y repetir: debe seguir cuadrado y
la existencia debe volver a su valor inicial.

---

## Fase 6 — Cola FEL y tareas programadas

**Objetivo.** Que la certificación del DTE ocurra fuera del ciclo de la
petición y que las alertas del negocio se ejecuten solas.

**Trabajo.**

1. Job `CertificarDocumentoFel` en la cola `fel`: construye el XML del DTE,
   lo envía al certificador, guarda serie, número, autorización y ruta del XML,
   y pasa el estado a `certificado`. Ante fallo, incrementa `intentos`, guarda
   `mensaje_error` y reintenta con retroceso. Al llegar a
   `fel.intentos_maximos`, marca `rechazado` y genera una notificación.
2. Mientras no haya certificador contratado, un adaptador de simulación
   configurable por variable de entorno, para que el flujo sea demostrable.
3. Job `EnviarNotificacion` en la cola `correo`, que consuma la tabla
   `notificacion`.
4. Tareas programadas en `app/Console/Kernel.php`:
   - diaria: lotes próximos a vencer según `vw_lotes_proximos_vencer`, genera
     notificaciones
   - diaria: existencias bajo mínimo según `vw_stock_bajo`
   - cada quince minutos: expirar `reserva_existencia` vencidas
   - diaria: suscripciones con entrega próxima según `vw_suscripciones_activas`

**Criterio de aceptación.**

```bash
docker compose logs queue --tail=30
docker compose exec catalogo php artisan schedule:list
docker compose exec db mysql -u root -p"$DB_ROOT_PASSWORD" chocolate_diego \
  -e "SELECT estado, COUNT(*) FROM documento_fel GROUP BY estado;"
```

Se ven trabajos procesados, las cuatro tareas listadas y documentos que pasaron
de `pendiente` a `certificado`.

---

## Fase 7 — Diagrama de contenedores

**Objetivo.** Reemplazar la figura 1 del séptimo documento, que menciona React
por error.

**Trabajo.**

Escribir `docs/arquitectura/diagrama-contenedores.puml` mostrando la puerta de
enlace, los cuatro microservicios de dominio con las tablas que atiende cada
uno, los servicios de infraestructura, la red `chdiego_net`, los volúmenes
nombrados, el único puerto publicado, y fuera del límite del sistema los dos
servicios externos: certificador FEL-SAT y SendGrid.

Renderizar a PNG con `-Sdpi=170` y también a SVG.

**Criterio de aceptación.** Los tres archivos existen en
`docs/arquitectura/` y el PNG se abre correctamente.

---

## Fase 8 — Documento de la entrega DEVOPS 1

**Objetivo.** El documento que se entrega, en Markdown, listo para que Carla lo
consolide.

**Trabajo.**

Escribir `docs/devops1/documento-devops1.md` con la estructura de los
documentos anteriores del grupo: portada con los cuatro carnés y el porcentaje
de participación, introducción, objetivo general y específicos, referencia a la
entrega anterior, desarrollo, evidencias, conclusiones.

El desarrollo cubre cuatro puntos:

1. **Control de versiones.** Repositorio, estructura de carpetas, estrategia de
   ramas, convención de commits.
2. **Diseño basado en microservicios.** Los cuatro servicios de dominio y
   las tablas que atiende cada uno, la puerta de enlace y su enrutamiento, los
   servicios de infraestructura, y la justificación de por qué el worker de
   colas va aparte: la certificación FEL no puede bloquear el registro de la
   venta. Incluir el diagrama de la fase 7 y la justificación de MySQL frente
   a PostgreSQL que está en el README.
3. **Cómputo en la nube.** Azure App Service, Azure Database for MySQL Flexible
   Server, Azure Blob Storage y el uso de Azure Boards, Repos, Pipelines y Test
   Plans.
4. **Trazabilidad.** Tabla que relaciona requerimiento, módulo del modelo de
   datos, tablas involucradas, servicio del compose y evidencia que lo respalda.
   Incluir la salida de `scripts/verificar-esquema.sh` con las ocho cifras.

La sección de evidencias referencia los catorce archivos que genera
`scripts/evidencias.sh`.

**No generar el archivo Word.** Se produce aparte cuando el contenido esté
aprobado, para no gastar esfuerzo en formato sobre un texto que aún va a
cambiar.

**Criterio de aceptación.** El documento existe, cubre los cuatro puntos, y la
tabla de trazabilidad no tiene celdas vacías.

---

## Puntos de corte

- Las fases 1, 2 y 3 son independientes del resto del equipo y se pueden
  ejecutar de inmediato.
- La fase 6 depende de que se defina el certificador FEL. Mientras tanto se
  trabaja con el adaptador de simulación.
- Las fases 7 y 8 dependen de que el grupo cierre la decisión Blade frente a
  React. Conviene resolverla esta semana y no el día de la entrega.

## Si algo falla

- `make verificar` devuelve un conteo distinto de 32 tablas: una migración tocó
  el modelo de negocio. Revertirla y ajustar `CLAUDE.md` si hizo falta.
- MySQL no aplica los cambios de `docker/mysql/init/`: esos scripts solo se
  ejecutan al crear el volumen. `make limpiar` lo recrea, y borra los datos.
- Un procedimiento almacenado falla con "Falta el tipo de movimiento": los
  catálogos de `03_datos_iniciales.sql` no se cargaron. Mismo caso anterior.
