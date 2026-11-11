class LicenciaTipo {
  const LicenciaTipo(
      {required this.id,
      required this.nombre,
      this.codigo,
      this.columnaFicha,
      this.categoriaExcelId,
      this.descripcion});
  final int id;
  final String nombre;
  final String? codigo;
  final String? columnaFicha;
  final int? categoriaExcelId;
  final String? descripcion;
  String get etiqueta => codigo == null ? nombre : '$codigo · $nombre';

  factory LicenciaTipo.fromJson(Map<String, dynamic> json) => LicenciaTipo(
        id: (json['id'] as num).toInt(),
        nombre: json['nombre'] as String,
        codigo: json['codigo'] as String?,
        columnaFicha: json['columna_ficha'] as String?,
        categoriaExcelId: (json['categoria_excel_id'] as num?)?.toInt(),
        descripcion: json['descripcion'] as String?,
      );
}

class LicenciaPersona {
  const LicenciaPersona({
    required this.dni,
    required this.nombre,
    this.legajo,
    this.carrera = '',
    this.situacion = '',
    this.funcion = '',
    this.activo = true,
  });
  final int dni;
  final String nombre;
  final int? legajo;
  final String carrera;
  final String situacion;
  final String funcion;
  final bool activo;

  factory LicenciaPersona.fromJson(Map<String, dynamic> json) =>
      LicenciaPersona(
        dni: (json['dni'] as num).toInt(),
        nombre: json['apellido_nombre'] as String,
        legajo: (json['legajo'] as num?)?.toInt(),
        carrera: json['carrera'] as String? ?? '',
        situacion: json['situacion_revista'] as String? ?? '',
        funcion: json['funcion'] as String? ?? '',
        activo: json['activo'] == true,
      );
}

class LicenciaRegistro {
  const LicenciaRegistro({
    required this.id,
    required this.dni,
    required this.nombre,
    required this.tipoId,
    required this.tipo,
    required this.desde,
    required this.hasta,
    required this.dias,
    this.carrera = '',
    this.situacion = '',
    this.funcion = '',
    this.observacion,
    this.anulado = false,
    this.origenFila,
    this.codigo,
    this.columnaFicha,
    this.dniFamiliar,
    this.numeroOrden,
    this.cantidadFicha,
    this.imprevistoId,
    this.diasCalendario,
    this.diasPorAnio,
    this.categoriaExcelId,
    this.cantidadDiasFicha,
    this.anioCupo,
    this.origenDocumento,
    this.origenPagina,
    this.documentacionPendiente = false,
  });
  final int id;
  final int dni;
  final String nombre;
  final int tipoId;
  final int? categoriaExcelId;
  final String tipo;
  final DateTime desde;
  final DateTime hasta;
  final int dias;
  final String carrera;
  final String situacion;
  final String funcion;
  final String? observacion;
  final bool anulado;
  final int? origenFila;
  final String? codigo;
  final String? columnaFicha;
  final int? dniFamiliar;
  final int? numeroOrden;
  final String? cantidadFicha;
  final int? imprevistoId;
  final int? cantidadDiasFicha;
  final int? anioCupo;
  final String? origenDocumento;
  final int? origenPagina;
  final bool documentacionPendiente;
  String get estado => anulado
      ? 'Anulada'
      : documentacionPendiente
          ? 'Documentación pendiente'
          : 'Vigente';
  String? get referenciaOrigen => origenDocumento == 'PDF'
      ? 'PDF: página $origenPagina, renglón ${(origenFila ?? 0) % 100}'
      : origenFila != null
          ? 'Excel: fila $origenFila'
          : null;
  bool get esImprevisto => imprevistoId != null;
  final int? diasCalendario;
  final Map<int, int>? diasPorAnio;
  bool get esEstudio => codigo == '29';
  String get unidadDias => esEstudio
      ? 'días hábiles'
      : cantidadDiasFicha != null
          ? 'días según ficha'
          : 'días';
  String get etiqueta => codigo == null ? tipo : '$codigo · $tipo';

  factory LicenciaRegistro.fromJson(Map<String, dynamic> json) =>
      LicenciaRegistro(
        id: (json['id'] as num).toInt(),
        dni: (json['dni'] as num).toInt(),
        nombre: json['apellido_nombre'] as String,
        tipoId: (json['tipo_id'] as num).toInt(),
        categoriaExcelId: (json['categoria_excel_id'] as num?)?.toInt(),
        tipo: (json['tipo'] as Map?)?['nombre'] as String? ?? '',
        desde: DateTime.parse(json['desde'] as String),
        hasta: DateTime.parse(json['hasta'] as String),
        dias: (json['dias'] as num).toInt(),
        carrera: json['carrera'] as String? ?? '',
        situacion: json['situacion_revista'] as String? ?? '',
        funcion: json['funcion'] as String? ?? '',
        observacion: json['observacion'] as String?,
        anulado: json['anulado_at'] != null,
        origenFila: (json['origen_fila'] as num?)?.toInt(),
        codigo: (json['tipo'] as Map?)?['codigo'] as String?,
        columnaFicha: (json['tipo'] as Map?)?['columna_ficha'] as String?,
        dniFamiliar: (json['dni_familiar'] as num?)?.toInt(),
        numeroOrden: (json['numero_orden'] as num?)?.toInt(),
        cantidadFicha: json['cantidad_ficha'] as String?,
        imprevistoId: (json['imprevisto_id'] as num?)?.toInt(),
        cantidadDiasFicha: (json['cantidad_dias_ficha'] as num?)?.toInt(),
        anioCupo: (json['anio_cupo'] as num?)?.toInt(),
        origenDocumento: json['origen_documento'] as String?,
        origenPagina: (json['origen_pagina'] as num?)?.toInt(),
        documentacionPendiente: json['documentacion_pendiente'] == true,
        diasCalendario: (json['dias_calendario'] as num?)?.toInt(),
        diasPorAnio: (json['dias_por_anio'] as Map?)?.map((key, value) =>
            MapEntry(int.parse(key.toString()), (value as num).toInt())),
      );

  LicenciaPersona get persona => LicenciaPersona(
        dni: dni,
        nombre: nombre,
        carrera: carrera,
        situacion: situacion,
        funcion: funcion,
      );
}

/// Usa fechas UTC de calendario para que el horario de verano no quite días.
int diasLicencia(DateTime desde, DateTime hasta) =>
    DateTime.utc(hasta.year, hasta.month, hasta.day)
        .difference(DateTime.utc(desde.year, desde.month, desde.day))
        .inDays +
    1;

DateTime hastaLicencia(DateTime desde, int dias) {
  final fecha = DateTime.utc(desde.year, desde.month, desde.day + dias - 1);
  return DateTime(fecha.year, fecha.month, fecha.day);
}
