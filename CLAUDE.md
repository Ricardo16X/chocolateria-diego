# Contexto del proyecto

Plataforma web en la nube para **Artesanal Chocolate Diego**, empresa de
chocolate artesanal de San Pedro La Laguna, Sololá, Guatemala. Proyecto
académico de la Universidad Mariano Gálvez, curso Seminario de Tecnologías de
Información, código 1900-047, Grupo 8.

Alcance funcional: inventario con lotes y vencimientos, punto de venta,
facturación electrónica FEL ante la SAT, tienda en línea con entregas en
Sololá, Chimaltenango, Sacatepéquez y Guatemala, y caja por suscripción.

La infraestructura de contenedores ya está construida y funciona. El trabajo
pendiente es la aplicación Laravel que corre dentro de ella.

## Arquitectura de microservicios

Una sola base de código Laravel en `src/` corre en cuatro contenedores de
dominio. Cada contenedor recibe la variable de entorno `SERVICIO` con su
nombre, y la puerta de enlace le entrega solo las peticiones de su prefijo:

| Servicio | Prefijo | Carpeta de modelos |
|---|---|---|
| `auth` | `/api/auth/` | `Seguridad` |
| `catalogo` | `/api/catalogo/` y la vitrina pública | `Catalogo`, `Inventario` |
| `pedidos` | `/api/pedidos/` | `Clientes`, `Entregas`, `Suscripcion` |
| `pagos` | `/api/pagos/` | `PuntoVenta`, `Fel` |

Reglas que se derivan de esto:

- Las rutas de cada dominio se registran agrupadas bajo su prefijo en
  `routes/api.php`. Una ruta de pagos nunca va bajo `/api/catalogo/`.
- Cada servicio expone `GET /api/<servicio>/salud`, que responde con el valor
  de `SERVICIO`. Las pruebas de humo lo usan.
- Un controlador de un dominio no consulta directamente tablas de otro dominio;
  usa el servicio o el procedimiento almacenado correspondiente.
- El worker de colas corre con la imagen de `pagos` y el planificador con la de
  `catalogo`.

## Reglas técnicas no negociables

### Versiones
- PHP 8.1, Laravel 10, MySQL 8.0, Redis 7, nginx 1.27. No actualizar versiones
  mayores ni sugerir hacerlo.
- No usar Laravel Sail. La orquestación es el `docker-compose.yml` del
  repositorio.

### Base de datos
- `docker/mysql/init/01_esquema.sql` es la **única fuente de verdad** del modelo
  de datos. Nunca crear, alterar ni eliminar tablas de negocio desde migraciones
  de Laravel.
- Los modelos Eloquent se mapean a las tablas existentes con `$table`,
  `$primaryKey`, `$timestamps = false`, `$fillable` y `$casts` explícitos.
- Las columnas generadas (`venta.total`, `pedido.total`, `subtotal_linea`,
  `lote_clave`, `predeterminada_clave`, `factura_clave`) **nunca** se escriben.
  Van en `$guarded` o fuera de `$fillable`. MySQL rechaza cualquier intento.
- Nombres de tablas y columnas en español, tal como están en el esquema. No
  pluralizar, no traducir, no usar convenciones de Laravel.
- Las únicas migraciones permitidas son las de infraestructura del framework:
  `personal_access_tokens`, `failed_jobs`, `password_reset_tokens`,
  `job_batches`. Esas no pertenecen al modelo de negocio.
- Antes de cambiar el precio de un producto, la conexión debe fijar la variable
  de sesión: `SET @id_usuario_actual = ?, @motivo_cambio_precio = ?`. El
  disparador `trg_producto_historial_precio` rechaza el cambio si viene nula.
- Los parámetros de negocio (tasa de IVA, reintentos, vigencias) viven en
  `parametro_sistema` y se leen en cada operación, nunca como constante fija en
  código PHP ni en variables de entorno. `sp_registrar_venta` ya lee
  `fel.tasa_iva` de esa tabla; cualquier lógica nueva que dependa de un valor
  de negocio configurable sigue el mismo patrón, para que un cambio no exija
  redesplegar.
- Los 25 `SIGNAL SQLSTATE '45000'` de `02_rutinas.sql` llevan un código en
  mayúsculas antes del mensaje, `MODULO_MOTIVO: texto en español`. El código
  es el contrato estable para mapear a excepciones de dominio en PHP
  (`SUBSTRING_INDEX(mensaje, ':', 1)`); el texto es solo para mostrar al
  usuario y puede reformularse sin romper nada. Toda señal nueva sigue el
  mismo formato.

### Aplicación
- Frontend con **Blade y Tailwind CSS**. No introducir React, Vue ni Inertia.
  La figura 1 del séptimo documento menciona React por error y está en
  corrección.
- Autenticación con Laravel Sanctum. Roles y permisos se leen de las tablas
  `rol`, `permiso` y `rol_permiso`, no de un paquete externo.
- Sesiones, caché y colas sobre Redis.
- La certificación del DTE ante el certificador FEL-SAT va siempre en un Job de
  la cola `fel`, nunca en el ciclo de la petición. Si falla, la venta ya quedó
  registrada.
- Ningún secreto en el código. Todo por variables de entorno.

### Estilo
- Comentarios, mensajes de commit y textos de interfaz en español.
- Commits convencionales: `feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `test:`.
- Antes de dar una fase por terminada, ejecutar su criterio de aceptación y
  mostrar la salida real del comando. No declarar algo funcionando sin haberlo
  corrido.

### Documentos
- Texto formal en tercera persona, sin gerundios, tono lineal y afirmativo. Las
  decisiones se afirman y se justifican; no se presentan como menú de opciones.
- No referenciar la guía del curso dentro de los documentos.

## Comandos del repositorio

```
make arriba        levanta los nueve servicios
make consola       terminal dentro del microservicio catalogo
make mysql         cliente de MySQL
make verificar     comprueba el esquema contra el documento
make probar        ejecuta las 18 pruebas de humo
make evidencias    genera las evidencias de DEVOPS 1
make registros     sigue los registros
```

Todo comando de PHP, Composer o artisan se ejecuta **dentro del contenedor**:
`docker compose exec catalogo php artisan ...`. No instalar PHP ni Composer en el
equipo.
