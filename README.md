# Artesanal Chocolate Diego — Plataforma de gestión

Plataforma web en la nube para Artesanal Chocolate Diego, empresa de chocolate
artesanal de San Pedro La Laguna, Sololá. El sistema cubre inventario con
control de lotes y vencimientos, punto de venta, facturación electrónica FEL
ante la SAT, tienda en línea con entregas en cuatro departamentos y caja por
suscripción.

Proyecto académico de la Universidad Mariano Gálvez de Guatemala, Facultad de
Ingeniería en Sistemas de Información, curso Seminario de Tecnologías de
Información, código 1900-047, a cargo del Ing. Erick Roberto Aguilar Juárez.

## Integrantes — Grupo 8

| Carné | Nombre | Rol |
|---|---|---|
| 0900-22-15843 | Carla Estefanía Duque Martínez | Scrum Master |
| 0900-09-13357 | William Natanael Vásquez Navichoc | Product Owner |
| 0900-09-6892 | Julio Alexis León Rodríguez | Desarrollo — Azure DevOps |
| 0900-23-22081 | Ricardo Ismael Pérez Ajanel | Desarrollo — Docker y microservicios |

## Arquitectura de microservicios

El sistema se divide en cuatro microservicios de dominio, cada uno con su
propio Dockerfile y su propio contenedor, y cinco servicios de infraestructura.
Solo la puerta de enlace es accesible desde fuera; los microservicios viven en
una red interna aislada.

### Microservicios de dominio

| Servicio | Responsabilidad | Módulos del modelo de datos | Tablas |
|---|---|---|---|
| `auth` | Identidad, roles, permisos y auditoría | Seguridad | `rol`, `permiso`, `rol_permiso`, `usuario`, `bitacora` |
| `catalogo` | Productos, precios, lotes, existencias y kardex | Catálogo, Inventario | `categoria`, `producto`, `historial_precio`, `bodega`, `lote`, `existencia`, `tipo_movimiento`, `movimiento_inventario`, `reserva_existencia` |
| `pedidos` | Clientes, carrito, envíos y suscripciones | Clientes, Entregas, Suscripción | `cliente`, `direccion_entrega`, `pedido`, `detalle_pedido`, `carrito`, `detalle_carrito`, `zona_cobertura`, `transportista`, `envio`, `plan_suscripcion`, `suscripcion` |
| `pagos` | Punto de venta y facturación electrónica FEL | Punto de venta, FEL | `venta`, `detalle_venta`, `metodo_pago`, `turno_caja`, `documento_fel` |

Las tablas `notificacion` y `parametro_sistema` son transversales y las
consultan todos los servicios.

Cada microservicio ajusta su configuración a su perfil de carga: `catalogo`
tiene más procesos y más caché de código porque recibe las lecturas de la
tienda; `pagos` mantiene sus procesos siempre arrancados para que el punto de
venta nunca espere; `pedidos` admite cuerpos de petición mayores porque recibe
los comprobantes de pago.

### Servicios de infraestructura

| Servicio | Imagen | Responsabilidad |
|---|---|---|
| `gateway` | nginx 1.27 | Único punto de entrada; enruta cada prefijo a su microservicio |
| `db` | MySQL 8.0 | Modelo relacional de 32 tablas |
| `cache` | Redis 7 | Sesiones, caché y cola de trabajos |
| `queue` | imagen de `pagos` | Certificación FEL y correo transaccional |
| `scheduler` | imagen de `catalogo` | Vencimientos de lote, existencias bajo mínimo, suscripciones |

El worker de colas ocupa un contenedor propio porque la certificación del DTE
ante el certificador FEL-SAT no debe bloquear el registro de la venta. Si el
certificador no responde, la venta ya quedó registrada y el documento espera en
`documento_fel` con su contador de intentos.

### Enrutamiento

| Prefijo | Microservicio |
|---|---|
| `/api/auth/` | `auth` |
| `/api/catalogo/` | `catalogo` |
| `/api/pedidos/` | `pedidos` |
| `/api/pagos/` | `pagos` |
| cualquier otra ruta | `catalogo`, como vitrina pública |

Cada respuesta incluye la cabecera `X-Servicio` con el nombre del microservicio
que la atendió.

```
                         Navegador
                             │
                             ▼
                      ┌────────────┐
                      │  gateway   │  :8080
                      └─────┬──────┘
          ┌──────────┬──────┴─────┬──────────┐
          ▼          ▼            ▼          ▼
     ┌────────┐ ┌──────────┐ ┌─────────┐ ┌───────┐
     │  auth  │ │ catalogo │ │ pedidos │ │ pagos │
     └───┬────┘ └────┬─────┘ └────┬────┘ └───┬───┘
         └───────────┴──────┬─────┴──────────┘
                ┌───────────┴───────────┐
                ▼                       ▼
           ┌────────┐              ┌─────────┐
           │   db   │              │  cache  │
           └────────┘              └────┬────┘
                                        │ cola
                              ┌─────────┴─────────┐
                              ▼                   ▼
                         ┌─────────┐       ┌───────────┐
                         │  queue  │       │ scheduler │
                         └────┬────┘       └───────────┘
                              ▼
                     Certificador FEL-SAT
```

### Motor de base de datos

El proyecto utiliza MySQL 8.0 y no PostgreSQL. El modelo relacional, el
diccionario de datos y la implementación entregados en el séptimo y octavo
documento se construyeron y verificaron sobre MySQL, incluidas sus funciones,
disparadores, procedimientos almacenados y vistas. Cambiar de motor en esta
etapa rompería la trazabilidad entre el modelo documentado y la
implementación.

## Requisitos

- Docker Engine 24 o superior (o Docker Desktop en Windows/Mac), con Docker
  Compose v2
- GNU Make, recomendado. En Windows sin WSL, ver "Sin Make" más abajo — los
  mismos pasos funcionan con Docker Desktop sin instalar nada más en el
  equipo, ni PHP, ni Composer, ni Node.

## Puesta en marcha

La aplicación Laravel ya está instalada en `src/` y las ocho fases de
`PLAN.md` están completas: el sistema funciona de punta a punta (login,
punto de venta, facturación FEL, tareas programadas). Para levantarlo:

```bash
git clone <url-del-repositorio> chocolate-diego
cd chocolate-diego

make preparar            # crea .env; cambiar DB_PASSWORD y DB_ROOT_PASSWORD
make activos              # compila CSS/JS (Tailwind/Vite) sin instalar Node
make construir            # imagen base y luego los microservicios
make arriba               # levanta los servicios
make probar               # ejecuta las 18 pruebas de humo
```

`make activos` es obligatorio la primera vez y cada vez que cambie una
vista Blade o un archivo CSS/JS: sin `src/public/build/manifest.json`, las
páginas cargan sin estilos (`@vite()` falla). Usa un contenedor de Node
descartable, igual que `make construir` usa uno de Composer — no hace falta
tener Node instalado en el equipo.

La imagen base debe construirse antes que los microservicios, porque los
cuatro parten de ella. `make construir` lo hace en el orden correcto. Sin Make:

```bash
docker build -f docker/base/Dockerfile -t chocolate-diego/base:dev .
docker run --rm -v "$(pwd)/src:/app" -w /app node:20-alpine sh -c "npm install && npm run build"
docker compose build
docker compose up -d
```

Direcciones:

- Puerta de enlace: http://localhost:8080
- Bandeja de correo de desarrollo: http://localhost:8025
- MySQL desde el equipo: `localhost:3307`
- Ingreso: http://localhost:8080/ingreso — usuario `admin`, contraseña
  `Chocolate2026` (cambiarla en el primer ingreso real; ver
  `docker/mysql/init/03_datos_iniciales.sql`)

## Base de datos

El esquema se carga la primera vez que se crea el volumen de datos. Los scripts
de `docker/mysql/init/` se ejecutan en orden:

| Archivo | Contenido |
|---|---|
| `01_esquema.sql` | 32 tablas, 274 columnas, 56 llaves foráneas, 28 restricciones CHECK |
| `02_rutinas.sql` | 5 funciones, 3 disparadores, 5 procedimientos almacenados, 10 vistas |
| `03_datos_iniciales.sql` | Roles, permisos, tipos de movimiento, métodos de pago, bodegas, zonas de cobertura y parámetros |

Para recargarlos hay que eliminar el volumen con `make limpiar`, operación que
borra los datos.

`make verificar` compara las ocho cifras declaradas en el Octavo Documento de
Proyecto contra lo que existe en MySQL, comprueba los 23 objetos por nombre y
valida que la existencia cuadre con la suma de movimientos del kardex.

## Pruebas

Ver [`tests/README.md`](tests/README.md). Resumen:

- `tests/humo/pruebas-humo.sh`: 18 pruebas automáticas con resultados JUnit
- `tests/casos/casos-de-prueba-azure.csv`: los mismos casos para importar en
  Azure Test Plans
- `azure-pipelines.yml`: pipeline de construcción y pruebas para Azure DevOps
- `.github/workflows/ci.yml`: el mismo flujo en GitHub Actions

## Tareas disponibles

```
make ayuda               Lista las tareas
make preparar            Crea el archivo .env
make instalar-laravel    Crea el proyecto Laravel en src/ (ya está hecho)
make activos             Compila CSS/JS (Tailwind/Vite) sin instalar Node
make construir           Construye la imagen base y los microservicios
make arriba              Levanta los servicios
make abajo               Los detiene conservando los datos
make estado              Estado de los contenedores
make registros           Sigue los registros
make consola             Terminal dentro del microservicio catalogo
make mysql               Cliente de MySQL
make redis               Cliente de Redis
make verificar           Verifica el esquema contra el documento
make probar              Ejecuta las pruebas de humo
make evidencias          Genera las evidencias de DEVOPS 1
make limpiar             Elimina contenedores y volúmenes. Destructivo.
```

## Estructura del repositorio

```
chocolate-diego/
├── .github/workflows/ci.yml       Integración continua en GitHub
├── azure-pipelines.yml            Integración continua en Azure DevOps
├── docker/
│   ├── base/                      Imagen base común de los microservicios
│   ├── auth/                      Microservicio de identidad
│   ├── catalogo/                  Microservicio de catálogo e inventario
│   ├── pedidos/                   Microservicio de tienda y entregas
│   ├── pagos/                     Microservicio de punto de venta y FEL
│   ├── gateway/                   Puerta de enlace
│   └── mysql/                     Configuración, esquema, rutinas y catálogos
├── docs/
│   ├── arquitectura/              Diagramas
│   └── devops1/evidencias/        Evidencias técnicas generadas
├── scripts/
│   ├── verificar-esquema.sh       Trazabilidad documento ↔ implementación
│   └── evidencias.sh              Generación de evidencias
├── src/                           Aplicación Laravel 10
├── tests/
│   ├── humo/                      Pruebas automáticas
│   ├── casos/                     Casos para Azure Test Plans
│   ├── api/                       Peticiones de prueba
│   └── unitarias/                 Pruebas de PHPUnit
├── docker-compose.yml             Definición de los nueve servicios
├── docker-compose.override.yml    Ajustes de desarrollo
├── .env.example                   Variables de entorno
├── Makefile
├── CLAUDE.md                      Reglas para Claude Code
└── PLAN.md                        Plan de ejecución de la aplicación
```

## Desarrollo frente a producción

`docker-compose.override.yml` se aplica automáticamente en desarrollo: monta el
código desde el equipo, expone MySQL y Redis al equipo local y agrega la
bandeja de correo. En el servidor se ejecuta solo el archivo principal:

```bash
docker compose -f docker-compose.yml up -d
```

Ninguna credencial se versiona. Las contraseñas, la clave de la aplicación y
las credenciales del certificador FEL viven en `.env`, excluido del control de
versiones. En Azure App Service se configuran como Application Settings.
