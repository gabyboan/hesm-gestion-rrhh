import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_horas/features/medicos/data/ajuste_impresion_medica_repository.dart';
import 'package:app_horas/features/medicos/data/parte_medico_printer.dart';
import 'package:app_horas/features/medicos/domain/ajuste_impresion_medica.dart';
import 'package:app_horas/features/medicos/domain/medico_domicilio.dart';
import 'package:app_horas/features/medicos/domain/parte_medico.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Impresora extends PrintingPlatform {
  Printer? destino;
  PdfPageFormat? formato;
  bool? dinamico;
  bool? usarPreferencias;
  List<Uint8List> documentos = [];

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
    bool forceCustomPrintPaper,
  ) async {
    destino = printer;
    formato = format;
    dinamico = dynamicLayout;
    usarPreferencias = usePrinterSettings;
    // Simulamos el área imprimible que informa un driver y un segundo callback.
    for (final papel in [format, PdfPageFormat.letter]) {
      documentos.add(await onLayout(papel));
    }
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cada impresora usa su ajuste en la impresión individual y por lotes',
      () async {
    SharedPreferences.setMockInitialValues({});
    const repository = AjusteImpresionMedicaRepository();
    const brother = Printer(url: r'\\equipo\Brother HL-1210W series');
    const canon = Printer(url: r'\\PC01\Canon LBP6030/6040/6018L');
    const ajusteBrother =
        AjusteImpresionMedica(horizontalMm: 1, verticalMm: -2);
    const ajusteCanon =
        AjusteImpresionMedica(horizontalMm: -3, verticalMm: 0.5);
    await repository.guardar(ajusteBrother, impresora: brother.url);
    await repository.guardar(ajusteCanon, impresora: canon.url);
    final parte = ParteMedico.fromJson({
      'id': 42,
      'dni': 12345678,
      'fecha': '2026-11-02',
      'tipo': 'DOMICILIO',
      'empleado_apellido': 'Prueba',
      'empleado_nombre': 'Impresion',
      'codigo_qr': '00000422',
    });
    final original = PrintingPlatform.instance;
    final impresora = _Impresora();
    PrintingPlatform.instance = impresora;
    addTearDown(() => PrintingPlatform.instance = original);

    await ParteMedicoPrinter.imprimir(parte, impresora: brother);
    expect(impresora.destino?.url, brother.url);
    final esperadoBrother = _contenidoCrudoPdf(
        await ParteMedicoPrinter.generar(parte, ajuste: ajusteBrother));
    expect(impresora.documentos.map(_contenidoCrudoPdf),
        everyElement(esperadoBrother));
    expect(impresora.formato?.width, closeTo(210 * PdfPageFormat.mm, 0.001));
    expect(impresora.formato?.height, closeTo(297 * PdfPageFormat.mm, 0.001));
    expect(impresora.formato?.marginLeft, 0);
    expect(impresora.formato?.marginTop, 0);
    expect(impresora.dinamico, isFalse);
    expect(impresora.usarPreferencias, isFalse);

    impresora.documentos.clear();
    await ParteMedicoPrinter.imprimirTodos([parte, parte], impresora: canon);
    expect(impresora.destino?.url, canon.url);
    final esperadoCanon =
        _contenidoCrudoPdf(await ParteMedicoPrinter.generarTodos(
      [parte, parte],
      ajuste: ajusteCanon,
    ));
    expect(impresora.documentos.map(_contenidoCrudoPdf),
        everyElement(esperadoCanon));
    expect(esperadoCanon, isNot(esperadoBrother));
  });

  test('el ajuste mueve exactamente los milímetros pedidos en ambos ejes',
      () async {
    final parte = ParteMedico.fromJson({
      'id': 42,
      'dni': 12345678,
      'fecha': '2026-11-02',
      'tipo': 'CONSULTORIO',
      'empleado_apellido': 'Prueba',
      'empleado_nombre': 'Impresion',
      'codigo_qr': '00000422',
    });
    final base = _traslacionPdf(await ParteMedicoPrinter.generar(parte));
    expect(base.x, closeTo(0.5 * PdfPageFormat.mm, 0.001));
    expect(base.y, closeTo(15 - 0.2 * PdfPageFormat.mm, 0.001));
    for (final paso in [-2.0, -0.1, 0.1, 2.0]) {
      final movido = _traslacionPdf(await ParteMedicoPrinter.generar(parte,
          ajuste: AjusteImpresionMedica(
            horizontalMm: paso,
            verticalMm: paso,
          )));
      expect(movido.x - base.x, closeTo(paso * PdfPageFormat.mm, 0.001));
      // El eje vertical del PDF crece hacia arriba.
      expect(movido.y - base.y, closeTo(-paso * PdfPageFormat.mm, 0.001));
    }
  });

  test('genera un lote con una hoja por parte y conserva el orden', () async {
    final partes = List.generate(
        3,
        (index) => ParteMedico.fromJson({
              'id': index + 1,
              'dni': 23456780 + index,
              'fecha': '2026-10-21',
              'tipo': ['DOMICILIO', 'CONSULTORIO', 'DOMICILIO_FAMILIAR'][index],
              'empleado_apellido': 'Empleado${index + 1}',
              'empleado_nombre': 'Prueba',
              'familiar_apellido_nombre': index == 2 ? 'Familiar, Ana' : null,
              'familiar_edad_meses': index == 2 ? 8 : null,
            }));
    final bytes = await ParteMedicoPrinter.generarTodos(partes);
    final crudo = latin1.decode(bytes);
    expect(RegExp(r'/Type\s*/Page\b').allMatches(crudo), hasLength(3));
    final contenido = _contenidoPdf(bytes);
    expect(contenido.indexOf('Empleado1'),
        lessThan(contenido.indexOf('Empleado2')));
    expect(contenido.indexOf('Empleado2'),
        lessThan(contenido.indexOf('Empleado3')));
    expect(contenido, contains('8 meses'));
  });

  test('rechaza un lote vacío', () async {
    await expectLater(ParteMedicoPrinter.generarTodos([]), throwsArgumentError);
  });

  test('genera el parte y la vista previa de un suplente sin legajo', () async {
    final parte = ParteMedico.fromJson({
      'id': 1,
      'dni': 23456789,
      'fecha': '2026-10-16',
      'tipo': 'CONSULTORIO',
      'empleado_apellido': 'Perez',
      'empleado_nombre': 'Ana',
      'empleado_legajo': null,
    });

    for (final bytes in [
      await ParteMedicoPrinter.generar(parte),
      await ParteMedicoPrinter.generarVistaPrevia(parte),
    ]) {
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    }
  });

  test('genera un PDF imprimible para un parte familiar', () async {
    final parte = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 6, 12),
      tipo: TipoParteMedico.domicilioFamiliar,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Maria',
      empleadoLegajo: 123,
      familiarApellidoNombre: 'Perez, Juan',
      familiarDni: 40123456,
      familiarEdad: 8,
      familiarParentesco: 'Hijo',
    );

    final bytes = await ParteMedicoPrinter.generar(parte);

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('imprime la edad del familiar menor de un año en meses', () async {
    final parte = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 6, 12),
      tipo: TipoParteMedico.domicilioFamiliar,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Maria',
      empleadoLegajo: 123,
      familiarApellidoNombre: 'Perez, Juan',
      familiarEdad: 0,
      familiarEdadMeses: 8,
      familiarParentesco: 'Hijo',
    );

    final contenido = _contenidoPdf(await ParteMedicoPrinter.generar(parte));

    expect(contenido, contains('8 meses'));
    expect(contenido, isNot(contains('0 años')));
  });

  test('imprime en años al cumplir un año', () async {
    final parte = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 6, 12),
      tipo: TipoParteMedico.domicilioFamiliar,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Maria',
      empleadoLegajo: 123,
      familiarApellidoNombre: 'Perez, Juan',
      familiarEdad: 1,
      familiarParentesco: 'Hijo',
    );

    final contenido = _contenidoPdf(await ParteMedicoPrinter.generar(parte));

    expect(contenido, contains('1 año'));
    expect(contenido, isNot(contains('mes')));
  });

  test('usa el mismo tamaño de fuente en todos los campos impresos', () async {
    final parte = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 6, 12),
      tipo: TipoParteMedico.domicilioFamiliar,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Maria',
      empleadoLegajo: 123,
      familiarApellidoNombre: 'Perez, Juan',
      familiarDni: 40123456,
      familiarEdad: 8,
      familiarParentesco: 'Hijo',
      aclaracionFechaTurno: 'Turno de tarde',
      domicilio: const MedicoDomicilio(
        calle: 'San Martin',
        numero: '123',
        barrio: 'Centro',
        referencias: 'Cerca de plaza',
        otrosDatos: 'Casa interna',
      ),
    );

    final tamanos = _tamanosFuentePdf(
      await ParteMedicoPrinter.generar(parte),
    );

    expect(tamanos, isNotEmpty);
    expect(tamanos, everyElement(11.5));
  });

  test('la vista previa incluye el formulario escaneado completo', () async {
    final parte = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 6, 12),
      tipo: TipoParteMedico.domicilio,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Maria',
      empleadoLegajo: 123,
      familiarApellidoNombre: null,
      familiarEdad: null,
      familiarParentesco: null,
      esArt: false,
    );

    final imprimible = await ParteMedicoPrinter.generar(parte);
    final vistaPrevia = await ParteMedicoPrinter.generarVistaPrevia(parte);

    expect(String.fromCharCodes(vistaPrevia.take(4)), '%PDF');
    expect(vistaPrevia.length, greaterThan(imprimible.length));
  });

  test('solo domicilio y familiar tachan la frase del formulario', () {
    expect(TipoParteMedico.consultorio.tachaConsultorio, isFalse);
    expect(TipoParteMedico.canje.tachaConsultorio, isFalse);
    expect(TipoParteMedico.domicilio.tachaConsultorio, isTrue);
    expect(TipoParteMedico.domicilioFamiliar.tachaConsultorio, isTrue);
  });

  test('incluye el domicilio salvo en modalidad consultorio', () async {
    final domicilio = const MedicoDomicilio(
      calle: 'San Martin',
      numero: '123',
      localidad: 'Resistencia',
    );
    final domicilioParte = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 6, 12),
      tipo: TipoParteMedico.domicilio,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Maria',
      empleadoLegajo: 123,
      familiarApellidoNombre: null,
      familiarEdad: null,
      familiarParentesco: null,
      domicilio: domicilio,
    );
    final domicilioSinDatos = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 6, 12),
      tipo: TipoParteMedico.domicilio,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Maria',
      empleadoLegajo: 123,
      familiarApellidoNombre: null,
      familiarEdad: null,
      familiarParentesco: null,
    );
    final consultorioConDomicilio = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 6, 12),
      tipo: TipoParteMedico.consultorio,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Maria',
      empleadoLegajo: 123,
      familiarApellidoNombre: null,
      familiarEdad: null,
      familiarParentesco: null,
      domicilio: domicilio,
    );
    final consultorioSinDomicilio = ParteMedico(
      id: 1,
      dni: 12345678,
      fecha: DateTime(2026, 6, 12),
      tipo: TipoParteMedico.consultorio,
      empleadoApellido: 'Perez',
      empleadoNombre: 'Maria',
      empleadoLegajo: 123,
      familiarApellidoNombre: null,
      familiarEdad: null,
      familiarParentesco: null,
    );

    final domicilioPdf = await ParteMedicoPrinter.generar(domicilioParte);
    final domicilioVacioPdf =
        await ParteMedicoPrinter.generar(domicilioSinDatos);
    final consultorioPdf =
        await ParteMedicoPrinter.generar(consultorioConDomicilio);
    final consultorioVacioPdf =
        await ParteMedicoPrinter.generar(consultorioSinDomicilio);

    expect(domicilioPdf.length, greaterThan(domicilioVacioPdf.length));
    expect(consultorioPdf.length, consultorioVacioPdf.length);
  });

  test('imprime torre en otros datos y la omite para consultorio', () async {
    ParteMedico parte(TipoParteMedico tipo) => ParteMedico(
          id: 1,
          dni: 12345678,
          fecha: DateTime(2026, 10, 20),
          tipo: tipo,
          empleadoApellido: 'Demostracion',
          empleadoNombre: 'Prueba',
          empleadoLegajo: null,
          familiarApellidoNombre: null,
          familiarEdad: null,
          familiarParentesco: null,
          domicilio: const MedicoDomicilio(torre: 'DEMO'),
        );

    final domicilio =
        await ParteMedicoPrinter.generar(parte(TipoParteMedico.domicilio));
    final consultorio =
        await ParteMedicoPrinter.generar(parte(TipoParteMedico.consultorio));
    expect(_contenidoPdf(domicilio), contains('Torre DEMO'));
    expect(_contenidoPdf(consultorio), isNot(contains('Torre DEMO')));
  });

  test('no duplica el número de domicilio en otros datos ni en casa', () async {
    for (final domicilio in [
      const MedicoDomicilio(
        calle: 'Lapacho negro',
        numero: '369',
        otrosDatos: '369',
      ),
      const MedicoDomicilio(
        calle: 'Lapacho negro',
        numero: '369',
        casa: '369',
      ),
    ]) {
      final parte = ParteMedico(
        id: 1,
        dni: 12345678,
        fecha: DateTime(2026, 10, 20),
        tipo: TipoParteMedico.domicilio,
        empleadoApellido: 'Martinez',
        empleadoNombre: 'Hector Miguel',
        empleadoLegajo: 226592,
        familiarApellidoNombre: null,
        familiarEdad: null,
        familiarParentesco: null,
        domicilio: domicilio,
      );

      final contenido = _contenidoPdf(await ParteMedicoPrinter.generar(parte));

      expect(RegExp('369').allMatches(contenido), hasLength(1));
    }
  });
}

String _contenidoPdf(List<int> bytes) {
  final contenido = _contenidoCrudoPdf(bytes);
  // PDF puede posicionar cada palabra con un operador de texto distinto.
  return RegExp(r'\(([^()]*)\)')
      .allMatches(contenido)
      .map((match) => match[1]!)
      .join(' ');
}

List<double> _tamanosFuentePdf(List<int> bytes) {
  final contenido = _contenidoCrudoPdf(bytes);
  return RegExp(r'/F\d+\s+([\d.]+)\s+Tf')
      .allMatches(contenido)
      .map((match) => double.parse(match[1]!))
      .toList();
}

String _contenidoCrudoPdf(List<int> bytes) {
  final pdf = latin1.decode(bytes);
  final streams = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
  return streams.allMatches(pdf).map((match) {
    final stream = latin1.encode(match[1]!);
    try {
      return latin1.decode(zlib.decode(stream));
    } on FormatException {
      return latin1.decode(stream);
    }
  }).join('\n');
}

PdfPoint _traslacionPdf(List<int> bytes) {
  final matriz = RegExp(r'1 0 0 1 ([-\d.]+) ([-\d.]+) cm')
      .firstMatch(_contenidoCrudoPdf(bytes))!;
  return PdfPoint(double.parse(matriz[1]!), double.parse(matriz[2]!));
}
