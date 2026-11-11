"""Lectura del historial de licencias sin ejecutar macros ni modificar el Excel."""
from __future__ import annotations

from collections import Counter
from datetime import date, timedelta
from decimal import Decimal, InvalidOperation
import hashlib
from io import BytesIO
from pathlib import Path
import re
import unicodedata
import xml.etree.ElementTree as ET
from zipfile import ZipFile

NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}


def normalizar(texto: str) -> str:
    return ' '.join(''.join(c for c in unicodedata.normalize('NFKD', texto)
                            if not unicodedata.combining(c)).upper().split())


def entero(valor: str) -> int:
    try:
        numero = Decimal(valor)
    except InvalidOperation:
        raise ValueError('Falta un valor numérico o su formato es inválido.') from None
    if not numero.is_finite() or numero != numero.to_integral_value():
        raise ValueError('Se esperaba un entero.')
    return int(numero)


def dni_excel(valor: str) -> int:
    valor = valor.strip()
    # Excel contiene DNI como texto con separadores de miles.
    if re.fullmatch(r'\d{1,3}([.,])\d{3}\1\d{3}', valor):
        valor = valor.replace(',', '').replace('.', '')
    dni = entero(valor)
    if not 1_000_000 <= dni <= 99_999_999:
        raise ValueError('DNI fuera de rango.')
    return dni


def fecha_excel(valor: str) -> date:
    dias = entero(valor)
    if dias < 61 or dias > 2958465:
        raise ValueError('Fecha Excel fuera de rango.')
    return date(1899, 12, 30) + timedelta(days=dias)


def leer_licencias(path: Path) -> dict:
    contenido = path.read_bytes()
    huella = hashlib.sha256(contenido).hexdigest()
    with ZipFile(BytesIO(contenido)) as book:
        strings = []
        if 'xl/sharedStrings.xml' in book.namelist():
            strings = [''.join(t.text or '' for t in s.iter('{%s}t' % NS['m']))
                       for s in ET.fromstring(book.read('xl/sharedStrings.xml'))]
        workbook = ET.fromstring(book.read('xl/workbook.xml'))
        props = workbook.find('m:workbookPr', NS)
        if props is not None and props.get('date1904') in ('1', 'true'):
            raise ValueError('Este importador requiere fechas Excel del sistema 1900.')
        rels = {r.get('Id'): r.get('Target') for r in
                ET.fromstring(book.read('xl/_rels/workbook.xml.rels'))}
        sheets = {}
        for sheet in workbook.find('m:sheets', NS):
            rel = sheet.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id')
            target = rels[rel]
            xmlpath = target.lstrip('/') if target.startswith('/') else 'xl/' + target
            rows = []
            for row in ET.fromstring(book.read(xmlpath)).findall('m:sheetData/m:row', NS):
                cells = {}
                for cell in row:
                    v = cell.find('m:v', NS)
                    value = v.text if v is not None else ''.join(cell.find('m:is', NS).itertext()) if cell.find('m:is', NS) is not None else ''
                    if cell.get('t') == 's':
                        value = strings[int(value)]
                    cells[re.sub(r'\d', '', cell.get('r'))] = value or ''
                rows.append((int(row.get('r')), cells))
            sheets[sheet.get('name')] = rows
    tipos = [r['B'].strip() for n, r in sheets['Carga de Datos']
             if 25 <= n <= 54 and r.get('B', '').strip()]
    registros, pendientes = [], []
    for fila, cells in sheets['Informe']:
        if fila == 1 or not any(cells.get(c, '') for c in 'ABCDEF'):
            continue
        raw = {c: cells.get(c, '') for c in 'ABCDEF'}
        try:
            dni = dni_excel(raw['A'])
            desde, hasta = fecha_excel(raw['D']), fecha_excel(raw['E'])
            cantidad = entero(raw['F'])
            if hasta < desde or cantidad != (hasta - desde).days + 1 or cantidad <= 0:
                raise ValueError('Fechas y cantidad de días inconsistentes.')
            if not raw['B'].strip() or raw['C'].strip() not in tipos:
                raise ValueError('Nombre o tipo de licencia inválido.')
            registros.append(dict(fila=fila, dni=dni, apellido_nombre=raw['B'].strip(),
                                  tipo=raw['C'].strip(), desde=desde.isoformat(),
                                  hasta=hasta.isoformat(), dias=cantidad, original=raw))
        except (ValueError, InvalidOperation, OverflowError) as error:
            pendientes.append(dict(fila=fila, motivo=str(error) or 'Datos incompletos.', original=raw))
    repetidos = Counter((r['dni'], r['tipo'], r['desde'], r['hasta']) for r in registros)
    return dict(sha256=huella, tipos=tipos, registros=registros, pendientes=pendientes,
                duplicados_origen=sum(n - 1 for n in repetidos.values() if n > 1))
