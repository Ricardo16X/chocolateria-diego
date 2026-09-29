# Pruebas — Artesanal Chocolate Diego

Todo lo necesario para Azure Pipelines y Azure Test Plans ya está escrito. Esta
guía es **operativa**: dice cómo ejecutar las pruebas, no qué se prueba ni por
qué.

Para eso están los dos documentos del plan:

- **Qué se prueba, con qué estrategia, bajo qué criterios y con qué riesgos:**
  [`docs/devops1/plan-de-pruebas.md`](../docs/devops1/plan-de-pruebas.md)
- **Los 51 casos con sus precondiciones, pasos y el resultado obtenido:**
  [`docs/devops1/casos-de-prueba.md`](../docs/devops1/casos-de-prueba.md)

## Contenido

| Carpeta | Qué contiene | Para qué sirve |
|---|---|---|
| `unitarias/` | `pruebas-unitarias.sh`, que ejecuta PHPUnit en la imagen de pruebas | Casos U01–U17, sobre las clases de PHP |
| `humo/` | `pruebas-humo.sh`, 18 pruebas de sistema e integración | Casos H01–H18 |
| `seguridad/` | `pruebas-seguridad.sh`, 11 pruebas de control de acceso y endurecimiento | Casos S01–S11 |
| `rendimiento/` | `pruebas-rendimiento.sh`, 5 pruebas de carga | Casos R01–R05 |
| `casos/` | `casos-de-prueba-azure.csv`, los 51 casos como pasos manuales | Importar a Azure Test Plans |
| `api/` | `peticiones.http`, peticiones a la puerta de enlace | Probar rutas a mano desde el editor |
| `resultados/` | Se genera al ejecutar las pruebas | Informes JUnit y reporte HTML |

Las pruebas unitarias viven en `src/tests/Unit/` y `src/tests/Feature/`, junto
al código que prueban, como espera Laravel. Lo que hay en `tests/unitarias/` es
solo el script que las ejecuta y trae el informe al repositorio.

Corren en una imagen aparte, `docker/pruebas/Dockerfile`, que parte de la base
y agrega las dependencias de desarrollo. La imagen de producción se instala con
`--no-dev` y PHPUnit es una de ellas, así que dentro de un microservicio no
existe: eso funcionaba solo en el equipo de desarrollo, donde el montaje de
`./src` trae el `vendor` completo del anfitrión.

## Las cuatro suites

| Suite | Tipo de prueba | Casos | Ejecuciones | Duración | Necesita el sistema levantado |
|---|---|---|---|---|---|
| Unitarias | Unitarias | 17 | 39 | menos de 1 s | No: solo la imagen base |
| Humo | Sistema (H01–H11) e integración (H12–H18) | 18 | 18 | 20 s | Sí, los nueve |
| Seguridad | Seguridad | 11 | 11 | 9 s | Sí, los nueve |
| Rendimiento | Rendimiento | 5 | 5 | 2 s | Sí, los nueve |
| **Total** | | **51** | **73** | **poco más de 30 s** | |

## Ejecutarlas en el equipo

```bash
make arriba        # levanta los nueve servicios
make probar-todo   # las cuatro suites y el reporte HTML
```

`probar-todo` deja que las cuatro suites corran aunque una falle, y termina
generando el reporte, de modo que una suite rota no oculta el resultado de las
otras tres.

Suite por suite:

```bash
make probar-unitarias    # U01–U17
make probar              # H01–H18
make probar-seguridad    # S01–S11
make probar-rendimiento  # R01–R05
make reporte             # regenera el HTML con los informes que haya
```

### Lo que las pruebas escriben y limpian

| Suite | Qué escribe | Cómo se limpia |
|---|---|---|
| Unitarias | Nada. No tocan la base ni la red | — |
| Humo | Un producto con código `PH-`, su lote, una venta y su anulación | Queda en la base, identificable por el prefijo. H18 verifica que el kardex cuadre |
| Seguridad | Dos usuarios con prefijo `ps_` | Se borran al terminar, incluso si un caso falla |
| Rendimiento | Nada | — |

H11 detiene y vuelve a levantar el servicio `pagos` a propósito: es la prueba
más lenta, unos 9 segundos, y deja el sistema como lo encontró.

### Resultados

| Archivo | Contenido |
|---|---|
| `resultados/reporte-de-pruebas.html` | Reporte consolidado de las cuatro suites. Se abre en cualquier navegador, sin conexión |
| `resultados/resultados-unitarias.xml` | Informe JUnit de PHPUnit |
| `resultados/resultados-humo.xml` | Informe JUnit de la suite de humo |
| `resultados/resultados-seguridad.xml` | Informe JUnit de la suite de seguridad |
| `resultados/resultados-rendimiento.xml` | Informe JUnit de la suite de rendimiento |
| `resultados/linea-base-rendimiento.txt` | Mediciones crudas de latencia y memoria |

Esta carpeta está en `.gitignore`: es salida generada. `make evidencias` copia
el reporte, los cuatro informes JUnit y la línea base a
`docs/devops1/evidencias/informes/`, que sí se versiona y es la copia que viaja
con la entrega.

### Ajustar los umbrales de rendimiento

Los umbrales son holgados a propósito, para no producir fallos en agentes
hospedados que no corresponden a ninguna regresión real. Se cambian por
variable de entorno, sin editar el script:

```bash
PETICIONES=500 CONCURRENCIA=50 UMBRAL_P95_SERVICIO=5.000 make probar-rendimiento
```

---

## Azure Pipelines

`azure-pipelines.yml` en la raíz del repositorio define tres etapas:
construcción, pruebas y despliegue. La de pruebas ejecuta las cuatro suites,
cada una en su propio paso.

1. En Azure DevOps: **Pipelines → New pipeline**.
2. Elegir el origen del código: **GitHub** o **Azure Repos Git**.
3. Seleccionar el repositorio.
4. Elegir **Existing Azure Pipelines YAML file** y la ruta
   `/azure-pipelines.yml`.
5. **Run**.

Al terminar, la pestaña **Tests** de la ejecución muestra los 51 casos de las
cuatro suites con su resultado y duración, y la pestaña **Artifacts** contiene
la carpeta `evidencias-devops1` con el reporte HTML, los cuatro informes JUnit y
la línea base de rendimiento.

### Antes de ejecutar por primera vez

Las organizaciones nuevas de Azure DevOps pueden no tener habilitados los
agentes gratuitos hospedados por Microsoft, y la solicitud tarda algunos días
hábiles en aprobarse. Si al ejecutar aparece el mensaje *No hosted parallelism
has been purchased or granted*, hay dos caminos:

- Solicitar la concesión gratuita en
  https://aka.ms/azpipelines-parallelism-request lo antes posible.
- Mientras tanto, registrar un agente propio en un equipo del grupo con Docker
  instalado: **Project Settings → Agent pools → Default → New agent**, y cambiar
  en `azure-pipelines.yml` la línea `vmImage: ubuntu-latest` por `name: Default`.

Conviene revisarlo hoy y no el día de la entrega. Está registrado como riesgo
R-01 del plan de pruebas.

---

## GitHub Actions

`.github/workflows/ci.yml` corre en paralelo al pipeline de Azure, sobre `main`,
`develop` y cada *pull request* contra `main`. Dos trabajos:

- **revision**: `hadolint` sobre los seis Dockerfiles y `shellcheck` sobre todos
  los scripts, incluidos los de prueba.
- **pruebas**: construye, levanta el sistema, ejecuta las cuatro suites y sube
  `tests/resultados/` completo como artefacto, con el reporte HTML incluido.

No hace falta configurar nada: funciona con el repositorio tal como está.

---

## Azure Test Plans

`casos/casos-de-prueba-azure.csv` contiene los 51 casos con 74 pasos, cada uno
con acción y resultado esperado.

1. En Azure DevOps: **Test Plans → New Test Plan**. Nombre sugerido:
   *Sprint 2 — DEVOPS 2*.
2. Dentro del plan, en la suite raíz: menú **⋮ → Import test cases from CSV**.
   En algunas versiones la opción está en la vista de cuadrícula,
   **Grid → Import**.
3. Seleccionar `casos-de-prueba-azure.csv`.
4. Revisar la asignación de columnas: *Title*, *Test Step*, *Step Action*,
   *Step Expected*, *Priority*, *State*. Aceptar.

Los 51 casos quedan creados como elementos de trabajo de tipo *Test Case*.

### Vincular las pruebas manuales con las automáticas

Cada caso manual tiene el mismo identificador que su prueba automática: U01 a
U17, H01 a H18, S01 a S11, R01 a R05. Esa correspondencia es la trazabilidad
entre Test Plans y Pipelines: lo que el plan describe como pasos manuales es
exactamente lo que el pipeline ejecuta.

Para la revisión basta con mostrar un caso en Test Plans y el mismo
identificador aprobado en la pestaña Tests de la ejecución del pipeline. Los dos
más ilustrativos:

- **H11**, que apaga el microservicio de pagos y comprueba que los demás siguen
  atendiendo.
- **S05**, que entra con un usuario sin permiso de venta y comprueba que el
  panel le abre pero el punto de venta le responde 403.

### Ejecutar un caso manual

En el plan, seleccionar un caso y **Run → Run for web application**. Azure
muestra los pasos uno por uno y permite marcarlos como aprobados o fallidos. Eso
genera la evidencia de ejecución manual que pide la entrega.
