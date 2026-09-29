#!/usr/bin/env python3
"""Artesanal Chocolate Diego — reporte HTML de la ejecucion de pruebas.

Une los informes JUnit que dejan las cuatro suites en tests/resultados/ y
genera un solo archivo HTML autocontenido, sin dependencias externas ni
acceso a la red, para adjuntarlo a la entrega y publicarlo como artefacto
del pipeline.

Uso:
    make reporte
    python3 scripts/reporte-pruebas.py

Devuelve 0 si todas las pruebas de todos los informes pasaron, 1 si alguna
fallo, y 2 si no encontro ningun informe que leer.
"""

from __future__ import annotations

import html
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
RESULTADOS = RAIZ / "tests" / "resultados"
DESTINO = RESULTADOS / "reporte-de-pruebas.html"

# Orden de presentacion: del nivel mas bajo al mas alto, como en el plan de
# pruebas. La clave es el nombre del archivo; el valor, como se titula la
# suite en el reporte y de que tipo de prueba se trata.
SUITES = [
    ("resultados-unitarias.xml", "Pruebas unitarias", "Unitarias"),
    ("resultados-humo.xml", "Pruebas de humo, integracion y sistema", "Integracion y sistema"),
    ("resultados-seguridad.xml", "Pruebas de seguridad", "Seguridad"),
    ("resultados-rendimiento.xml", "Pruebas de rendimiento", "Rendimiento"),
]


class Caso:
    def __init__(self, nombre: str, clase: str, duracion: float, fallo: str | None):
        self.nombre = nombre
        self.clase = clase
        self.duracion = duracion
        self.fallo = fallo

    @property
    def paso(self) -> bool:
        return self.fallo is None


class Suite:
    def __init__(self, titulo: str, tipo: str, archivo: Path):
        self.titulo = titulo
        self.tipo = tipo
        self.archivo = archivo
        self.casos: list[Caso] = []
        self.marca: str = ""

    @property
    def total(self) -> int:
        return len(self.casos)

    @property
    def fallidas(self) -> int:
        return sum(1 for c in self.casos if not c.paso)

    @property
    def aprobadas(self) -> int:
        return self.total - self.fallidas

    @property
    def duracion(self) -> float:
        return sum(c.duracion for c in self.casos)


def leer_suite(archivo: Path, titulo: str, tipo: str) -> Suite | None:
    """Lee un informe JUnit. Tolera las dos formas que producen las suites:
    PHPUnit anida <testsuite> dentro de <testsuite>, los scripts de bash
    emiten un solo nivel."""
    if not archivo.is_file():
        return None

    try:
        raiz = ET.parse(archivo).getroot()
    except ET.ParseError as e:
        print(f"  [omitido] {archivo.name}: XML invalido ({e})", file=sys.stderr)
        return None

    suite = Suite(titulo, tipo, archivo)

    for ts in raiz.iter("testsuite"):
        if not suite.marca:
            suite.marca = ts.get("timestamp", "")

    # iter() recorre todos los niveles, asi que los <testcase> se recogen una
    # sola vez sin importar cuanto anidamiento traiga el informe.
    for tc in raiz.iter("testcase"):
        fallo = None
        for etiqueta in ("failure", "error"):
            nodo = tc.find(etiqueta)
            if nodo is not None:
                fallo = (nodo.get("message") or "") + "\n" + (nodo.text or "")
                fallo = fallo.strip()
                break
        try:
            duracion = float(tc.get("time", "0") or 0)
        except ValueError:
            duracion = 0.0
        suite.casos.append(
            Caso(
                nombre=tc.get("name", "(sin nombre)"),
                clase=tc.get("classname", ""),
                duracion=duracion,
                fallo=fallo,
            )
        )

    return suite if suite.casos else None


def fila(caso: Caso) -> str:
    estado = "aprobado" if caso.paso else "fallado"
    etiqueta = "Aprobado" if caso.paso else "Fallado"
    detalle = ""
    if not caso.paso:
        detalle = (
            f'<tr class="detalle"><td colspan="4"><pre>{html.escape(caso.fallo or "")}</pre></td></tr>'
        )
    return (
        f'<tr><td class="estado {estado}">{etiqueta}</td>'
        f"<td>{html.escape(caso.nombre)}</td>"
        f'<td class="clase">{html.escape(caso.clase)}</td>'
        f'<td class="num">{caso.duracion:.2f} s</td></tr>{detalle}'
    )


def construir(suites: list[Suite]) -> str:
    total = sum(s.total for s in suites)
    fallidas = sum(s.fallidas for s in suites)
    aprobadas = total - fallidas
    duracion = sum(s.duracion for s in suites)
    verde = fallidas == 0

    generado = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    if verde:
        veredicto = "Todas las pruebas pasaron"
    elif fallidas == 1:
        veredicto = "1 prueba fallo"
    else:
        veredicto = f"{fallidas} pruebas fallaron"

    resumen_suites = "".join(
        f"<tr><td>{html.escape(s.tipo)}</td>"
        f"<td>{html.escape(s.titulo)}</td>"
        f'<td class="num">{s.total}</td>'
        f'<td class="num">{s.aprobadas}</td>'
        f'<td class="num {"aprobado" if s.fallidas == 0 else "fallado"}">{s.fallidas}</td>'
        f'<td class="num">{s.duracion:.2f} s</td></tr>'
        for s in suites
    )

    secciones = "".join(
        f"<section><h2>{html.escape(s.titulo)}</h2>"
        f'<p class="meta">{s.total} casos · {s.aprobadas} aprobados · {s.fallidas} fallados · '
        f"{s.duracion:.2f} s · informe <code>{html.escape(s.archivo.name)}</code></p>"
        '<table><thead><tr><th>Estado</th><th>Caso</th><th>Grupo</th><th>Duracion</th></tr></thead>'
        f'<tbody>{"".join(fila(c) for c in s.casos)}</tbody></table></section>'
        for s in suites
    )

    return f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Reporte de pruebas — Artesanal Chocolate Diego</title>
<style>
  :root {{
    --fondo: #ffffff; --texto: #1b1b1b; --tenue: #5d5d5d;
    --borde: #e0ddd8; --panel: #faf8f5;
    --verde: #1f6f43; --verde-fondo: #e7f4ec;
    --rojo: #a52121; --rojo-fondo: #fbeaea;
    --cacao: #5b3a25;
  }}
  @media (prefers-color-scheme: dark) {{
    :root:not([data-theme="light"]) {{
      --fondo: #17150f; --texto: #f2efe9; --tenue: #a9a39a;
      --borde: #37322a; --panel: #201d16;
      --verde: #6fd39b; --verde-fondo: #17301f;
      --rojo: #f08a8a; --rojo-fondo: #331a1a;
      --cacao: #d9b08c;
    }}
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; padding: 0 16px 64px;
    background: var(--fondo); color: var(--texto);
    font: 15px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  }}
  .envoltura {{ max-width: 1040px; margin: 0 auto; }}
  header {{ padding: 40px 0 8px; border-bottom: 2px solid var(--cacao); }}
  h1 {{ margin: 0 0 4px; font-size: 1.6rem; letter-spacing: -0.01em; }}
  .sub {{ color: var(--tenue); margin: 0; }}
  .veredicto {{
    margin: 24px 0; padding: 20px 24px; border-radius: 10px;
    border: 1px solid var(--borde);
    background: {"var(--verde-fondo)" if verde else "var(--rojo-fondo)"};
  }}
  .veredicto strong {{
    display: block; font-size: 1.25rem;
    color: {"var(--verde)" if verde else "var(--rojo)"};
  }}
  .cifras {{ display: flex; flex-wrap: wrap; gap: 28px; margin-top: 12px; }}
  .cifra span {{ display: block; font-size: 1.5rem; font-weight: 600; }}
  .cifra small {{ color: var(--tenue); }}
  h2 {{ margin: 36px 0 4px; font-size: 1.15rem; color: var(--cacao); }}
  .meta {{ margin: 0 0 12px; color: var(--tenue); font-size: 0.9rem; }}
  table {{ width: 100%; border-collapse: collapse; font-size: 0.92rem; }}
  th, td {{ padding: 8px 10px; text-align: left; border-bottom: 1px solid var(--borde); }}
  thead th {{
    background: var(--panel); font-weight: 600; font-size: 0.8rem;
    text-transform: uppercase; letter-spacing: 0.04em; color: var(--tenue);
  }}
  td.num, th.num {{ text-align: right; font-variant-numeric: tabular-nums; }}
  td.clase {{ color: var(--tenue); font-family: ui-monospace, monospace; font-size: 0.85rem; }}
  td.estado {{ font-weight: 600; white-space: nowrap; }}
  .aprobado {{ color: var(--verde); }}
  .fallado {{ color: var(--rojo); }}
  tr.detalle td {{ background: var(--rojo-fondo); }}
  pre {{ margin: 0; overflow-x: auto; font-size: 0.82rem; white-space: pre-wrap; }}
  code {{ font-family: ui-monospace, monospace; font-size: 0.85em; }}
  footer {{ margin-top: 48px; padding-top: 16px; border-top: 1px solid var(--borde);
            color: var(--tenue); font-size: 0.85rem; }}
  @media (max-width: 620px) {{
    td.clase {{ display: none; }}
    thead th:nth-child(3) {{ display: none; }}
  }}
</style>
</head>
<body>
<div class="envoltura">
<header>
  <h1>Reporte de ejecucion de pruebas</h1>
  <p class="sub">Artesanal Chocolate Diego · Grupo 8 · Seminario de Tecnologias de Informacion</p>
</header>

<div class="veredicto">
  <strong>{veredicto}</strong>
  <div class="cifras">
    <div class="cifra"><span>{total}</span><small>ejecutadas</small></div>
    <div class="cifra"><span class="aprobado">{aprobadas}</span><small>aprobadas</small></div>
    <div class="cifra"><span class="{"aprobado" if verde else "fallado"}">{fallidas}</span><small>falladas</small></div>
    <div class="cifra"><span>{duracion:.1f} s</span><small>duracion total</small></div>
    <div class="cifra"><span>{len(suites)}</span><small>suites</small></div>
  </div>
</div>

<section>
  <h2>Resumen por tipo de prueba</h2>
  <table>
    <thead><tr><th>Tipo</th><th>Suite</th><th class="num">Casos</th>
    <th class="num">Aprobados</th><th class="num">Fallados</th><th class="num">Duracion</th></tr></thead>
    <tbody>{resumen_suites}</tbody>
  </table>
</section>

{secciones}

<footer>
  Generado el {generado} por <code>scripts/reporte-pruebas.py</code> a partir de los
  informes JUnit de <code>tests/resultados/</code>.
  El plan de pruebas correspondiente esta en <code>docs/devops1/plan-de-pruebas.md</code>.
</footer>
</div>
</body>
</html>
"""


def main() -> int:
    suites: list[Suite] = []
    for archivo, titulo, tipo in SUITES:
        suite = leer_suite(RESULTADOS / archivo, titulo, tipo)
        if suite is None:
            print(f"  [ausente] {archivo}")
            continue
        suites.append(suite)
        print(f"  [leido]   {archivo}: {suite.total} casos, {suite.fallidas} fallan")

    if not suites:
        print(
            "No se encontro ningun informe en tests/resultados/.\n"
            "Ejecute primero: make probar-todo",
            file=sys.stderr,
        )
        return 2

    RESULTADOS.mkdir(parents=True, exist_ok=True)
    DESTINO.write_text(construir(suites), encoding="utf-8")

    total = sum(s.total for s in suites)
    fallidas = sum(s.fallidas for s in suites)
    print()
    print(f"  {total} pruebas · {total - fallidas} pasan · {fallidas} fallan")
    print(f"  Reporte: {DESTINO.relative_to(RAIZ)}")

    return 0 if fallidas == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
