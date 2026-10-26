"""Verifica los PDF ficticios generados por generate_parte_qr_preview_test.dart.

Requiere PyMuPDF, Pillow y zxing-cpp en el entorno de Python o build/qr-tools.
"""
from pathlib import Path
import sys

sys.path.insert(0, str(Path('build/qr-tools').resolve()))
import fitz
import zxingcpp
from PIL import Image

root = Path('build/qr-preview')
expected = 'HESM:PM:1:00000422'
for filename in ['parte-con-qr.pdf', 'impresion-con-qr.pdf']:
    with fitz.open(root / filename) as document:
        page = document[0]
        assert 'PM-0000-0422' in page.get_text()
        for dpi in [150, 300]:
            pix = page.get_pixmap(dpi=dpi)
            image = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
            results = zxingcpp.read_barcodes(image)
            assert len(results) == 1 and results[0].text == expected, (filename, dpi, results)
            # Una hoja rotada también debe poder leerse con el celular.
            rotated = zxingcpp.read_barcodes(image.rotate(90, expand=True))
            assert len(rotated) == 1 and rotated[0].text == expected
            print(f'OK: {filename}, {dpi} dpi, normal y rotado, {results[0].text}')
        if filename == 'parte-con-qr.pdf':
            page.get_pixmap(dpi=144).save(root / 'parte-con-qr.png')
