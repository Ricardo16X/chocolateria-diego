# Pruebas — Artesanal Chocolate Diego

Todo lo necesario para Azure Pipelines y Azure Test Plans ya está escrito.
Esta guía explica cómo usarlo sin escribir pruebas nuevas.

## Contenido

| Carpeta | Qué contiene | Para qué sirve |
|---|---|---|
| `humo/` | `pruebas-humo.sh`, 18 pruebas automáticas | Etapa de pruebas del pipeline |
| `casos/` | `casos-de-prueba-azure.csv`, los mismos 18 casos como pasos manuales | Importar a Azure Test Plans |
| `api/` | `peticiones.http`, peticiones a la puerta de enlace | Probar rutas a mano desde VS Code |
| `unitarias/` | Reservada para PHPUnit | Pruebas de Laravel, en entregas posteriores |
| `resultados/` | Se genera al ejecutar las pruebas | Resultados en formato JUnit |

## Las 18 pruebas

| ID | Grupo | Qué comprueba |
|---|---|---|
| H01 | Infraestructura | Los nueve contenedores están en ejecución |
| H02 | Infraestructura | La base de datos reporta estado saludable |
| H03 | Infraestructura | Redis responde a PING |
| H04 | Infraestructura | La puerta de enlace responde |
| H05 | Microservicios | `/api/auth` llega al servicio auth |
| H06 | Microservicios | `/api/catalogo` llega al servicio catalogo |
| H07 | Microservicios | `/api/pedidos` llega al servicio pedidos |
| H08 | Microservicios | `/api/pagos` llega al servicio pagos |
| H09 | Microservicios | Los servicios de dominio no se exponen al exterior |
| H10 | Microservicios | Los cuatro tienen las extensiones de PHP requeridas |
| H11 | Microservicios | La caída de pagos no afecta a auth, y pagos se recupera |
| H12 | Base de datos | El esquema corresponde al Octavo Documento |
| H13 | Base de datos | Los catálogos base están cargados |
| H14 | Flujo de venta | Alta de producto, lote y entrada de inventario |
| H15 | Flujo de venta | Venta a consumidor final descuenta existencia y genera DTE |
| H16 | Flujo de venta | La venta queda registrada en la bitácora |
| H17 | Flujo de venta | La anulación restituye la existencia y anula el DTE |
| H18 | Flujo de venta | El kardex cuadra después del ciclo completo |

Las pruebas H05 a H11 funcionan desde el primer arranque, aunque Laravel todavía
no tenga rutas: comprueban a qué contenedor llega la petición, no lo que
responde.

## Ejecutarlas en el equipo

```bash
make arriba
make probar
```

Tarda entre uno y dos minutos. La H11 detiene y vuelve a levantar el servicio
de pagos a propósito.

---

## Azure Pipelines

El archivo `azure-pipelines.yml` en la raíz del repositorio ya define las dos
etapas, construcción y pruebas.

1. En Azure DevOps: **Pipelines → New pipeline**.
2. Elegir el origen del código: **GitHub** o **Azure Repos Git**.
3. Seleccionar el repositorio.
4. Elegir **Existing Azure Pipelines YAML file** y la ruta `/azure-pipelines.yml`.
5. **Run**.

Al terminar, la pestaña **Tests** de la ejecución muestra las 18 pruebas con su
resultado y duración, y la pestaña **Artifacts** contiene la carpeta
`evidencias-devops1`.

### Antes de ejecutar por primera vez

Las organizaciones nuevas de Azure DevOps pueden no tener habilitados los
agentes gratuitos hospedados por Microsoft, y la solicitud tarda algunos días
hábiles en aprobarse. Si al ejecutar aparece el mensaje *No hosted parallelism
has been purchased or granted*, hay dos caminos:

- Solicitar la concesión gratuita en https://aka.ms/azpipelines-parallelism-request
  lo antes posible.
- Mientras tanto, registrar un agente propio en un equipo del grupo con Docker
  instalado: **Project Settings → Agent pools → Default → New agent**, y cambiar
  en `azure-pipelines.yml` la línea `vmImage: ubuntu-latest` por `name: Default`.

Conviene revisarlo hoy y no el día de la entrega.

---

## Azure Test Plans

El archivo `casos/casos-de-prueba-azure.csv` contiene los 18 casos con 35 pasos,
cada uno con acción y resultado esperado.

1. En Azure DevOps: **Test Plans → New Test Plan**. Nombre sugerido:
   *Sprint 1 — DEVOPS 1*.
2. Dentro del plan, en la suite raíz: menú **⋮ → Import test cases from CSV**.
   En algunas versiones la opción está en la vista de cuadrícula,
   **Grid → Import**.
3. Seleccionar `casos-de-prueba-azure.csv`.
4. Revisar la asignación de columnas: *Title*, *Test Step*, *Step Action*,
   *Step Expected*, *Priority*, *State*. Aceptar.

Los 18 casos quedan creados como elementos de trabajo de tipo *Test Case*.

### Vincular las pruebas manuales con las automáticas

Cada caso manual tiene el mismo identificador que su prueba automática, de H01
a H18. Esa correspondencia es la trazabilidad entre Test Plans y Pipelines:
lo que el plan describe como pasos manuales es exactamente lo que el pipeline
ejecuta.

Para el video basta con mostrar un caso en Test Plans, por ejemplo el H11, y
luego el mismo H11 aprobado en la pestaña Tests de la ejecución del pipeline.

### Ejecutar un caso manual

En el plan, seleccionar un caso y **Run → Run for web application**. Azure
muestra los pasos uno por uno y permite marcarlos como aprobados o fallidos.
Eso genera la evidencia de ejecución manual que pide la entrega.
