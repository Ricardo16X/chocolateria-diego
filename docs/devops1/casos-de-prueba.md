# Casos de Prueba

**Proyecto:** Artesanal Chocolate Diego — Plataforma de gestión
**Entrega:** DEVOPS 2 — Integración continua, entrega continua y plan de pruebas
**Grupo:** 8
**Responsable:** Ricardo Ismael Pérez Ajanel — carné 0900-23-22081
**Ejecución documentada:** 28 de septiembre de 2026
**Plan de pruebas asociado:** [`plan-de-pruebas.md`](plan-de-pruebas.md)

---

## Cómo leer este documento

**51 casos** en cuatro suites, con **73 ejecuciones**. Cada caso lleva su
identificador, su tipo, su prioridad, sus precondiciones, sus pasos, el
resultado esperado y el **resultado obtenido** en la ejecución de referencia.

El identificador dice a qué suite pertenece:

| Prefijo | Suite | Tipo de prueba | Casos |
|---|---|---|---|
| **U** | `src/tests/` con PHPUnit | Unitarias | U01–U17 |
| **H** | `tests/humo/pruebas-humo.sh` | Integración y sistema | H01–H18 |
| **S** | `tests/seguridad/pruebas-seguridad.sh` | Seguridad | S01–S11 |
| **R** | `tests/rendimiento/pruebas-rendimiento.sh` | Rendimiento | R01–R05 |

Cada caso existe en tres lugares con el mismo identificador: aquí documentado,
en `tests/casos/casos-de-prueba-azure.csv` como caso manual para Azure Test
Plans, y en su script como prueba automatizada que corre en cada cambio subido
al repositorio. Esa numeración compartida es la trazabilidad.

**Prioridad 1** = crítico, bloquea la entrega si falla. **Prioridad 2** =
importante, no bloqueante.

Las duraciones corresponden a la corrida de referencia archivada en
`tests/resultados/`. Varían en centésimas de segundo entre corridas, y bastante
más en un agente de integración continua: se documentan como orden de magnitud,
no como valor exacto reproducible.

## Resumen de la ejecución

| | |
|---|---|
| Casos documentados | 51 |
| Ejecuciones | 73 |
| Aprobadas | 73 |
| Falladas | 0 |
| Bloqueadas | 0 |
| Duración total | poco más de 30 segundos |
| Reporte consolidado | `docs/devops1/evidencias/informes/reporte-de-pruebas.html` |

| Suite | Tipo | Casos | Ejecuciones | Aprobadas | Duración |
|---|---|---|---|---|---|
| Unitarias | Unitarias | 17 | 39 | 39 de 39 | 0.11 s |
| Humo | Sistema (H01–H11) e integración (H12–H18) | 18 | 18 | 18 de 18 | 20 s |
| Seguridad | Seguridad | 11 | 11 | 11 de 11 | 9 s |
| Rendimiento | Rendimiento | 5 | 5 | 5 de 5 | 2 s |

---

# Suite 1 — Pruebas unitarias (U01–U17)

**Tipo:** unitarias · **Herramienta:** PHPUnit 10.5.64 · **Ejecución:**
`make probar-unitarias`

**Precondición común a los 17 casos:** existe un contenedor de aplicación en
ejecución con las dependencias de Composer instaladas. No requieren base de
datos, ni Redis, ni red: cada caso construye en memoria lo que necesita. Por eso
la suite completa tarda 0.11 s.

## Grupo 1.1 — Traducción de errores de procedimiento (U01–U05)

**Archivo:** `src/tests/Unit/TraduceErroresDeProcedimientoTest.php`
**Sujeto:** `App\Services\TraduceErroresDeProcedimiento`
**Duración del grupo:** 0.001 s · **5 de 5 aprobados**

Los 25 `SIGNAL SQLSTATE '45000'` de `02_rutinas.sql` llevan un código en
mayúsculas antes de los dos puntos. Ese código es el contrato estable que el
controlador usa para decidir; el texto que sigue es para mostrar al usuario y
puede reformularse sin romper nada. Este grupo verifica ese contrato.

### U01 — Un SIGNAL 45000 se traduce separando código y texto

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Ninguna adicional |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Construir una `QueryException` con SQLSTATE 45000 y mensaje `VENTA_SIN_ITEMS: La venta no tiene lineas de detalle.` | — |
| 2 | Pasarla por `traducir()` | Devuelve una `ExcepcionNegocio` |
| 3 | Leer el código y el mensaje | Código `VENTA_SIN_ITEMS`, mensaje `La venta no tiene lineas de detalle.` |

**Resultado obtenido:** los tres pasos conformes. El código y el texto quedan
separados en las dos propiedades correctas.

### U02 — Un error que no es SIGNAL 45000 pasa sin traducir

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Ninguna adicional |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Construir una `QueryException` con SQLSTATE `42S02` (tabla inexistente) | — |
| 2 | Pasarla por `traducir()` | Devuelve la **misma instancia** de `QueryException`, no una excepción de negocio |

**Resultado obtenido:** devuelve la instancia original. Es el comportamiento
correcto: una conexión caída o una tabla inexistente no son errores de negocio
y deben seguir propagándose para que el manejador global las trate como fallo
de infraestructura.

### U03 — Sin dos puntos en el mensaje se usa el código desconocido

| | |
|---|---|
| Prioridad | 2 |
| Precondición | Ninguna adicional |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Construir un SIGNAL 45000 con mensaje `Un mensaje sin codigo delante` | — |
| 2 | Pasarlo por `traducir()` | Código `ERROR_DESCONOCIDO`, mensaje íntegro |

**Resultado obtenido:** conforme. El sistema degrada sin romperse ante un
mensaje que no sigue la convención.

### U04 — Se recortan los espacios alrededor del código y del texto

| | |
|---|---|
| Prioridad | 2 |
| Precondición | Ninguna adicional |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Construir un SIGNAL 45000 con espacios sobrantes: `  INVENTARIO_EXISTENCIA_NEGATIVA  :   No hay existencia suficiente.  ` | — |
| 2 | Pasarlo por `traducir()` | Código y mensaje sin espacios al inicio ni al final |

**Resultado obtenido:** código `INVENTARIO_EXISTENCIA_NEGATIVA` y mensaje
`No hay existencia suficiente.`, ambos recortados.

### U05 — Los dos puntos dentro del texto se conservan

| | |
|---|---|
| Prioridad | 2 |
| Precondición | Ninguna adicional |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Construir un SIGNAL 45000 cuyo texto contenga una hora: `VENTA_YA_ANULADA: La venta ya fue anulada el 2026-09-28 a las 10:30:00.` | — |
| 2 | Pasarlo por `traducir()` | El corte ocurre en el **primer** separador; el texto conserva sus dos puntos |

**Resultado obtenido:** código `VENTA_YA_ANULADA`, texto completo con la hora
intacta.

## Grupo 1.2 — Excepción de negocio (U06–U08)

**Archivo:** `src/tests/Unit/ExcepcionNegocioTest.php`
**Sujeto:** `App\Exceptions\ExcepcionNegocio`
**Duración del grupo:** 0.002 s · **3 de 3 aprobados**

### U06 — Expone el código y el mensaje por separado

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Ninguna adicional |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Construir `ExcepcionNegocio('VENTA_TURNO_CERRADO', 'El turno de caja esta cerrado.')` | — |
| 2 | Leer la propiedad de código y el mensaje | Quedan disponibles por separado, sin necesidad de analizar el texto |

**Resultado obtenido:** conforme.

### U07 — Compara el código sin depender del texto

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Ninguna adicional |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Construir la excepción con código `VENTA_SIN_ITEMS` y un texto arbitrario | — |
| 2 | Llamar `esCodigo('VENTA_SIN_ITEMS')` | Verdadero |
| 3 | Llamar `esCodigo('VENTA_YA_ANULADA')` | Falso |
| 4 | Llamar `esCodigo('venta_sin_items')` | Falso: la comparación distingue mayúsculas |

**Resultado obtenido:** los cuatro pasos conformes. Es la razón de existir de la
clase: reformular el mensaje para el usuario no rompe ninguna decisión de
lógica.

### U08 — Sigue siendo una excepción de PHP capturable

| | |
|---|---|
| Prioridad | 2 |
| Precondición | Ninguna adicional |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Lanzar una `ExcepcionNegocio` | Se puede capturar como `RuntimeException` |

**Resultado obtenido:** conforme. El manejador global de excepciones la
recoge sin tratamiento especial.

## Grupo 1.3 — Modelos contra el esquema (U09–U13)

**Archivo:** `src/tests/Unit/ModelosContraEsquemaTest.php`
**Duración del grupo:** 0.014 s · **27 ejecuciones, 27 aprobadas**

`01_esquema.sql` es la única fuente de verdad del modelo de datos, y los
modelos Eloquent se mapean contra él a mano. Este grupo es la red de seguridad
contra el error más probable del proyecto: que alguien agregue a `$fillable` una
columna que MySQL calcula sola, o que renombre una tabla siguiendo las
convenciones de Laravel en vez de las del esquema.

### U09 — Una columna generada por MySQL nunca es asignable en masa

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Ninguna adicional |
| Ejecuciones | 7, una por columna generada |
| Resultado | **Aprobado, 7 de 7** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Para cada una de las 7 columnas `GENERATED ALWAYS` del esquema, leer el `$fillable` del modelo que mapea su tabla | La columna **no** aparece en `$fillable` |

Columnas verificadas: `existencia.lote_clave`,
`direccion_entrega.predeterminada_clave`, `pedido.total`,
`detalle_pedido.subtotal_linea`, `venta.total`, `detalle_venta.subtotal_linea`,
`documento_fel.factura_clave`.

**Resultado obtenido:** ninguna de las siete es asignable. MySQL rechazaría
cualquier intento de escritura.

### U10 — Una columna generada no pasa el filtro de asignación de Eloquent

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Ninguna adicional |
| Ejecuciones | 7, las mismas columnas |
| Resultado | **Aprobado, 7 de 7** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Intentar `fill([columna => 1])` sobre el modelo correspondiente | El atributo no queda asignado |

**Resultado obtenido:** las siete descartadas por Eloquent. U09 lee la
declaración; U10 ejercita el comportamiento real, que es lo que protege de
verdad.

### U11 — El modelo apunta a la tabla y la llave del esquema

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Ninguna adicional |
| Ejecuciones | 6, una por modelo |
| Resultado | **Aprobado, 6 de 6** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Leer `getTable()` y `getKeyName()` de cada modelo | Coinciden con el nombre y la llave primaria del esquema, en español y en singular |

Modelos verificados: `Usuario`/`usuario`/`id_usuario`,
`Venta`/`venta`/`id_venta`, `DetalleVenta`/`detalle_venta`/`id_detalle_venta`,
`Pedido`/`pedido`/`id_pedido`, `Existencia`/`existencia`/`id_existencia`,
`DocumentoFel`/`documento_fel`/`id_documento_fel`.

**Resultado obtenido:** los seis conformes. Sin la declaración explícita,
Laravel pluralizaría en inglés y buscaría `ventas` o `usuarios`.

### U12 — Ningún modelo espera las marcas de tiempo de Laravel

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Ninguna adicional |
| Ejecuciones | 6, los mismos modelos |
| Resultado | **Aprobado, 6 de 6** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Leer `usesTimestamps()` de cada modelo | Falso en los seis |

**Resultado obtenido:** conforme. Ninguna tabla del esquema tiene `created_at`
ni `updated_at`; con las marcas activas, Eloquent intentaría escribirlas y
fallaría.

### U13 — El usuario autentica contra `contrasena_hash` y no la expone

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Ninguna adicional |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Asignar un hash a `contrasena_hash` y llamar `getAuthPassword()` | Devuelve ese hash |
| 2 | Leer `getHidden()` | Incluye `contrasena_hash` |
| 3 | Serializar el modelo con `toArray()` | El hash **no** aparece |

**Resultado obtenido:** los tres pasos conformes. La columna se llama
`contrasena_hash`, no `password`, y el guard lo sabe por `getAuthPassword()`.

## Grupo 1.4 — Adaptador del certificador FEL (U14–U17)

**Archivo:** `src/tests/Feature/CertificadorSimuladoTest.php`
**Sujeto:** `App\Fel\CertificadorSimulado`
**Duración del grupo:** 0.092 s · **4 de 4 aprobados**

**Precondición del grupo:** además de la común, el contenedor de servicios de
Laravel debe estar arrancado, porque el adaptador lee configuración y escribe
en un disco de almacenamiento. Ese disco se reemplaza por uno falso en cada
caso, y el documento FEL se construye en memoria: no se toca la base de datos.

### U14 — Devuelve las cuatro claves que el contrato declara

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Modo de simulación en `exito`, almacenamiento falso |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Certificar un documento FEL en memoria | Devuelve exactamente las claves `serie`, `numero_dte`, `numero_autorizacion` y `ruta_xml`, en ese orden |
| 2 | Leer la serie | Es `SIM` |

**Resultado obtenido:** conforme. Es el contrato que el Job de la cola consume;
si cambiara, el Job fallaría en producción y no en la prueba.

### U15 — Rellena el número de DTE a diez dígitos

| | |
|---|---|
| Prioridad | 2 |
| Precondición | Modo `exito`, documento con identificador 42 |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Certificar y leer `numero_dte` | Es `0000000042`, de 10 caracteres |

**Resultado obtenido:** conforme.

### U16 — Deja el XML escrito y bien formado en la ruta que reporta

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Modo `exito`, almacenamiento falso |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Certificar y comprobar que existe el archivo en `ruta_xml` | El archivo existe |
| 2 | Analizar el contenido como XML | Es bien formado |
| 3 | Leer serie, número, NIT receptor y monto total | `SIM`, `0000000042`, `CF` y `75.00` |

**Resultado obtenido:** los tres pasos conformes. La ruta que el adaptador
reporta es la ruta donde el archivo realmente está.

### U17 — Lanza excepción cuando se configura para fallar

| | |
|---|---|
| Prioridad | 1 |
| Precondición | Modo de simulación en `fallo` |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Certificar un documento con el modo en `fallo` | Lanza `RuntimeException` cuyo mensaje incluye `FEL_SIMULACION_MODO=fallo` |

**Resultado obtenido:** conforme. Es el camino que la cola necesita para
reintentar: si el certificador no lanzara, el Job daría la certificación por
buena y el DTE quedaría marcado como certificado sin estarlo.

---

# Suite 2 — Integración y sistema (H01–H18)

**Tipo:** sistema (H01–H11) e integración (H12–H18) · **Ejecución:**
`make probar` · **Duración:** 20 s · **18 de 18 aprobados**

**Precondición común a los 18 casos:** las cinco imágenes construidas
(`make construir`), archivo `.env` con `APP_KEY`, los nueve servicios
levantados (`make arriba`) y `chdiego_db` en estado `healthy`.

## Grupo 2.1 — Infraestructura (H01–H04)

### H01 — Los nueve contenedores están en ejecución

| | |
|---|---|
| Tipo | Sistema |
| Prioridad | 1 |
| Precondición | La común |
| Duración | 0.40 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `docker compose ps` | Se listan `gateway`, `auth`, `catalogo`, `pedidos`, `pagos`, `db`, `cache`, `queue` y `scheduler` |
| 2 | Revisar la columna STATUS | Los nueve aparecen como `Up`; los que tienen comprobación de salud aparecen como `healthy` |

**Resultado obtenido:** los nueve servicios levantados. `chdiego_db`,
`chdiego_cache` y `chdiego_gateway` en `healthy`. Evidencia 04.

### H02 — La base de datos reporta estado saludable

| | |
|---|---|
| Tipo | Sistema |
| Prioridad | 1 |
| Precondición | La común, con el esquema ya inicializado |
| Duración | 0.04 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `docker inspect --format '{{.State.Health.Status}}' chdiego_db` | La salida es `healthy` |

**Resultado obtenido:** `healthy`. MySQL 8.0.46 sirve la base
`chocolate_diego`.

### H03 — Redis responde a PING

| | |
|---|---|
| Tipo | Sistema |
| Prioridad | 2 |
| Precondición | La común |
| Duración | 0.74 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `docker compose exec cache redis-cli ping` | La respuesta es `PONG` |

**Resultado obtenido:** `PONG`. Redis atiende sesiones, caché y la cola `fel`.

### H04 — La puerta de enlace responde

| | |
|---|---|
| Tipo | Sistema |
| Prioridad | 1 |
| Precondición | La común, con el puerto 8080 publicado |
| Duración | 0.02 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Abrir `http://localhost:8080/estado` | Se muestra `{"servicio":"gateway","estado":"ok"}` |

**Resultado obtenido:** `{"servicio":"gateway","estado":"ok"}`.

## Grupo 2.2 — Microservicios (H05–H11)

Los casos H05 a H08 comprueban el enrutamiento por dominio mediante la cabecera
`X-Servicio`, que cada microservicio agrega a su respuesta. Por eso funcionan
desde el primer arranque: verifican **a qué contenedor llegó la petición**, no
qué contestó.

### H05 — `/api/auth` se enruta al servicio auth

| | |
|---|---|
| Tipo | Sistema |
| Prioridad | 1 |
| Precondición | La común |
| Duración | 0.03 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `curl -I http://localhost:8080/api/auth/salud` | La respuesta incluye `X-Servicio: auth` |

**Resultado obtenido:** `X-Servicio: auth`.

### H06 — `/api/catalogo` se enruta al servicio catalogo

| | |
|---|---|
| Tipo | Sistema |
| Prioridad | 1 |
| Precondición | La común |
| Duración | 0.03 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `curl -I http://localhost:8080/api/catalogo/salud` | La respuesta incluye `X-Servicio: catalogo` |

**Resultado obtenido:** `X-Servicio: catalogo`.

### H07 — `/api/pedidos` se enruta al servicio pedidos

| | |
|---|---|
| Tipo | Sistema |
| Prioridad | 1 |
| Precondición | La común |
| Duración | 0.03 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `curl -I http://localhost:8080/api/pedidos/salud` | La respuesta incluye `X-Servicio: pedidos` |

**Resultado obtenido:** `X-Servicio: pedidos`.

### H08 — `/api/pagos` se enruta al servicio pagos

| | |
|---|---|
| Tipo | Sistema |
| Prioridad | 1 |
| Precondición | La común |
| Duración | 0.03 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `curl -I http://localhost:8080/api/pagos/salud` | La respuesta incluye `X-Servicio: pagos` |

**Resultado obtenido:** `X-Servicio: pagos`.

### H09 — Los servicios de dominio no se exponen al exterior

Prueba una decisión de arquitectura, no una función: los cuatro microservicios
solo son alcanzables desde dentro de la red interna.

| | |
|---|---|
| Tipo | Sistema |
| Prioridad | 2 |
| Precondición | La común |
| Duración | 0.16 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `docker port chdiego_auth` | No se muestra ningún puerto publicado |
| 2 | Repetir con `chdiego_catalogo`, `chdiego_pedidos` y `chdiego_pagos` | Ninguno publica puertos; solo la puerta de enlace es accesible desde fuera |

**Resultado obtenido:** los cuatro exponen `9000/tcp` solo dentro de la red
interna, sin asignación a ningún puerto del anfitrión. El único mapeo publicado
hacia el exterior es `8080 → 80` en el gateway. Evidencias 04 y 08.

### H10 — Los cuatro servicios tienen las extensiones de PHP requeridas

| | |
|---|---|
| Tipo | Sistema |
| Prioridad | 2 |
| Precondición | La común |
| Duración | 3.06 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `docker compose exec auth php -m` | La lista incluye `pdo_mysql`, `redis`, `bcmath` e `intl` |
| 2 | Repetir con `catalogo`, `pedidos` y `pagos` | Los cuatro muestran las mismas extensiones |

**Resultado obtenido:** los cuatro coinciden. Es el efecto de compartir una
imagen base común: si una extensión se agrega en la base, los cuatro la heredan
y nadie tiene que recordar replicarla.

### H11 — La caída de un servicio no afecta a los demás

El caso más importante de la suite: demuestra que la separación en
microservicios aguanta un fallo real, no solo que existe en el diagrama.

| | |
|---|---|
| Tipo | Sistema |
| Prioridad | 1 |
| Precondición | La común. El caso deja el sistema como lo encontró |
| Duración | 8.58 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `docker compose stop pagos` | El contenedor `chdiego_pagos` se detiene |
| 2 | Ejecutar `curl -I http://localhost:8080/api/pagos/salud` | La respuesta es `502 Bad Gateway` |
| 3 | Ejecutar `curl -I http://localhost:8080/api/auth/salud` | La respuesta **no** es 502: `auth` sigue atendiendo |
| 4 | Ejecutar `docker compose start pagos` y repetir el paso 2 | `pagos` vuelve a responder sin reiniciar la puerta de enlace |

**Resultado obtenido:** con `pagos` detenido, `auth` y `catalogo` respondieron
con normalidad y solo `/api/pagos` devolvió 502. Al volver a levantar `pagos`,
la ruta respondió de nuevo sin tocar el gateway, porque nginx resuelve los
nombres de los contenedores en cada petición y no al arrancar. Evidencia 13.

## Grupo 2.3 — Base de datos (H12–H13)

### H12 — El esquema corresponde al Octavo Documento

No comprueba comportamiento sino **correspondencia documental**. Si alguien
altera el esquema sin actualizar el documento, o al contrario, este caso falla.

| | |
|---|---|
| Tipo | Integración |
| Prioridad | 1 |
| Precondición | La común |
| Duración | 0.93 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `make verificar` | Las ocho cifras aparecen con resultado OK: 32 tablas, 274 columnas, 56 llaves foráneas, 28 CHECK, 5 funciones, 3 disparadores, 5 procedimientos, 10 vistas |
| 2 | Revisar la sección OBJETOS POR NOMBRE | Los 23 objetos aparecen como `[OK]` |
| 3 | Revisar la línea final | Dice: la implementación corresponde al documento |

**Resultado obtenido:**

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

Los 23 objetos con nombre en `[OK]`. Línea final: *la implementación
corresponde al documento*. Evidencia 11.

### H13 — Los catálogos base están cargados

| | |
|---|---|
| Tipo | Integración |
| Prioridad | 2 |
| Precondición | La común, con el volumen `chdiego_db_data` creado por primera vez para que corran los scripts de inicialización |
| Duración | 0.74 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Consultar `SELECT nombre, efecto FROM tipo_movimiento` | Existen `venta` con efecto resta y `devolucion` con efecto suma |
| 2 | Consultar `SELECT nombre_usuario FROM usuario` | Existe `admin` con rol Administrador |
| 3 | Consultar `SELECT COUNT(*) FROM zona_cobertura` | Hay zonas en Sololá, Chimaltenango, Sacatepéquez y Guatemala |

**Resultado obtenido:** los tres pasos conformes. Sin estos catálogos los casos
del flujo de venta no podrían ejecutarse, así que H13 es precondición efectiva
de H14 a H18.

## Grupo 2.4 — Flujo de venta (H14–H18)

**Tipo:** integración y aceptación. Los cinco casos forman **una sola secuencia
encadenada** y deben ejecutarse en orden: H14 prepara el inventario, H15 vende,
H16 comprueba la auditoría, H17 anula y H18 verifica que todo cuadró.

Escriben en la base de datos real, no contra objetos simulados: llaman a los
procedimientos almacenados donde vive la lógica de inventario y facturación.
Los datos que dejan son identificables por el prefijo `PH-`.

### H14 — Alta de producto, lote y entrada de inventario

| | |
|---|---|
| Tipo | Integración y aceptación |
| Prioridad | 1 |
| Precondición | H13 aprobado |
| Duración | 0.76 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Registrar un producto con `sp_registrar_producto` | Se devuelve el identificador del producto nuevo |
| 2 | Registrar un lote de 10 unidades con vencimiento a 90 días | El lote queda en estado disponible |
| 3 | Registrar la entrada con `sp_ajustar_inventario`, tipo compra | `fn_stock_disponible` del producto devuelve 10.000 |

**Resultado obtenido:** producto creado, lote disponible, existencia en 10.000
unidades.

### H15 — Venta a consumidor final descuenta existencia y genera DTE

| | |
|---|---|
| Tipo | Integración y aceptación |
| Prioridad | 1 |
| Precondición | H14 aprobado |
| Duración | 0.75 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Registrar una venta de 3 unidades sin cliente con `sp_registrar_venta` | La venta queda en estado completada con total 75.00 |
| 2 | Consultar la existencia del producto | `fn_stock_disponible` devuelve 7.000 |
| 3 | Consultar `documento_fel` de esa venta | Existe un documento en estado pendiente con NIT receptor CF |

**Resultado obtenido:** venta completada por 75.00 con el IVA calculado desde
`parametro_sistema.fel.tasa_iva`, existencia descontada a 7.000, y el DTE creado
en estado **pendiente**. Que quede pendiente y no certificado es el
comportamiento correcto: la certificación ante el certificador FEL-SAT se encola
para que la procese el contenedor `queue` en segundo plano, de modo que la caja
nunca espera a un servicio externo.

### H16 — La venta queda registrada en la bitácora

| | |
|---|---|
| Tipo | Integración |
| Prioridad | 2 |
| Precondición | H15 aprobado |
| Duración | 0.77 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Consultar `bitacora` filtrando por evento venta y el identificador de la venta | Existe el asiento generado por el disparador `trg_venta_bitacora_insert` |

**Resultado obtenido:** el asiento existe. Lo escribió el disparador de la base
de datos, no código de PHP: la auditoría no depende de que la aplicación se
acuerde de registrarla.

### H17 — La anulación restituye la existencia y anula el DTE

| | |
|---|---|
| Tipo | Integración y aceptación |
| Prioridad | 1 |
| Precondición | H15 aprobado |
| Duración | 0.74 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Anular la venta con `sp_anular_venta` usando el usuario `admin` | La venta pasa a estado anulada con fecha, usuario y motivo |
| 2 | Consultar la existencia del producto | `fn_stock_disponible` vuelve a 10.000 |
| 3 | Consultar el documento FEL de la venta | El documento pasa a estado anulado |
| 4 | Intentar anular la misma venta otra vez | El procedimiento rechaza la operación: la venta ya está anulada |

**Resultado obtenido:** los cuatro pasos conformes. La existencia regresó
exactamente a su valor inicial de 10.000. El paso 4 es el más valioso del caso:
comprueba el camino negativo, que el procedimiento se niega a anular dos veces
con un error de negocio identificable y no con un fallo genérico.

### H18 — El kardex cuadra después del ciclo completo

| | |
|---|---|
| Tipo | Integración y aceptación |
| Prioridad | 1 |
| Precondición | H17 aprobado |
| Duración | 0.74 s |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `make verificar` | La sección CUADRE DEL KARDEX dice que la existencia cuadra con la suma de movimientos |

**Resultado obtenido:** `[OK] La existencia cuadra con la suma de movimientos`.
Es el cierre de la secuencia: después de crear, vender, anular y restituir, el
inventario registrado coincide con la suma de sus movimientos. Evidencia 11.

---

# Suite 3 — Seguridad (S01–S11)

**Tipo:** seguridad · **Ejecución:** `make probar-seguridad` · **Duración:**
9 s · **11 de 11 aprobados**

**Precondición común a los 11 casos:** el sistema levantado y `chdiego_db` en
`healthy`. La suite crea dos usuarios temporales con prefijo `ps_` —uno con
estado bloqueado, uno con rol sin permiso de venta— y **los borra al terminar,
incluso si un caso falla**, mediante una trampa de salida del intérprete. No
modifica ningún usuario existente. Se verificó que al terminar la tabla
`usuario` vuelve a tener solo el `admin`.

## Grupo 3.1 — Control de acceso (S01–S05)

### S01 — Las rutas protegidas no responden sin sesión

| | |
|---|---|
| Prioridad | 1 |
| Precondición | La común, sin cookie de sesión |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Pedir `/panel` sin sesión | Redirige a `/ingreso`, no entrega el panel |
| 2 | Pedir `/punto-venta` sin sesión | Redirige a `/ingreso` |

**Resultado obtenido:** ambas redirigen a `/ingreso` con código 302.

### S02 — Un POST sin token CSRF es rechazado con 419

| | |
|---|---|
| Prioridad | 1 |
| Precondición | La común |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Enviar POST a `/ingreso` con credenciales válidas pero **sin** el campo `_token` | Código 419, la petición no se procesa |

**Resultado obtenido:** 419. Las credenciales eran correctas, y precisamente por
eso el caso sirve: demuestra que la protección contra falsificación de petición
actúa antes de evaluar la contraseña.

### S03 — El ingreso con credenciales válidas funciona

Control positivo. Sin este caso, S04 y S05 pasarían igual si el inicio de sesión
estuviera completamente roto.

| | |
|---|---|
| Prioridad | 1 |
| Precondición | La común, usuario `admin` con su contraseña documentada |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Obtener el token CSRF del formulario de `/ingreso` | Se obtiene un token de 40 caracteres |
| 2 | Enviar POST con token, usuario y contraseña correctos | Redirige a `/panel` |

**Resultado obtenido:** redirige a `/panel`.

### S04 — Una cuenta bloqueada no inicia sesión

| | |
|---|---|
| Prioridad | 1 |
| Precondición | La común, más el usuario `ps_bloqueado` con estado `bloqueado` y contraseña correcta |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Intentar iniciar sesión con `ps_bloqueado` y su contraseña **correcta** | Vuelve a `/ingreso`, no llega a `/panel` |

**Resultado obtenido:** vuelve a `/ingreso`. La contraseña era válida: lo niega
`App\Auth\UsuarioProvider` por el estado de la cuenta, antes de comparar el
hash.

### S05 — Sin el permiso `ventas.registrar` el punto de venta da 403

| | |
|---|---|
| Prioridad | 1 |
| Precondición | La común, más el usuario `ps_bodega` con rol *Personal de Bodega*, que no tiene ese permiso |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Iniciar sesión con `ps_bodega` | Entra y llega a `/panel` |
| 2 | Pedir `/punto-venta` con esa sesión | Código 403 |

**Resultado obtenido:** entra al panel y recibe 403 en el punto de venta. El
caso distingue las dos capas: la autenticación lo deja pasar, la autorización
por permiso lo detiene.

## Grupo 3.2 — Endurecimiento de la plataforma (S06–S08)

### S06 — La puerta de enlace no revela la versión del servidor

| | |
|---|---|
| Prioridad | 2 |
| Precondición | La común |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Leer la cabecera `Server` de la respuesta | Existe, y no contiene ningún número de versión |

**Resultado obtenido:** `Server: nginx`, sin versión. Es el efecto de
`server_tokens off`: la versión exacta es información gratuita para quien busca
una vulnerabilidad conocida.

### S07 — La puerta de enlace envía las cabeceras de seguridad

| | |
|---|---|
| Prioridad | 2 |
| Precondición | La común |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Leer las cabeceras de la respuesta | Están presentes `X-Frame-Options`, `X-Content-Type-Options` y `Referrer-Policy` |

**Resultado obtenido:** las tres presentes: `SAMEORIGIN`, `nosniff` y
`strict-origin-when-cross-origin`.

### S08 — Los microservicios no corren como root

| | |
|---|---|
| Prioridad | 1 |
| Precondición | La común |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Ejecutar `whoami` dentro de `auth`, `catalogo`, `pedidos` y `pagos` | Los cuatro responden `laravel` |

**Resultado obtenido:** los cuatro como `laravel`. El gateway queda fuera del
caso a propósito: la imagen oficial de nginx arranca su proceso maestro como
root y baja los trabajadores a un usuario sin privilegios, que es su diseño y no
algo que este proyecto deba alterar.

## Grupo 3.3 — Manejo de secretos (S09–S11)

### S09 — La aplicación no se conecta a MySQL como root

| | |
|---|---|
| Prioridad | 1 |
| Precondición | La común |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Leer `DB_USERNAME` dentro del contenedor de aplicación | Tiene valor y no es `root` |

**Resultado obtenido:** `chocolate`, una cuenta con permisos solo sobre su
propia base.

### S10 — Todas las contraseñas son hash bcrypt de 60 caracteres

| | |
|---|---|
| Prioridad | 1 |
| Precondición | La común |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Contar las filas de `usuario` cuyo `contrasena_hash` no empiece por `$2y$` o no mida 60 caracteres | El resultado es 0 |

**Resultado obtenido:** 0 filas incorrectas. El caso revisa **todas** las filas,
no solo el `admin`, de modo que un usuario agregado a mano con contraseña en
claro haría fallar la suite.

### S11 — Las imágenes no llevan el archivo `.env` horneado

| | |
|---|---|
| Prioridad | 1 |
| Precondición | La común, con las cuatro imágenes de microservicio construidas |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Arrancar cada imagen de microservicio y comprobar si existe `/var/www/html/.env` | No existe en ninguna de las cuatro |

**Resultado obtenido:** ausente en las cuatro. Los secretos entran por variables
de entorno al arrancar el contenedor, no en una capa de imagen que podría
publicarse en un registro.

---

# Suite 4 — Rendimiento (R01–R05)

**Tipo:** rendimiento · **Ejecución:** `make probar-rendimiento` ·
**Duración:** 2 s · **5 de 5 aprobados**

**Precondición común a los 5 casos:** el sistema levantado y estabilizado, sin
otra carga corriendo contra él. La carga se aplica con `curl` distribuido por
`xargs`, disponible en cualquier agente de integración continua sin instalar
nada.

**Parámetros de la carga:** 200 peticiones con 20 concurrentes por ruta, y 25
peticiones con 10 concurrentes por cada prefijo de dominio. Ajustables por las
variables `PETICIONES` y `CONCURRENCIA`.

Los umbrales son deliberadamente holgados, entre diez y treinta veces lo
medido, porque los agentes hospedados tienen la mitad de núcleos que el equipo
de desarrollo y comparten su máquina física. Un umbral ajustado produciría
fallos en el pipeline que no corresponden a ninguna regresión real.

## Grupo 4.1 — Carga sostenida (R01–R03)

### R01 — La puerta de enlace atiende la carga sin un solo error

El caso más importante de la suite: un 502 bajo esta carga significaría que la
puerta de enlace agota conexiones contra PHP-FPM antes de que el sistema esté
siquiera ocupado.

| | |
|---|---|
| Prioridad | 1 |
| Precondición | La común |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Lanzar 200 peticiones a `/estado` con 20 concurrentes | Las 200 se completan |
| 2 | Contar las que respondieron HTTP 200 | Las 200 |

**Resultado obtenido:** 200 de 200 con HTTP 200, ningún error.

### R02 — El percentil 95 de la puerta de enlace está bajo el umbral

| | |
|---|---|
| Prioridad | 2 |
| Precondición | R01 ejecutado, sus mediciones disponibles |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Calcular los percentiles 50 y 95 de los tiempos de respuesta de `/estado` | El percentil 95 queda por debajo de 1.000 s |

**Resultado obtenido:** percentil 50 en **0.003 s**, percentil 95 en
**0.008 s**, contra un umbral de 1.000 s. Mide la puerta de enlace sola, sin
PHP de por medio.

### R03 — El percentil 95 de una ruta con PHP y base está bajo el umbral

| | |
|---|---|
| Prioridad | 2 |
| Precondición | La común |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Lanzar 200 peticiones a `/api/auth/salud` con 20 concurrentes | Las 200 responden HTTP 200 |
| 2 | Calcular los percentiles 50 y 95 | El percentil 95 queda por debajo de 3.000 s |

**Resultado obtenido:** 200 de 200 con HTTP 200, percentil 50 en **0.079 s** y
percentil 95 en **0.102 s**, contra un umbral de 3.000 s. Esta ruta sí atraviesa
PHP-FPM y consulta la base y Redis, así que es la cifra que representa al
sistema completo.

## Grupo 4.2 — Aislamiento bajo carga (R04–R05)

### R04 — El enrutamiento por dominio se mantiene bajo carga

La separación por dominio tiene que sobrevivir a la presión, no solo al reposo.

| | |
|---|---|
| Prioridad | 1 |
| Precondición | La común |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Lanzar 25 peticiones con 10 concurrentes contra cada uno de los cuatro prefijos de dominio | Las respuestas de cada prefijo traen **un solo** valor de `X-Servicio`, y es el del microservicio que le corresponde |

**Resultado obtenido:** los cuatro prefijos siguen atendidos cada uno por su
propio microservicio. Si la puerta de enlace mezclara el enrutamiento bajo
presión, este caso lo detectaría.

### R05 — Ningún contenedor desborda su memoria tras la carga

| | |
|---|---|
| Prioridad | 2 |
| Precondición | R01 a R04 ejecutados, para medir después de la carga y no en reposo |
| Resultado | **Aprobado** |

| # | Acción | Resultado esperado |
|---|---|---|
| 1 | Leer el consumo de memoria de cada contenedor | Ninguno supera 512 MB |

**Resultado obtenido:** el máximo es `chdiego_db` con **444 MB**. Los
contenedores de aplicación quedan entre 13 y 56 MB. Es un techo de cordura, no
un presupuesto de capacidad.

---

# Cobertura y análisis

## Cobertura por componente

| Componente | Casos que lo cubren |
|---|---|
| Puerta de enlace (nginx) | H04–H08, H11, S01, S02, S06, S07, R01, R02, R04 |
| Microservicio `auth` | H05, H09, H10, H11, H13, H16, S01–S05, S08, R03, R04 |
| Microservicio `catalogo` | H06, H09, H10, H14, H17, H18, S08, R04, U09–U12 |
| Microservicio `pedidos` | H07, H09, H10, H13, S08, R04 |
| Microservicio `pagos` | H08–H11, H15, H17, S05, S08, R04, U01–U08 |
| Contenedor `queue` | H01, H15, U14–U17 |
| Contenedor `scheduler` | H01 |
| MySQL | H01, H02, H12–H18, S09, S10, U09–U13 |
| Redis | H01, H03 |
| Procedimientos almacenados | H14, H15, H17, U01–U05 |
| Funciones de la base | H14, H15, H17 |
| Disparadores de bitácora | H16 |
| Red interna y aislamiento | H09, S08, R04 |
| Imágenes de contenedor | H10, S08, S11 |
| Clases de PHP con lógica propia | U01–U17 |

Los nueve contenedores quedan cubiertos por al menos un caso.

## Camino negativo: los casos que prueban que el sistema falla como debe

Ocho casos no comprueban que algo funcione, sino que **se niegue
correctamente**. Son los que más peso tienen en una revisión, porque un sistema
que concede lo que debe negar es peor que uno que no funciona.

| Caso | Fallo o abuso provocado a propósito | Comportamiento correcto verificado |
|---|---|---|
| U02 | Error de infraestructura disfrazado de error de base | No se traduce a error de negocio: sigue propagándose |
| U17 | Certificador FEL configurado para fallar | Lanza excepción, para que la cola pueda reintentar |
| H09 | Intento de alcanzar un microservicio desde fuera de la red | No hay puerto publicado que lo permita |
| H11 | Detención deliberada del contenedor `pagos` | Solo `/api/pagos` devuelve 502; el resto sigue atendiendo, y `pagos` se recupera sin reiniciar el gateway |
| H17 paso 4 | Anulación de una venta ya anulada | El procedimiento rechaza con un error de negocio identificable |
| S02 | POST con credenciales correctas pero sin token CSRF | Rechazado con 419 antes de evaluar la contraseña |
| S04 | Inicio de sesión de cuenta bloqueada con contraseña correcta | Negado por el estado de la cuenta |
| S05 | Usuario autenticado sin el permiso requerido | 403 en el punto de venta, aunque el panel sí le abre |

## Casos manuales para Azure Test Plans

`tests/casos/casos-de-prueba-azure.csv` contiene los casos escritos como pasos
manuales, con las columnas que Azure DevOps espera: *ID*, *Work Item Type*,
*Title*, *Test Step*, *Step Action*, *Step Expected*, *Priority* y *State*.

Importación: *Test Plans → New Test Plan → ⋮ → Import test cases from CSV*. Los
casos quedan creados como elementos de trabajo de tipo *Test Case*. Para
ejecutar uno a mano: *Run → Run for web application*, que muestra los pasos uno
por uno y permite marcarlos como aprobados o fallidos.

Para demostrar la trazabilidad en la revisión basta con abrir un caso en Test
Plans —H11 y S05 son los más ilustrativos— y luego el mismo identificador
aprobado en la pestaña *Tests* de la ejecución del pipeline, o en
`docs/devops1/evidencias/informes/reporte-de-pruebas.html`.
