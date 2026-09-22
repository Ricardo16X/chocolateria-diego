# Universidad Mariano Gálvez de Guatemala

**Facultad de Ingeniería en Sistemas de Información**
**Curso:** Seminario de Tecnologías de Información — código 1900-047
**Catedrático:** Ing. Erick Roberto Aguilar Juárez
**Proyecto:** Artesanal Chocolate Diego — Plataforma de gestión
**Entrega:** DEVOPS 1 — Contenedores, integración continua y arquitectura de microservicios
**Grupo:** 8

## Integrantes

| Carné | Nombre | Rol | Participación |
|---|---|---|---|
| 0900-22-15843 | Carla Estefanía Duque Martínez | Scrum Master | — (pendiente) |
| 0900-09-13357 | William Natanael Vásquez Navichoc | Product Owner | — (pendiente) |
| 0900-09-6892 | Julio Alexis León Rodríguez | Desarrollo — Azure DevOps | — (pendiente) |
| 0900-23-22081 | Ricardo Ismael Pérez Ajanel | Desarrollo — Docker y microservicios | — (pendiente) |

---

## Introducción

Artesanal Chocolate Diego es una empresa de chocolate artesanal de San Pedro
La Laguna, Sololá, que requiere una plataforma web para gestionar su
inventario por lotes, su punto de venta, su facturación electrónica ante la
SAT y su tienda en línea con entregas en cuatro departamentos. Las entregas
anteriores del proyecto definieron el modelo de negocio, el modelo relacional
y el diseño de la solución. Esta entrega, DEVOPS 1, cubre la primera etapa de
construcción: la infraestructura de contenedores, la aplicación que corre
dentro de ella y la integración continua que la respalda.

## Objetivo general

Construir y verificar la infraestructura de contenedores y la aplicación web
de Artesanal Chocolate Diego bajo una arquitectura de microservicios, con
integración continua y trazabilidad completa entre el modelo de datos
documentado y su implementación.

## Objetivos específicos

- Dividir el sistema en microservicios de dominio independientes, cada uno
  con su propio contenedor, y una puerta de enlace como único punto de
  entrada.
- Implementar la aplicación Laravel sobre el esquema relacional ya
  construido, sin alterar el modelo de datos documentado.
- Automatizar la construcción, las pruebas y la verificación del sistema
  mediante integración continua.
- Demostrar que el registro de una venta, su facturación electrónica y las
  alertas del negocio ocurren de forma correcta y trazable.

## Referencia a la entrega anterior

El Séptimo y el Octavo Documento de Proyecto definieron el modelo relacional
de 32 tablas, 274 columnas, 56 llaves foráneas y 28 restricciones CHECK, junto
con 5 funciones, 3 disparadores, 5 procedimientos almacenados y 10 vistas.
Esta entrega no modifica ese modelo: `docker/mysql/init/01_esquema.sql` es su
única fuente de verdad, y `scripts/verificar-esquema.sh` compara las ocho
cifras declaradas contra lo que existe en MySQL en cada verificación (ver
sección de Trazabilidad). La figura 1 del Séptimo Documento menciona React
por error; el diagrama de la fase 7 de esta entrega (`docs/arquitectura/`) la
corrige: el frontend es Blade con Tailwind CSS, sin frameworks de JavaScript.

---

## Desarrollo

### 1. Control de versiones

**Repositorio.** El código vive en un único repositorio, con la estructura
siguiente:

```
chocolate-diego/
├── .github/workflows/ci.yml       Integración continua en GitHub
├── azure-pipelines.yml            Integración continua en Azure DevOps
├── docker/                        Dockerfiles y configuración de cada servicio
│   ├── base/                      Imagen base común de los microservicios
│   ├── auth/ catalogo/ pedidos/ pagos/   Los cuatro servicios de dominio
│   ├── gateway/                   Puerta de enlace
│   └── mysql/                     Esquema, rutinas y catálogos base
├── docs/
│   ├── arquitectura/              Diagramas
│   └── devops1/                   Esta entrega: documento y evidencias
├── scripts/                       Verificación de esquema y generación de evidencias
├── src/                           Aplicación Laravel 10
├── tests/                         Pruebas de humo, casos para Azure Test Plans
├── docker-compose.yml             Definición de los nueve servicios
├── docker-compose.override.yml    Ajustes de desarrollo
├── Makefile                       Tareas frecuentes
├── CLAUDE.md                      Reglas técnicas del proyecto
└── PLAN.md                        Plan de ejecución, fase por fase
```

**Estrategia de ramas.** `azure-pipelines.yml` ya define el disparador sobre
las ramas `main` y `develop`, y exige revisión de *pull request* contra
`main`. El trabajo de cada fase o funcionalidad se hace en una rama propia a
partir de `develop`; `main` refleja siempre el estado desplegable.

**Convención de commits.** El grupo usa *commits* convencionales, regla fijada
en `CLAUDE.md`: `feat:` para una funcionalidad nueva, `fix:` para una
corrección, `docs:` para documentación, `chore:` para tareas de
mantenimiento, `ci:` para cambios de integración continua y `test:` para
pruebas. Los mensajes se escriben en español, igual que el resto del
proyecto.

### 2. Diseño basado en microservicios

El sistema se divide en cuatro microservicios de dominio, cada uno con su
propio Dockerfile y su propio contenedor sobre una imagen base común de PHP
8.1, y cinco servicios de infraestructura. Solo la puerta de enlace se
publica al exterior; los ocho servicios restantes viven en la red interna
`chdiego_net`, sin puertos publicados.

| Servicio | Responsabilidad | Tablas |
|---|---|---|
| `auth` | Identidad, roles, permisos, auditoría | `rol`, `permiso`, `rol_permiso`, `usuario`, `bitacora` |
| `catalogo` | Productos, precios, lotes, existencias, kardex; vitrina pública | `categoria`, `producto`, `historial_precio`, `bodega`, `lote`, `existencia`, `tipo_movimiento`, `movimiento_inventario`, `reserva_existencia` |
| `pedidos` | Clientes, carrito, envíos, suscripciones | `cliente`, `direccion_entrega`, `pedido`, `detalle_pedido`, `carrito`, `detalle_carrito`, `zona_cobertura`, `transportista`, `envio`, `plan_suscripcion`, `suscripcion` |
| `pagos` | Punto de venta y facturación electrónica FEL | `venta`, `detalle_venta`, `metodo_pago`, `turno_caja`, `documento_fel` |

Las tablas `notificacion` y `parametro_sistema` son transversales: las
consulta cualquiera de los cuatro servicios.

**Puerta de enlace.** `gateway` (nginx 1.27) es el único punto de entrada
HTTP, en el puerto 8080. Resuelve el destino de cada petición contra un mapa
de prefijos (`/api/auth/`, `/api/catalogo/`, `/api/pedidos/`, `/api/pagos/`,
y cualquier otra ruta a `catalogo` como vitrina pública) y agrega la
cabecera `X-Servicio` con el nombre del servicio que atendió, verificable en
cada respuesta.

**Servicios de infraestructura.** `db` (MySQL 8.0) sostiene el modelo
relacional; `cache` (Redis 7) las sesiones, la caché y las colas de
trabajos; `queue` (imagen de `pagos`) procesa las colas `fel`, `correo` y
`default`; `scheduler` (imagen de `catalogo`) corre las tareas programadas.

**Por qué el worker de colas va aparte.** La certificación del DTE ante el
certificador FEL-SAT es una llamada a un servicio externo, con una latencia
y una disponibilidad que el sistema no controla. Si esa llamada ocurriera
dentro del ciclo de la petición HTTP, una venta quedaría bloqueada —o
fallaría— por un problema ajeno al negocio: el certificador lento o caído.
Por eso `sp_registrar_venta` deja el documento en `documento_fel` con estado
`pendiente` y comete su transacción de inmediato; la venta ya está
registrada. La certificación corre después, en un `Job` de la cola `fel`
(`App\Jobs\CertificarDocumentoFel`), en un contenedor propio. Si el
certificador falla, el `Job` reintenta con un retroceso creciente hasta el
máximo configurado en `parametro_sistema.fel.intentos_maximos`, y solo
entonces marca el documento como `rechazado` y genera una alerta — la venta,
mientras tanto, nunca dejó de estar registrada.

**Diagrama de contenedores.** El diagrama completo, con la red, los
volúmenes nombrados, el único puerto publicado y los dos servicios externos
(certificador FEL-SAT y SendGrid) está en
[`docs/arquitectura/diagrama-contenedores.png`](../arquitectura/diagrama-contenedores.png)
(fuente en `.puml`, también disponible en `.svg`).

**MySQL frente a PostgreSQL.** El proyecto utiliza MySQL 8.0 y no
PostgreSQL. El modelo relacional, el diccionario de datos y la
implementación entregados en el Séptimo y el Octavo Documento se
construyeron y verificaron sobre MySQL, incluidas sus funciones,
disparadores, procedimientos almacenados y vistas. Cambiar de motor en esta
etapa rompería la trazabilidad entre el modelo documentado y la
implementación.

### 3. Cómputo en la nube

El diseño de despliegue en Azure preserva la misma separación de
responsabilidades que los contenedores locales:

- **Azure App Service**, en modo contenedor, aloja la puerta de enlace y los
  cuatro microservicios de dominio. Cada uno se despliega como una imagen
  independiente, igual que en `docker-compose.yml`, y App Service maneja el
  escalado y el reinicio de cada uno por separado.
- **Azure Database for MySQL Flexible Server** reemplaza al contenedor `db`.
  El esquema, las rutinas y los catálogos base de `docker/mysql/init/` se
  aplican igual, sin cambios: el motor es el mismo, MySQL 8.0.
- **Azure Blob Storage** reemplaza al volumen `chdiego_app_storage` para los
  archivos que hoy vive ahí: los XML de los DTE que genera
  `CertificarDocumentoFel` y los archivos que suba la aplicación. Las
  variables `AZURE_STORAGE_NAME`, `AZURE_STORAGE_KEY` y
  `AZURE_STORAGE_CONTAINER` ya están declaradas en `.env.example`, sin
  completar hasta el aprovisionamiento real.
- El correo transaccional, que en desarrollo captura Mailpit, sale por
  **SendGrid** en producción (ver `docker-compose.override.yml`, donde
  Mailpit se declara exclusivo de desarrollo).

**Azure DevOps.** `azure-pipelines.yml` ya define las dos etapas de
integración continua —construcción de las cinco imágenes y ejecución de las
18 pruebas de humo—, disparadas sobre las ramas `main` y `develop` y sobre
cada *pull request* contra `main` (Azure Repos). Los resultados se publican
en la pestaña **Tests** de la ejecución, en formato JUnit. Azure Test Plans
importa los 18 casos de `tests/casos/casos-de-prueba-azure.csv` como
elementos de trabajo de tipo *Test Case*, cada uno con el mismo
identificador (H01 a H18) que su prueba automática: esa correspondencia es
la trazabilidad entre lo que Test Plans describe como pasos manuales y lo
que el *pipeline* ejecuta. Azure Boards sostiene el tablero de trabajo del
equipo.

### 4. Trazabilidad

La tabla relaciona cada módulo del modelo de datos con el requerimiento que
cubre, las tablas involucradas, el servicio del *compose* que lo atiende y
la evidencia que lo respalda.

| Requerimiento | Módulo | Tablas | Servicio | Evidencia |
|---|---|---|---|---|
| Identidad, roles, permisos y auditoría | Seguridad | `rol`, `permiso`, `rol_permiso`, `usuario`, `bitacora` | `auth` | H05, H09–H11; login real verificado en Fase 4 (PLAN.md); `evidencias/06-dominio-de-cada-servicio.txt` |
| Catálogo de productos y precios | Catálogo | `categoria`, `producto`, `historial_precio` | `catalogo` | H06, H14; `docs/devops1/trazabilidad.md` |
| Inventario por lotes y kardex | Inventario | `bodega`, `lote`, `existencia`, `tipo_movimiento`, `movimiento_inventario`, `reserva_existencia` | `catalogo` | H14, H18; `evidencias/11-verificacion-de-esquema.txt` (cuadre del kardex) |
| Punto de venta | Punto de Venta | `venta`, `detalle_venta`, `metodo_pago`, `turno_caja` | `pagos` | H15, H17; flujo completo verificado por HTTP en Fase 5 (PLAN.md) |
| Facturación electrónica FEL | FEL | `documento_fel` | `pagos` (cola `fel`, servicio `queue`) | H15; certificación, reintentos y rechazo verificados por la cola real en Fase 6 (PLAN.md) |
| Clientes, carrito y pedidos | Clientes | `cliente`, `direccion_entrega`, `pedido`, `detalle_pedido`, `carrito`, `detalle_carrito` | `pedidos` | H07; `docs/devops1/trazabilidad.md` |
| Entregas y zonas de cobertura | Entregas | `zona_cobertura`, `transportista`, `envio` | `pedidos` | H07; `docs/devops1/trazabilidad.md` |
| Caja por suscripción | Suscripción | `plan_suscripcion`, `suscripcion` | `pedidos` | Recordatorio de entrega próxima verificado en Fase 6 (`chdiego:recordar-suscripciones`, PLAN.md) |
| Notificaciones y parámetros del sistema | Soporte | `notificacion`, `parametro_sistema` | Transversal (los cuatro) | Alertas internas y parámetros dinámicos (tasa de IVA, intentos máximos) verificados en Fase 6 (PLAN.md) |

**Verificación de esquema.** `scripts/verificar-esquema.sh` compara las ocho
cifras declaradas en el Octavo Documento de Proyecto contra lo que existe en
la base de datos construida:

```
OBJETO                        DOCUMENTO      MYSQL  RESULTADO
------------------------------------------------------------
Tablas                               32         32         OK
Columnas                            274        274         OK
Llaves foraneas                      56         56         OK
Restricciones CHECK                  28         28         OK
Funciones                             5          5         OK
Disparadores                          3          3         OK
Procedimientos                        5          5         OK
Vistas                               10         10         OK
```

(Salida completa en
[`evidencias/11-verificacion-de-esquema.txt`](evidencias/11-verificacion-de-esquema.txt),
que además verifica los 23 objetos por nombre y el cuadre del kardex.)

---

## Evidencias

`scripts/evidencias.sh` genera catorce evidencias técnicas en
`docs/devops1/evidencias/`, con su propio índice
([`evidencias/README.md`](evidencias/README.md)):

| # | Evidencia | Qué demuestra |
|---|---|---|
| 01 | Versión de Docker | Versiones de Docker y Compose usadas |
| 02 | Composición validada | La composición de nueve servicios es válida |
| 03 | Construcción de imágenes | Cada microservicio se construye desde su Dockerfile |
| 04 | Servicios en ejecución | Los nueve contenedores levantan y quedan saludables |
| 05 | Imágenes construidas | Tamaño de las imágenes propias |
| 06 | Dominio de cada servicio | Módulo y tablas que atiende cada microservicio |
| 07 | Registros por servicio | Arranque correcto de cada servicio |
| 08 | Red interna | Red aislada y direcciones asignadas |
| 09 | Volúmenes | Persistencia de datos fuera de los contenedores |
| 10 | Enrutamiento por dominio | La puerta de enlace entrega cada prefijo a su servicio |
| 11 | Verificación de esquema | La base implementada corresponde al Octavo Documento |
| 12 | Consumo de recursos | CPU, memoria y red por contenedor |
| 13 | Tolerancia a fallos | La caída de `pagos` no afecta a los demás servicios, y se recupera |
| 14 | Pruebas de humo | Resultado de las 18 pruebas automáticas: 18 pasan, 0 fallan |

La evidencia 13 detiene el contenedor `pagos` a propósito y confirma que
`auth` y `catalogo` responden con normalidad, y que `pagos` vuelve a
responder sin necesidad de reiniciar la puerta de enlace: nginx resuelve
los nombres de los contenedores en cada petición, no al arrancar.

---

## Conclusiones

La infraestructura de contenedores y la aplicación Laravel que corre sobre
ella quedan construidas y verificadas de punta a punta: las 18 pruebas de
humo pasan, las ocho cifras del esquema coinciden con el Octavo Documento de
Proyecto, y el flujo completo de una venta —registro, descuento de
inventario, certificación FEL con reintentos, y anulación— se comprobó
contra la base de datos real, no solo contra código aislado.

La separación en microservicios demostró su valor concreto durante esta
misma construcción: la puerta de enlace mantuvo el tráfico hacia `auth` y
`catalogo` mientras `pagos` estaba deliberadamente caído, y la certificación
del DTE, al vivir en su propia cola, nunca bloqueó el registro de una venta
ni siquiera cuando el certificador simulado se configuró para fallar
repetidamente.

Queda pendiente, para las próximas entregas, contratar el certificador
FEL-SAT real (hoy sustituido por un adaptador de simulación configurable) y
completar el aprovisionamiento de los servicios de Azure descritos en la
sección de cómputo en la nube.
