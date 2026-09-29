# Plan de Pruebas

**Proyecto:** Artesanal Chocolate Diego — Plataforma de gestión
**Entrega:** DEVOPS 2 — Integración continua, entrega continua y plan de pruebas
**Curso:** Seminario de Tecnologías de Información — código 1900-047
**Catedrático:** Ing. Erick Roberto Aguilar Juárez
**Grupo:** 8
**Responsable de pruebas:** Ricardo Ismael Pérez Ajanel — carné 0900-23-22081
**Versión del plan:** 2.0 — 28 de septiembre de 2026

---

## 1. Propósito

Este documento establece cómo se verifica que la plataforma de Artesanal
Chocolate Diego funciona, y cómo se demuestra que sigue funcionando después de
cada cambio. Cumple tres funciones concretas:

1. **Define el contrato de calidad de la entrega.** Fija qué se prueba, con qué
   criterio se declara aprobada una ejecución, y qué queda deliberadamente
   fuera. Nadie tiene que adivinar si una entrega está lista.
2. **Hace la verificación repetible por alguien más.** Cada caso tiene un
   identificador, precondiciones y pasos ejecutables. Un integrante distinto
   del que escribió la prueba puede correrla y obtener el mismo resultado.
3. **Conecta el modelo de datos documentado con el sistema construido.** La
   matriz de trazabilidad de la sección 13 liga cada requerimiento del negocio
   con los casos que lo respaldan y la evidencia que lo prueba.

La entrega anterior definió el modelo relacional: 32 tablas, 274 columnas, 56
llaves foráneas y 28 restricciones CHECK, más 5 funciones, 3 disparadores, 5
procedimientos almacenados y 10 vistas. Este plan no lo cuestiona: verifica que
la implementación le corresponda exactamente.

Por eso el plan tiene una característica poco común: uno de sus casos (H12) no
comprueba comportamiento sino **correspondencia documental**. Si alguien altera
el esquema sin actualizar el documento, o al revés, el caso falla. Ese es el
control de trazabilidad de la entrega.

## 2. Objetivos

1. Verificar que las clases de la aplicación cumplen sus contratos de forma
   aislada, sin depender de la base de datos ni de la red.
2. Verificar que la composición de nueve servicios levanta completa y que cada
   contenedor queda en estado saludable.
3. Verificar que la puerta de enlace es el único punto de entrada y que entrega
   cada prefijo de ruta al microservicio de dominio correcto.
4. Verificar que los microservicios de dominio no están expuestos al exterior
   de la red interna.
5. Verificar que la caída de un microservicio no interrumpe a los demás, y que
   el servicio caído se recupera sin reiniciar la puerta de enlace.
6. Verificar que el esquema implementado en MySQL corresponde cifra por cifra y
   objeto por objeto al Octavo Documento de Proyecto.
7. Verificar el flujo de negocio crítico de punta a punta: alta de producto y
   lote, entrada de inventario, venta con descuento de existencia, generación
   del documento FEL, anulación y restitución, con el kardex cuadrado al final.
8. Verificar que el control de acceso niega lo que debe negar: sesión ausente,
   cuenta bloqueada, permiso insuficiente y petición sin token.
9. Establecer una línea base de rendimiento medida, y detectar una regresión de
   orden de magnitud contra ella.
10. Dejar cada ejecución registrada en un formato que los dos sistemas de
    integración continua publiquen automáticamente, y en un reporte HTML
    legible sin herramientas.

## 3. Alcance

### 3.1 Dentro del alcance

| Área | Qué se prueba |
|---|---|
| Clases de la aplicación | Traducción de errores de procedimiento, excepciones de negocio, mapeo de modelos contra el esquema, adaptador FEL |
| Infraestructura de contenedores | Composición, arranque, estado de salud, red interna, volúmenes, consumo de recursos |
| Arquitectura de microservicios | Enrutamiento por dominio, aislamiento de puertos, paridad de extensiones de PHP, tolerancia a fallos |
| Base de datos | Correspondencia del esquema con el documento, carga de catálogos base, cuadre del kardex |
| Lógica de negocio en la base | Los 5 procedimientos almacenados, las funciones de existencia y los disparadores de bitácora |
| Flujo de venta | Ciclo completo registrar → descontar → facturar → anular → restituir |
| Control de acceso | Autenticación, bloqueo de cuenta, permisos por módulo y acción, token contra falsificación de petición |
| Endurecimiento | Cabeceras de seguridad, ocultamiento de versión, usuario sin privilegios, manejo de secretos |
| Rendimiento | Latencia bajo carga concurrente, integridad del enrutamiento bajo carga, techo de memoria |
| Repositorio e integración continua | Historial versionado, sincronía con el remoto, ejecución de los dos pipelines |

### 3.2 Fuera del alcance de esta entrega

| Excluido | Motivo |
|---|---|
| Certificación FEL contra el certificador real de la SAT | El certificador no está contratado. Se prueba contra un adaptador de simulación configurable, con reintentos y rechazo reales, y el adaptador tiene sus propias pruebas unitarias (U14–U17). |
| Despliegue efectivo en Microsoft Azure | Los recursos de nube no están aprovisionados. La etapa de Despliegue del pipeline está escrita y condicionada a la rama `main`, a la espera de esos recursos. Ver `docs/nube/despliegue-azure.md`. |
| Pruebas de interfaz automatizadas con un navegador | El frontend es Blade con Tailwind, sin framework de JavaScript ni lógica de cliente que justifique automatizar un navegador. La interfaz se verifica de forma manual y exploratoria, documentada en la sección 5.4. |
| Pruebas de penetración | Fuera del temario de la entrega. Sí se verifican el control de acceso, la exposición de puertos, las cabeceras de seguridad y el manejo de secretos, con once casos automatizados (S01–S11). |
| Dimensionamiento de capacidad | Las pruebas de rendimiento establecen una línea base y detectan regresiones, no determinan cuántos usuarios simultáneos soporta la producción. Eso requiere el hardware de producción, que todavía no existe. |
| Pruebas de recuperación ante desastre | No hay entorno de producción del cual recuperarse. Sí se prueba la recuperación de un microservicio caído (H11). |

## 4. Tipos de prueba

Los seis tipos que contempla la entrega, con su cobertura real. Ninguna fila
queda sin casos.

| Tipo | Qué verifica | Casos | Cantidad | Automatización |
|---|---|---|---|---|
| **Unitarias** | Clases de PHP en aislamiento, sin base de datos ni red | U01–U17 | 17 casos, 39 ejecuciones | PHPUnit 10.5 |
| **Integración** | Que la aplicación y MySQL se entienden: esquema, catálogos, procedimientos almacenados, disparadores | H12–H18 | 7 | Bash contra MySQL real |
| **Sistema** | El stack completo levantado: contenedores, red, enrutamiento, tolerancia a fallos | H01–H11 | 11 | Bash contra el sistema en ejecución |
| **Aceptación** | Que el flujo que el negocio pidió ocurre de punta a punta y cuadra | H14–H18, más el recorrido manual de la sección 5.4 | 5 y un recorrido manual | Mixta |
| **Seguridad** | Control de acceso, endurecimiento de la plataforma y manejo de secretos | S01–S11 | 11 | Bash contra el sistema en ejecución |
| **Rendimiento** | Latencia bajo carga, integridad del enrutamiento bajo carga, techo de memoria | R01–R05 | 5 | Bash con concurrencia por `xargs` |

**Nota sobre el solapamiento entre aceptación e integración.** Los casos H14 a
H18 cuentan en ambos tipos, y no es un error de conteo: son integración porque
ejercitan los procedimientos almacenados contra MySQL, y son aceptación porque
el recorrido que describen —registrar una venta, descontar inventario, generar
la factura, anularla, restituir— es exactamente el criterio que el negocio
pidió. Contarlos dos veces refleja que una misma prueba responde a dos
preguntas distintas. El total de casos únicos es 51.

**Recuento total:** 51 casos documentados, 73 ejecuciones. La diferencia viene
de los proveedores de datos de PHPUnit: los casos U09 a U12 se ejecutan una vez
por cada columna generada o cada modelo de su tabla, y cuentan como un solo
caso documentado cada uno.

## 5. Estrategia de pruebas

### 5.1 Herramientas elegidas, y por qué no son pytest y Selenium

El enunciado sugiere pytest con Selenium. Este proyecto usa **PHPUnit** para
las pruebas unitarias y **Bash con curl** para las de sistema, seguridad y
rendimiento. La sustitución es deliberada, y el enunciado la permite al dejar
libre el lenguaje de programación:

| Sugerido | Elegido | Razón |
|---|---|---|
| pytest | PHPUnit 10.5 | La aplicación es Laravel 10 sobre PHP 8.1. PHPUnit ya viene instalado con el framework, corre dentro del mismo contenedor que el código y no exige agregar un intérprete de Python a las imágenes solo para probar. Con pytest habría que probar PHP desde fuera, sin acceso a las clases. |
| Selenium | Verificación manual de la interfaz | Selenium automatiza un navegador. El frontend de este sistema es Blade renderizado en el servidor, con Tailwind y sin framework de JavaScript: no hay estado de cliente ni comportamiento asíncrono que un navegador automatizado descubra y una petición HTTP no. Automatizarlo aquí agregaría una dependencia frágil sin cubrir ningún riesgo real. |
| Reporte HTML de pytest | `scripts/reporte-pruebas.py` | Genera el mismo artefacto —un HTML autocontenido con todos los casos, su estado y su duración— a partir de los informes JUnit de las cuatro suites. Ver sección 9.3. |

Lo que sí se conserva del enfoque sugerido es **el formato de salida**: las
cuatro suites emiten JUnit XML, el formato estándar que Azure DevOps y GitHub
Actions leen de forma nativa, igual que harían con pytest.

### 5.2 Niveles y su orden de ejecución

Del más rápido y aislado al más lento e integrado. El orden importa: si las
unitarias fallan, no tiene sentido interpretar un fallo de sistema.

| Orden | Nivel | Qué cubre | Cómo se ejecuta | Duración |
|---|---|---|---|---|
| 1 | Unitarias | Clases en aislamiento, en su propia imagen | `make probar-unitarias` | menos de 1 s |
| 2 | Humo, integración y sistema | Stack completo y base de datos | `make probar` | 20 s |
| 3 | Seguridad | Control de acceso y endurecimiento | `make probar-seguridad` | 9 s |
| 4 | Rendimiento | Carga concurrente | `make probar-rendimiento` | 2 s |
| — | Todo, con reporte | Las cuatro suites y el HTML | `make probar-todo` | poco más de 30 s |

### 5.3 Principio rector: la prueba escribe en la base real

Las pruebas de integración y aceptación (H14–H18) **no usan datos falsos en
memoria**: llaman a los procedimientos almacenados reales contra MySQL real. Un
producto con código que empieza por `PH-`, su lote, su venta y su anulación
quedan escritos. Se eligió así deliberadamente: probar el flujo contra objetos
simulados no demostraría nada sobre los procedimientos almacenados, que es
donde vive la lógica de inventario y facturación de este sistema.

La contrapartida está controlada. Los datos son identificables por el prefijo
`PH-`, H18 verifica que el kardex queda cuadrado después del ciclo, y las
pruebas de seguridad crean sus dos usuarios temporales con el prefijo `ps_` y
los borran al terminar, incluso si una prueba falla, mediante una trampa de
salida del intérprete.

Las pruebas unitarias son lo contrario, y también a propósito: no tocan la base
de datos ni la red. Construyen la excepción de MySQL a mano y reemplazan el
almacenamiento por uno falso, de modo que corren en menos de un segundo y se
pueden ejecutar sin levantar el sistema completo.

### 5.4 Pruebas manuales de interfaz y experiencia de uso

Lo que no se automatiza se recorre a mano, y queda documentado como recorrido,
no como intuición. `tests/api/peticiones.http` contiene las peticiones a la
puerta de enlace para ejecutarlo desde el editor.

Recorrido verificado de punta a punta:

iniciar sesión con `admin` → abrir turno de caja → buscar producto → agregar al
carrito → confirmar la venta → comprobar que el kardex cuadra → generar el
comprobante → anular la venta → comprobar que el kardex vuelve a cuadrar y la
existencia regresa a su valor inicial.

Aspectos que solo la revisión manual cubre: legibilidad del comprobante,
claridad de los mensajes de error de negocio que ve el cajero, y que la
navegación del panel corresponda a los permisos del rol con el que se entró.

### 5.5 Automatización y triple ejecución

Cada suite existe una sola vez, en un único archivo, y se ejecuta en tres
lugares con el mismo código:

1. En el equipo del desarrollador, con los objetivos de `make`.
2. En GitHub Actions, en cada `push` a `main` o `develop` y en cada *pull
   request* a `main` (`.github/workflows/ci.yml`).
3. En Azure Pipelines, en la etapa *Pruebas* (`azure-pipelines.yml`).

En ambos pipelines cada suite corre en su propio paso, con la marca de
continuar ante error, para que una suite fallida no oculte el resultado de las
otras tres. El veredicto lo dan la publicación de resultados y el reporte
final, no el primer paso que falla.

## 6. Parámetros del sistema

### 6.1 Versiones del sistema bajo prueba

| Componente | Versión |
|---|---|
| Aplicación | Laravel 10 |
| Lenguaje | PHP 8.1.34 (FPM), imagen base Alpine Linux 3.21.5 |
| Base de datos | MySQL 8.0.46 |
| Caché, sesiones y colas | Redis 7 (Alpine) |
| Puerta de enlace | nginx 1.27 (Alpine) |
| Bandeja de correo de prueba | Mailpit |
| Autenticación | Laravel Sanctum |
| Frontend | Blade con Tailwind CSS, compilado con Vite |
| Versión de la aplicación en las imágenes | `dev` |

### 6.2 Versiones de las herramientas de prueba

| Herramienta | Versión | Uso |
|---|---|---|
| PHPUnit | 10.5.64 | Pruebas unitarias |
| Bash | 5.3.9 | Suites de sistema, seguridad y rendimiento |
| curl | 8.18.0 | Peticiones HTTP y medición de latencia |
| Python | 3.14.7 | Generación del reporte HTML |
| Git | 2.55.0 | Control de versiones |
| hadolint | última | Revisión de los seis Dockerfiles en integración continua |
| shellcheck | última | Revisión de los scripts en integración continua |

### 6.3 Sistema operativo y motor de contenedores

| Entorno | Sistema operativo | Motor de contenedores |
|---|---|---|
| Equipo de desarrollo | Fedora Linux 44, núcleo 7.2.7, SELinux en modo obligatorio | Podman 5.8.7 sin privilegios de administrador, con podman-compose 1.6.0 |
| GitHub Actions | Ubuntu (imagen `ubuntu-latest`) | Docker Engine |
| Azure Pipelines | Ubuntu (imagen `ubuntu-latest`) | Docker Engine |

**Nota sobre Podman en el equipo de desarrollo.** La máquina donde se
capturaron las evidencias usa Podman, no Docker Engine. Podman implementa la
misma interfaz de línea de comandos y el mismo formato de composición, y por
eso la evidencia 01 reporta `podman version 5.8.7` donde diría `Docker version`
en otra máquina. El proyecto está escrito para Docker Engine —es lo que
ejecutan los dos sistemas de integración continua, y donde las mismas suites
también pasan—; los ajustes que Podman requiere (remapeo de identificadores de
usuario, dirección del resolvedor de nombres interno) viven aislados en
`docker-compose.podman-local.yml`, que no se versiona y no afecta a ninguna
otra máquina. Se documenta aquí y no se disimula, porque un lector de la
evidencia 01 lo va a notar.

### 6.4 Hardware

| Parámetro | Equipo de desarrollo | Agentes de integración continua |
|---|---|---|
| Procesador | AMD Ryzen 3 5300U, 4 núcleos y 8 hilos | 2 núcleos virtuales (agente hospedado estándar) |
| Memoria | 11 GiB | 7 GiB |
| Almacenamiento | NVMe, 929 GB con 640 GB libres | SSD, 14 GB de espacio de trabajo |

Las cifras de rendimiento de la sección 14 corresponden al equipo de
desarrollo. Los umbrales del plan son holgados justamente porque los agentes
hospedados tienen la mitad de núcleos y comparten su máquina física: un umbral
ajustado al equipo de desarrollo produciría fallos en el pipeline que no
corresponden a ninguna regresión real.

### 6.5 Navegador

| Parámetro | Valor |
|---|---|
| Navegador de las pruebas manuales | Mozilla Firefox 156.0.1 |
| Resolución de trabajo | 1920 × 1080 |
| Pruebas automatizadas de navegador | Ninguna. Ver sección 5.1 |

Las suites automatizadas no usan navegador: hablan HTTP directo con la puerta
de enlace mediante curl. El navegador solo interviene en el recorrido manual de
la sección 5.4.

## 7. Entorno de pruebas

### 7.1 Componentes bajo prueba

| Contenedor | Imagen | Rol | Puerto publicado |
|---|---|---|---|
| `chdiego_gateway` | `chocolate-diego/gateway` | Único punto de entrada | 8080 → 80 |
| `chdiego_auth` | `chocolate-diego/auth` | Seguridad: usuarios, roles, permisos, bitácora | ninguno |
| `chdiego_catalogo` | `chocolate-diego/catalogo` | Catálogo e inventario por lotes | ninguno |
| `chdiego_pedidos` | `chocolate-diego/pedidos` | Clientes, pedidos, entregas, suscripciones | ninguno |
| `chdiego_pagos` | `chocolate-diego/pagos` | Punto de venta y FEL | ninguno |
| `chdiego_queue` | `chocolate-diego/pagos` | Worker de la cola `fel` | ninguno |
| `chdiego_scheduler` | `chocolate-diego/catalogo` | Tareas programadas | ninguno |
| `chdiego_db` | `mysql:8.0` | Base de datos, 32 tablas | 3307 → 3306 |
| `chdiego_cache` | `redis:7-alpine` | Sesiones, caché y colas | 6380 → 6379 |

Que los cinco contenedores de aplicación no tengan puerto publicado no es un
detalle de configuración: es el objeto de los casos H09 y S08.

### 7.2 Datos de prueba

| Origen | Contenido |
|---|---|
| `docker/mysql/init/01_esquema.sql` | Las 32 tablas y los 23 objetos de lógica. Única fuente de verdad del esquema. |
| `docker/mysql/init/02_rutinas.sql` | Funciones, disparadores y procedimientos almacenados. |
| `docker/mysql/init/03_datos_iniciales.sql` | Catálogos base: tipos de movimiento, métodos de pago, zonas de cobertura, usuario `admin` con rol Administrador. |
| Generados por la suite de sistema | Producto con prefijo `PH-`, su lote, su venta y su anulación (H14–H18). |
| Generados por la suite de seguridad | Dos usuarios con prefijo `ps_`: uno con estado bloqueado y uno con rol sin permiso de venta. Se borran al terminar. |
| Construidos en memoria por las unitarias | Excepciones de MySQL simuladas y un documento FEL sin persistir. |

Los scripts de inicialización corren **únicamente cuando se crea el volumen**
`chdiego_db_data`. Si se cambian credenciales o el esquema, hay que recrear el
volumen (`make limpiar`, destructivo) para que vuelvan a aplicarse.

## 8. Criterios de entrada, salida y suspensión

### 8.1 Criterios de entrada

- La imagen base y las cuatro imágenes de microservicio están construidas
  (`make construir`).
- El archivo `.env` existe y `APP_KEY` tiene valor.
- Los nueve servicios están levantados (`make arriba`).
- `chdiego_db` reporta `healthy`. MySQL tarda en inicializar el esquema, y las
  pruebas de base de datos fallarían por arranque, no por defecto real. Ambos
  pipelines esperan hasta 200 segundos por este estado.

Las pruebas unitarias son la excepción: no requieren ningún servicio
levantado, solo que exista la imagen base. Corren en una imagen propia
(`docker/pruebas/Dockerfile`) que agrega las dependencias de desarrollo, porque
la imagen de producción se instala con `--no-dev` y PHPUnit es una de ellas.

### 8.2 Criterios de salida

La ejecución se considera aprobada cuando:

- Las 73 ejecuciones de las cuatro suites pasan y ninguna falla. Cada script
  devuelve 0 si todo pasa y 1 si algo falla, y el generador del reporte
  devuelve 1 si encuentra cualquier fallo en cualquiera de los cuatro informes.
- Las ocho cifras del esquema coinciden con el Octavo Documento y los 23
  objetos con nombre aparecen como `[OK]`.
- El kardex cuadra al terminar el ciclo de venta.
- Ningún caso de seguridad concede lo que debe negar.
- Las mediciones de latencia quedan por debajo de sus umbrales, y ningún
  contenedor supera su techo de memoria.
- El reporte HTML queda generado, y las 16 evidencias técnicas más la carpeta
  `informes/` quedan escritas en `docs/devops1/evidencias/`.

### 8.3 Criterios de suspensión y reanudación

Se suspende la ejecución si `chdiego_db` no alcanza el estado `healthy`, si la
construcción de imágenes falla, o si las pruebas unitarias fallan: en los tres
casos los resultados de las suites superiores no serían informativos. Se
reanuda una vez corregida la causa, y se ejecuta la suite completa desde el
inicio, no solo el caso que falló.

## 9. Ejecución del plan de pruebas

### 9.1 Ejecución completa

```bash
make arriba        # levanta los nueve servicios
make probar-todo   # las cuatro suites y el reporte HTML
make verificar     # verificación de esquema y cuadre del kardex
make evidencias    # genera las 16 evidencias técnicas
```

`make probar-todo` ejecuta las cuatro suites en orden, deja que todas corran
aunque una falle, y termina generando el reporte. Toma poco más de 30 segundos.
El caso más lento es H11, con unos 9 segundos, porque detiene y vuelve a
levantar el contenedor de `pagos` a propósito.

### 9.2 Ejecución por suite

```bash
make probar-unitarias    # U01–U17, PHPUnit en la imagen de pruebas
make probar              # H01–H18, sistema e integración
make probar-seguridad    # S01–S11
make probar-rendimiento  # R01–R05
make reporte             # regenera el HTML con lo que haya
```

### 9.3 Registro de resultados

Cada suite deja su informe en formato JUnit XML, y el generador los une en un
solo HTML autocontenido:

| Archivo | Contenido |
|---|---|
| `tests/resultados/resultados-unitarias.xml` | 39 ejecuciones de PHPUnit |
| `tests/resultados/resultados-humo.xml` | 18 casos de sistema e integración |
| `tests/resultados/resultados-seguridad.xml` | 11 casos de seguridad |
| `tests/resultados/resultados-rendimiento.xml` | 5 casos de rendimiento |
| `tests/resultados/linea-base-rendimiento.txt` | Mediciones crudas de latencia y memoria |
| `tests/resultados/reporte-de-pruebas.html` | Reporte único, legible en cualquier navegador sin conexión |

`tests/resultados/` está en `.gitignore` por ser salida generada, así que
`make evidencias` copia el reporte, los cuatro informes JUnit y la línea base a
`docs/devops1/evidencias/informes/`, que sí se versiona. La copia es la que
viaja con la entrega; la original es la de trabajo.

El reporte HTML muestra el veredicto global, un resumen por tipo de prueba, y
el detalle caso por caso con su grupo y su duración. Cuando un caso falla, el
reporte incluye el mensaje de fallo debajo de la fila correspondiente, de modo
que sirve tanto de captura de ejecución exitosa como de ejecución fallida. Ese
comportamiento con fallos se verificó de forma explícita, y no solo por
inspección del código.

Azure DevOps publica los cuatro informes juntos en la pestaña *Tests* de la
ejecución, con el identificador de cada caso tal como aparece en este plan, y
el reporte HTML queda como artefacto junto a las evidencias.

### 9.4 Ejecución en Azure Test Plans

`tests/casos/casos-de-prueba-azure.csv` contiene los casos escritos como pasos
manuales, con la misma numeración que las pruebas automáticas. Esa numeración
compartida **es** la trazabilidad entre Azure Test Plans y Azure Pipelines: lo
que el plan describe como pasos manuales es exactamente lo que el pipeline
ejecuta.

Importación: *Test Plans → New Test Plan → ⋮ → Import test cases from CSV*, con
las columnas *Title*, *Test Step*, *Step Action*, *Step Expected*, *Priority* y
*State*.

## 10. Gestión de defectos

### 10.1 Procedimiento

Un fallo de cualquier suite detiene la etapa del pipeline. El defecto se
registra como elemento de trabajo en Azure Boards, vinculado al caso de prueba
que lo detectó, y no se cierra hasta que las cuatro suites vuelven a pasar en el
pipeline, no solo en el equipo de quien corrigió.

### 10.2 Clasificación de severidad

| Severidad | Definición | Acción |
|---|---|---|
| Bloqueante | El sistema no levanta, el esquema no corresponde al documento, o el control de acceso concede lo que debe negar | Se detiene el avance de la entrega |
| Alta | Un microservicio no responde, el flujo de venta descuadra el inventario, o una prueba unitaria de contrato falla | Se corrige antes del siguiente commit a `main` |
| Media | Un caso falla sin afectar el flujo de venta, el esquema ni el control de acceso | Se registra y se corrige en el sprint |
| Baja | Ruido en registros, formato de salida, documentación | Se acumula para una revisión posterior |

### 10.3 Defectos reales encontrados y corregidos

Se listan porque son la evidencia de que las pruebas sirvieron para algo, no
solo de que pasaron.

| # | Defecto | Severidad | Detectado por | Corrección |
|---|---|---|---|---|
| D-01 | Con Redis caído, la ruta de salud devolvía HTML 500 en vez de JSON 503: el middleware `throttle:api` usa el mismo almacén de caché que la ruta diagnostica, y la petición nunca llegaba al controlador | Alta | Verificación de rutas de salud | Se excluyó `ThrottleRequests` de las cuatro rutas `/salud` |
| D-02 | El hash bcrypt del usuario `admin` en `03_datos_iniciales.sql` no correspondía a la contraseña que el propio comentario declaraba | Bloqueante | Prueba de inicio de sesión real | Se regeneró el hash |
| D-03 | El `.env` de la raíz sobrescribía `src/.env` con `APP_KEY` vacío, y la aplicación fallaba con `MissingAppKeyException`: `env_file` inyecta variables reales que `phpdotenv` no sobrescribe | Bloqueante | Arranque de la aplicación | Se recortó el `.env` de la raíz a solo `APP_VERSION` |
| D-04 | El volumen `app_public`, pensado para producción, se montaba sobre `./src/public` en desarrollo, congelaba esa carpeta y rompía `@vite()` en toda vista Blade | Alta | Recorrido manual del punto de venta | Se agregó el montaje de `./src/public` en `docker-compose.override.yml` |
| D-05 | La tabla `notificacion` no tenía valor de enumeración para la alerta de DTE rechazado, aunque las otras tres alertas sí estaban contempladas | Media | Prueba de la cola FEL | Se agregó `dte_rechazado` a `01_esquema.sql` |
| D-06 | `notificacion` exige destinatario por restricción CHECK: no existía forma de emitir una alerta "al sistema" | Media | Prueba de la cola FEL | Se resolvió con una notificación a cada usuario activo con el permiso relevante |
| D-07 | Declarar `public $queue` en la clase de un Job es error fatal de PHP, no advertencia: `Illuminate\Bus\Queueable` ya declara esa propiedad | Alta | Ejecución del worker de colas | Se reemplazó por `$this->onQueue()` en el constructor |
| D-08 | Envolver las llamadas a procedimientos almacenados en `DB::transaction()` confirmaba de forma implícita y prematura la transacción que el procedimiento ya había abierto | Alta | Prueba del ciclo de venta y anulación | Se eliminó la transacción de Laravel alrededor de esas llamadas |
| D-09 | Las evidencias técnicas incluían secuencias de color y el aviso del proveedor externo de composición, ilegibles en un editor de texto | Baja | Revisión de entregables | Se agregó un filtro de limpieza en `scripts/evidencias.sh` |
| D-10 | La evidencia del repositorio reportaba la sincronía con el remoto sin el identificador del commit: `git rev-parse --short` acepta una sola revisión y fallaba en silencio al recibir dos | Media | Revisión de la evidencia 15 | Se separó en dos invocaciones |
| D-11 | La misma evidencia listaba `push` y `pull_request` como trabajos de GitHub Actions: son disparadores, y el patrón de búsqueda no distinguía el nivel de anidamiento | Baja | Revisión de la evidencia 15 | Se reemplazó por una lectura de los hijos de `jobs:` |
| D-12 | El reporte HTML escribía "1 pruebas fallaron" cuando fallaba una sola | Baja | Prueba deliberada del camino de fallo del reporte | Se agregó la concordancia de número |
| D-13 | **La imagen nunca contuvo `vendor/autoload.php`.** `docker/base/Dockerfile` instalaba las dependencias con `--no-autoloader` y nada ejecutaba `composer dump-autoload` después, así que todo proceso PHP moría en la primera línea. En desarrollo no se notaba porque `docker-compose.override.yml` monta `./src` encima, y el equipo sí tiene un `vendor` completo | Bloqueante | Registros de integración continua de la corrida del 2026-09-22 (`auth` devolvía 500) | Se agregó `composer dump-autoload --optimize --no-dev` en la etapa 2, después de copiar `src/` |
| D-14 | La imagen tampoco llevaba los activos de Vite: `.dockerignore` excluye `src/public/build` y nada los compilaba dentro de la imagen, así que `@vite()` lanzaba excepción y ninguna vista Blade se servía | Bloqueante | Arranque con la composición de producción | Se agregó una etapa `activos` con Node 20 que compila `resources/` dentro de la construcción |
| D-15 | En la composición de producción no hay `APP_KEY`: la imagen excluye `src/.env` (correcto) y el `.env` de la raíz no la define (también correcto, ver D-03). Laravel lanzaba `MissingAppKeyException` y toda vista respondía 500 | Bloqueante | Arranque con la composición de producción | Los dos pipelines generan una clave desechable por corrida con `openssl rand`. En producción viene de los secretos del proveedor |
| D-16 | **El arranque en integración continua fallaba de forma intermitente.** Seis servicios montan el volumen compartido `app_storage`; al crearse a la vez sobre un volumen nuevo, Docker intenta sembrarlo desde la imagen en paralelo y choca consigo mismo: `failed to mkdir .../chdiego_app_storage/_data/app: file exists` | Bloqueante | Registro de la corrida del 2026-09-29, paso «Levantar los servicios» | Arranque escalonado en ambos pipelines: `db` y `cache` primero, luego un solo servicio de aplicación que siembra los volúmenes, y al final el resto |
| D-17 | H11 exigía exactamente 502 del microservicio detenido. nginx devuelve 502 cuando la conexión es rechazada y 504 cuando el nombre no resuelve o la conexión expira, y cuál sale depende del motor de contenedores: Docker Engine dio 504 y la prueba falló sin que nada estuviera roto | Alta | Registro de integración continua: `pagos detenido=504` | El caso acepta cualquier error de pasarela (502, 503 o 504) |
| D-18 | La misma H11 comprobaba que el servicio sobreviviente devolviera «algo distinto de 502», y un 500 por aplicación rota pasaba como si el aislamiento funcionara. Fue lo que dejó pasar D-13 durante una semana | Alta | Revisión del registro de integración continua | Ahora exige 200 del sobreviviente, no la ausencia de un código concreto |
| D-19 | Los pipelines arrancaban 9 servicios con `-f docker-compose.yml` pero los scripts de prueba invocaban `docker compose` sin `-f`, que carga también `docker-compose.override.yml` porque está versionado: el arranque veía 9 servicios y las pruebas 10 | Media | Comparación de `config --services` entre ambas composiciones | `COMPOSE_FILE` fijada a nivel de pipeline en los dos sistemas |
| D-20 | **El trabajo de integración continua quedó en verde habiendo ejecutado 34 de 73 pruebas.** Las unitarias fallaban con `Could not open input file: vendor/bin/phpunit`: se ejecutaban con `docker compose exec` dentro de un microservicio, y la imagen de producción instala con `--no-dev`, donde PHPUnit no existe. Funcionaba solo en el equipo de desarrollo, por el montaje de `./src` | Bloqueante | Primera corrida sobre la rama `develop`, 2026-09-29 | Las unitarias corren en su propia imagen (`docker/pruebas/Dockerfile`), que parte de la base y agrega las dependencias de desarrollo. Ya no necesitan ningún servicio levantado |
| D-21 | El generador del reporte ignoraba un informe ausente y sumaba solo los presentes. Como las suites corren con la marca de continuar ante error, el reporte es la única puerta que decide el resultado: un informe que falta pasaba inadvertido y el trabajo daba verde con una suite entera sin ejecutar. Es lo que permitió que D-20 no se viera | Bloqueante | Revisión de la anotación «exit code 1» en una corrida marcada como correcta | Un informe ausente ahora falla con un mensaje que nombra la suite que no llegó a escribirlo |
| D-22 | `composer dump-autoload` corría como root en la imagen base y dejaba `vendor/composer/*.php` con dueño root dentro de un `vendor` de `laravel`. Producción solo lee, así que no molestaba, pero impedía que cualquier imagen derivada reinstalara dependencias | Media | Construcción de la imagen de pruebas | Se unifica el dueño de `vendor` al terminar |
| D-23 | El informe de las unitarias se escribía en un directorio montado del anfitrión, y el contenedor corre como `laravel` (uid 1000): con Podman sin privilegios por el remapeo de uid, y en un agente porque el directorio es del usuario del agente. Fallaba con `Permission denied` al escribir el XML | Media | Ejecución de la imagen de pruebas | El informe se escribe dentro del contenedor y se extrae con `docker cp` |

Ninguno de estos defectos apareció en la lectura del código: todos se
encontraron al ejecutar el sistema contra contenedores reales y una base de
datos real, o al revisar la salida que el propio sistema produjo.

Los siete últimos (D-13 a D-19) merecen una nota aparte, porque son los que
justifican el gasto de montar integración continua. Las cuatro suites pasaban
en el equipo de desarrollo y seguían pasando, mientras **la imagen de
contenedor no podía ejecutar la aplicación por sí sola**: el montaje de `./src`
del archivo de desarrollo la tapaba. Solo el agente de integración continua,
que arranca la composición de producción sin ese montaje, lo puso en
evidencia. D-18 explica por qué tardó: la única prueba que atravesaba la
aplicación por HTTP durante un fallo comprobaba la ausencia de un código
concreto en vez de la presencia del correcto, y aceptó un 500 como si fuera
salud.

## 11. Riesgos del plan de pruebas

| # | Riesgo | Impacto | Mitigación |
|---|---|---|---|
| R-01 | Azure DevOps no concede agentes hospedados gratuitos a organizaciones nuevas, y la solicitud tarda días hábiles | Alto: la etapa de pruebas no corre en el pipeline el día de la entrega | Solicitud enviada con anticipación. Alternativa lista: registrar un agente propio en un equipo del grupo con Docker y cambiar `vmImage: ubuntu-latest` por `name: Default` |
| R-02 | Las pruebas de sistema y seguridad escriben en la base real | Bajo | Prefijos identificables `PH-` y `ps_`, borrado automático de los usuarios de seguridad mediante trampa de salida, y H18 verifica el cuadre del kardex |
| R-03 | Los scripts de inicialización solo corren al crear el volumen, así que un cambio de esquema puede no reflejarse | Medio: falsos fallos de H12 | Documentado en el criterio de entrada; `make limpiar` recrea el volumen |
| R-04 | Las pruebas de rendimiento pueden dar falsos fallos en un agente hospedado saturado | Medio: el pipeline falla sin regresión real | Umbrales holgados, entre diez y treinta veces lo medido, y ajustables por variable de entorno sin editar el script |
| R-05 | El certificador FEL real no está contratado, se prueba contra un simulador | Medio: el comportamiento del certificador real puede diferir | El simulador es configurable, tiene sus propias pruebas unitarias (U14–U17), y se probó con fallo repetido, reintentos con retroceso creciente y rechazo al llegar al máximo |
| R-06 | El equipo de desarrollo usa Podman y no Docker Engine | Bajo | Los dos pipelines ejecutan las mismas suites sobre Docker Engine real; los ajustes de Podman están aislados en un archivo no versionado |
| R-07 | No hay pruebas automatizadas de navegador | Bajo para este frontend, medio si se agrega lógica de cliente | Recorrido manual documentado en la sección 5.4. Si una entrega posterior introduce JavaScript con estado, este riesgo sube y hay que reconsiderar la decisión de la sección 5.1 |
| R-08 | La cobertura unitaria se concentra en cuatro clases, no en las 74 de la aplicación | Medio: un error en un controlador o un servicio no lo detecta ninguna unitaria | Deliberado: se eligieron las clases con lógica propia y contrato estable. Los controladores y servicios se ejercitan de forma indirecta por H14–H18 y S01–S05, que los atraviesan por HTTP real |

## 12. Entregables de prueba

| Entregable | Ubicación |
|---|---|
| Este plan de pruebas | `docs/devops1/plan-de-pruebas.md` |
| Casos de prueba documentados con resultados | `docs/devops1/casos-de-prueba.md` |
| Casos de prueba para importar a Azure Test Plans | `tests/casos/casos-de-prueba-azure.csv` |
| Pruebas unitarias | `src/tests/Unit/` y `src/tests/Feature/` |
| Ejecutor de las pruebas unitarias | `tests/unitarias/pruebas-unitarias.sh` |
| Imagen de pruebas unitarias | `docker/pruebas/Dockerfile` |
| Suite de sistema e integración | `tests/humo/pruebas-humo.sh` |
| Suite de seguridad | `tests/seguridad/pruebas-seguridad.sh` |
| Suite de rendimiento | `tests/rendimiento/pruebas-rendimiento.sh` |
| Generador del reporte HTML | `scripts/reporte-pruebas.py` |
| Reporte HTML de la ejecución | `docs/devops1/evidencias/informes/reporte-de-pruebas.html` (copia versionada de `tests/resultados/`) |
| Informes JUnit de las cuatro suites | `docs/devops1/evidencias/informes/resultados-*.xml` |
| Línea base de rendimiento | `docs/devops1/evidencias/informes/linea-base-rendimiento.txt` |
| Verificación de esquema y cuadre del kardex | `scripts/verificar-esquema.sh` |
| Peticiones para pruebas manuales | `tests/api/peticiones.http` |
| 16 evidencias técnicas con su índice | `docs/devops1/evidencias/` |
| Guía operativa de ejecución | `tests/README.md` |

## 13. Matriz de trazabilidad

Cada requerimiento del modelo de negocio, el microservicio que lo atiende y los
casos de prueba que lo respaldan, por tipo.

| Requerimiento | Servicio | Unitarias | Integración y sistema | Seguridad | Rendimiento | Evidencia |
|---|---|---|---|---|---|---|
| Identidad, roles, permisos y auditoría | `auth` | U13 | H05, H09–H11, H13, H16 | S01–S05, S10 | R04 | 06, 07, 10, 13 |
| Catálogo de productos y precios | `catalogo` | U11, U12 | H06, H14 | — | R04 | 06, 10, 11 |
| Inventario por lotes y kardex | `catalogo` | U09, U10 | H14, H17, H18 | — | — | 11 |
| Punto de venta | `pagos` | U01–U10 | H15, H17 | S05 | — | 11, 14 |
| Facturación electrónica FEL | `pagos` y `queue` | U14–U17 | H15, H17 | — | — | 07, 14 |
| Clientes, carrito y pedidos | `pedidos` | U09–U11 | H07 | — | R04 | 06, 10 |
| Entregas y zonas de cobertura | `pedidos` | — | H07, H13 | — | R04 | 06, 10 |
| Caja por suscripción | `pedidos` | — | H12 | — | — | 11 |
| Notificaciones y parámetros del sistema | los cuatro | — | H12 | — | — | 11 |
| Aislamiento entre dominios | `gateway` | — | H04–H09, H11 | S06–S08 | R01, R02, R04 | 08, 10, 13 |
| Correspondencia con el Octavo Documento | `db` | U09–U13 | H12, H13, H18 | — | — | 11 |
| Manejo de secretos y configuración | los cuatro | — | — | S09–S11 | — | 02, 16 |
| Versionado e integración continua | — | las cuatro suites en ambos pipelines | — | — | — | 15, 16 |

Sin filas vacías: todo requerimiento tiene al menos un caso de prueba y al
menos una evidencia. Los guiones marcan tipos de prueba que no aplican a ese
requerimiento, no cobertura faltante.

## 14. Resultado de la ejecución de referencia

| | |
|---|---|
| Fecha | 28 de septiembre de 2026 |
| Entorno | Equipo de desarrollo, nueve servicios levantados |
| Casos documentados | 51 |
| Ejecuciones | 73 |
| Aprobadas | 73 |
| Falladas | 0 |
| Duración total | poco más de 30 segundos |

### Por suite

| Suite | Casos | Ejecuciones | Aprobadas | Falladas | Duración |
|---|---|---|---|---|---|
| Unitarias (PHPUnit) | 17 | 39 | 39 | 0 | 0.11 s |
| Humo, integración y sistema | 18 | 18 | 18 | 0 | 20 s |
| Seguridad | 11 | 11 | 11 | 0 | 9 s |
| Rendimiento | 5 | 5 | 5 | 0 | 2 s |

### Verificación del esquema

| | |
|---|---|
| Cifras del esquema | 8 de 8 en OK |
| Objetos con nombre verificados | 23 de 23 en OK |
| Cuadre del kardex | Cuadra |

### Línea base de rendimiento medida

| Medición | Valor | Umbral |
|---|---|---|
| `/estado`, percentil 50 | 0.003 s | — |
| `/estado`, percentil 95 | 0.008 s | 1.000 s |
| `/api/auth/salud`, percentil 50 | 0.079 s | — |
| `/api/auth/salud`, percentil 95 | 0.102 s | 3.000 s |
| Respuestas correctas bajo carga | 400 de 400 | 100 % |
| Memoria máxima por contenedor | 444 MB (`chdiego_db`) | 512 MB |

Carga aplicada: 200 peticiones con 20 concurrentes por ruta, más 25 peticiones
con 10 concurrentes por cada uno de los cuatro prefijos de dominio.

Salida completa en `docs/devops1/evidencias/informes/reporte-de-pruebas.html`,
`docs/devops1/evidencias/14-pruebas-de-humo.txt`,
`docs/devops1/evidencias/16-pruebas-por-tipo.txt` y
`docs/devops1/evidencias/11-verificacion-de-esquema.txt`.

## 15. Aprobación

| Rol | Nombre | Responsabilidad sobre este plan |
|---|---|---|
| Responsable de pruebas | Ricardo Ismael Pérez Ajanel | Redacción del plan, diseño y ejecución de los 51 casos, captura de evidencias |
| Scrum Master | Carla Estefanía Duque Martínez | Revisión e integración al documento final |
| Product Owner | William Natanael Vásquez Navichoc | Validación de que los casos cubren las historias de usuario |
| Desarrollo — Azure DevOps | Julio Alexis León Rodríguez | Ejecución de las cuatro suites dentro del pipeline de integración continua |
