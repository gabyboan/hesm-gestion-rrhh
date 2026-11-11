"""Selección conservadora de licencias: nunca corrige ni sustituye un DNI."""
from __future__ import annotations

from collections import Counter
import re

from licencias_excel import normalizar


def palabras(texto: str) -> set[str]:
    return set(re.findall(r'[A-Z]+', normalizar(texto)))


def nombre_compatible(texto: str, apellido: str, nombre: str) -> bool:
    origen, apellidos, nombres = palabras(texto), palabras(apellido), palabras(nombre)
    completo = apellidos | nombres
    return (bool(apellidos) and bool(nombres) and len(origen) >= 2
            and apellidos <= origen and bool(nombres & origen)
            and (origen <= completo or completo <= origen))


def seleccionar(registros: list[dict], personas: dict[int, dict]) -> tuple[list[dict], list[dict]]:
    incluidos, pendientes, usados = [], [], set()
    for r in sorted(registros, key=lambda r: r['fila']):
        p = personas.get(r['dni'])
        motivo = None
        if r['desde'] < '2026-01-01':
            motivo = 'ANTERIOR_2026'
        elif p is None:
            motivo = 'DNI_SIN_FICHA'
        elif not nombre_compatible(r['apellido_nombre'], p['apellido'], p['nombre']):
            motivo = 'DNI_Y_NOMBRE_NO_COINCIDEN'
        llave = (r['dni'], r['tipo'], r['desde'], r['hasta'])
        if motivo is None and llave in usados:
            motivo = 'REPETICION_MISMO_TIPO_Y_PERIODO'
        if motivo:
            pendientes.append(dict(fila=r['fila'], motivo=motivo, datos=r))
        else:
            usados.add(llave)
            incluidos.append(r)
    return incluidos, pendientes


_CODIGOS = {
    'Lic. Anual': '01',
    'Lic. Profiláctica': '03',
    'ART - Licencia': '12',
    'Lic. por Maternidad': '14',
    'Lic. por Donación de Sangre': '26',
    'Lic. por Estudio': '29',
    'Franco': '60',
    'Comisión': '61',
    'Lic. Gremial': '70',
}
_COLUMNAS = {
    'Enf. de Corto Tratamiento': 'ENFERMEDAD',
    'Enf. de LARGO Tratamiento': 'ENFERMEDAD',
    'Cuidado de Fliar. Enfermo': 'ENFERMEDAD',
    'Lic. Profiláctica': 'PROFILACTICA',
    'Lic. por Estudio': 'ESTUDIO',
    'Imprevisto': 'ART8',
    'Falta CON Aviso': 'FALTA_CA',
    'Falta SIN Aviso': 'FALTA_SA',
}


def codigo_importado(tipo: str, dias: int) -> str | None:
    if tipo in _CODIGOS:
        return _CODIGOS[tipo]
    if tipo == 'Enf. de Corto Tratamiento' and dias <= 20:
        return '04'
    if tipo == 'Falta CON Aviso':
        return '62' if dias <= 2 else '63'
    if tipo == 'Falta SIN Aviso' and dias <= 10:
        return '64' if dias <= 2 else '65'
    return None


def columna_original(tipo: str) -> str | None:
    return _COLUMNAS.get(tipo)


def resumir_pendientes(pendientes: list[dict]) -> dict[str, int]:
    return dict(Counter(r['motivo'] for r in pendientes))
