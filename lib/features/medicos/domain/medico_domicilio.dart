class MedicoDomicilio {
  final String? calle;
  final String? numero;
  final String? barrio;
  final String? torre;
  final String? manzana;
  final String? lote;
  final String? casa;
  final String? monoblock;
  final String? piso;
  final String? departamento;
  final String? referencias;
  final String? otrosDatos;
  final String? localidad;
  final String? provincia;

  const MedicoDomicilio({
    this.calle,
    this.numero,
    this.barrio,
    this.torre,
    this.manzana,
    this.lote,
    this.casa,
    this.monoblock,
    this.piso,
    this.departamento,
    this.referencias,
    this.otrosDatos,
    this.localidad,
    this.provincia,
  });

  bool get estaVacio => [
        calle,
        numero,
        barrio,
        torre,
        manzana,
        lote,
        casa,
        monoblock,
        piso,
        departamento,
        referencias,
        otrosDatos,
        localidad,
        provincia,
      ].every((value) => value == null || value.trim().isEmpty);

  String? get localidadExterna {
    final localidadNormalizada =
        localidad?.trim().toLowerCase().replaceAll('á', 'a');
    if (localidadNormalizada == null ||
        localidadNormalizada.isEmpty ||
        localidadNormalizada == 'parana') {
      return null;
    }

    final ubicacion = [
      localidad,
      if (provincia?.isNotEmpty == true) provincia,
    ].whereType<String>().join(', ');
    return ubicacion;
  }

  factory MedicoDomicilio.fromJson(Map<String, dynamic> json) {
    return MedicoDomicilio(
      calle: _asNullableString(json['calle']),
      numero: _asNullableString(json['numero']),
      barrio: _asNullableString(json['barrio']),
      torre: _asNullableString(json['torre']),
      manzana: _asNullableString(json['manzana']),
      lote: _asNullableString(json['lote']),
      casa: _asNullableString(json['casa']),
      monoblock: _asNullableString(json['monoblock']),
      piso: _asNullableString(json['piso']),
      departamento: _asNullableString(json['departamento']),
      referencias: _asNullableString(json['referencias']),
      otrosDatos: _asNullableString(json['otros_datos']),
      localidad: _asNullableString(json['localidad_nombre']),
      provincia: _asNullableString(json['provincia_nombre']),
    );
  }

  static String? _asNullableString(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }
}
