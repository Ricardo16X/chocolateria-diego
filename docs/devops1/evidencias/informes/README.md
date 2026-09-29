# Informes de ejecucion de pruebas

Copia de `tests/resultados/`, generada el 2026-09-28 22:56:47 por
`scripts/evidencias.sh`. La carpeta original esta en `.gitignore` por ser
salida generada; esta copia se versiona porque el reporte de ejecucion es un
entregable de la entrega.

| Archivo | Contenido |
|---|---|
| reporte-de-pruebas.html | Reporte consolidado de las cuatro suites. Se abre en cualquier navegador, sin conexion |
| resultados-unitarias.xml | Informe JUnit de PHPUnit, casos U01 a U17 |
| resultados-humo.xml | Informe JUnit de sistema e integracion, casos H01 a H18 |
| resultados-seguridad.xml | Informe JUnit de seguridad, casos S01 a S11 |
| resultados-rendimiento.xml | Informe JUnit de rendimiento, casos R01 a R05 |
| linea-base-rendimiento.txt | Mediciones crudas de latencia y memoria |

Para regenerarlos: `make probar-todo` y luego `make evidencias`.
