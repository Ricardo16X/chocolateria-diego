# Despliegue en Microsoft Azure

## Azure DevOps no es Microsoft Azure

Son dos productos de Microsoft distintos y con una relación de dependencia,
no de sinónimos:

| | Azure DevOps | Microsoft Azure |
|---|---|---|
| Qué es | Herramienta de gestión y automatización | Proveedor de nube (IaaS/PaaS) |
| Qué contiene | Boards, Repos, **Pipelines**, Test Plans, Artifacts | Resource Groups, App Service, Azure Database for MySQL, Blob Storage, Container Registry |
| Rol en este proyecto | Ejecuta `azure-pipelines.yml`: construye, prueba y ahora también despliega | Aloja la aplicación en ejecución: el Web App, la base de datos administrada, el almacenamiento de archivos |
| Analogía | El operario y la cinta de producción | La fábrica y la bodega donde queda el producto terminado |

El pipeline (Azure DevOps) automatiza; los recursos que aparecen en el
Resource Group (Microsoft Azure) son lo que el pipeline automatiza *hacia*.
Antes de esta corrección, el pipeline solo cubría Azure DevOps (construir y
probar) y nunca tocaba Microsoft Azure: no había etapa de despliegue.

## Qué agrega esta corrección

`azure-pipelines.yml` ahora tiene una tercera etapa, **Despliegue**, que:

1. Reconstruye las imágenes de los cuatro microservicios.
2. Las publica en un **Azure Container Registry** (ACR).
3. Actualiza el **Web App multicontenedor** de Azure App Service para que
   use esas imágenes, a partir de una copia de `docker-compose.yml` con las
   referencias de imagen apuntando al registro.
4. Reinicia el Web App.

Solo corre cuando el pipeline se ejecuta sobre la rama `main` (no en cada
Pull Request), y solo si la etapa de Pruebas pasó.

## Recursos que hay que crear una sola vez en el portal de Azure

Esto **no lo hace el pipeline**: son recursos de infraestructura que se crean
una vez, de forma manual (o con Terraform/Bicep en una entrega futura), antes
de que la etapa de Despliegue pueda ejecutarse con éxito.

| Recurso | Para qué | Dónde crearlo |
|---|---|---|
| Grupo de recursos | Agrupa todo lo demás | portal.azure.com → Resource groups → Create |
| Azure Container Registry (ACR) | Guarda las imágenes de `auth`, `catalogo`, `pedidos`, `pagos`, `gateway` | Dentro del grupo de recursos → Create a resource → Container Registry |
| App Service Plan (Linux) + Web App | Corre el Web App multicontenedor a partir de `docker-compose.yml` | Create a resource → Web App → Publish: Docker Container → Linux |
| Azure Database for MySQL Flexible Server | Sustituye al contenedor `db` en producción | Create a resource → Azure Database for MySQL Flexible Server |
| Azure Blob Storage (opcional, fase posterior) | Comprobantes de venta, XML de FEL | Create a resource → Storage account |

## Conexión entre Azure DevOps y Microsoft Azure

1. En el **Resource Group**, crear una **Service Principal** con permisos de
   colaborador (o dejar que el paso siguiente lo haga automáticamente).
2. En Azure DevOps: **Project Settings → Service connections → New service
   connection → Azure Resource Manager**, autenticar contra la suscripción
   de Azure, y nombrarla (por ejemplo `conexion-azure-chocolate-diego`).
3. En Azure DevOps: **Pipelines → Library → Variable group**, crear un grupo
   (por ejemplo `nube-produccion`) con estas cuatro variables:

   | Variable | Ejemplo de valor |
   |---|---|
   | `AZURE_SERVICE_CONNECTION` | `conexion-azure-chocolate-diego` |
   | `ACR_NOMBRE` | `chocolatediegoacr` (sin guiones, es el subdominio) |
   | `RESOURCE_GROUP` | `rg-chocolate-diego` |
   | `APP_SERVICE_NOMBRE` | `chocolate-diego-app` |

4. Vincular el grupo de variables al pipeline: **Edit pipeline → Variables →
   Variable groups → Link variable group**.
5. En el Web App: **Configuration → Application settings**, agregar las
   variables de `.env` que la aplicación necesita en producción (`DB_HOST`
   apuntando al MySQL Flexible Server, `DB_PASSWORD`, `APP_KEY`, credenciales
   del certificador FEL, etc.). Ninguna de esas claves va en el repositorio.

## Nota de alcance

Esta etapa deja el pipeline completo (CI + CD) y documentado, pero **no
provisiona los recursos de Azure por sí sola**: eso requiere una suscripción
de Azure y decisiones de facturación que le corresponden al equipo, no al
pipeline. Mientras los recursos no existan, la etapa Despliegue fallará al
intentar conectarse — eso es esperado, no un error del YAML.
