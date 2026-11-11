import '../../licencias/domain/licencia.dart';

class FichaTipoResumen {
  const FichaTipoResumen(
      {required this.tipo, required this.registros, required this.dias});
  final String tipo;
  final int registros;
  final int dias;
}

/// Los días de una licencia que cruza el año se cuentan solo en el año mostrado.
List<FichaTipoResumen> resumirLicencias(
    List<LicenciaRegistro> registros, int anio) {
  final inicio = DateTime(anio, 1, 1);
  final fin = DateTime(anio, 12, 31);
  final grupos = <String, ({int cantidad, int dias})>{};
  for (final registro in registros) {
    if (registro.anulado ||
        registro.hasta.isBefore(inicio) ||
        registro.desde.isAfter(fin)) {
      continue;
    }
    final desde = registro.desde.isBefore(inicio) ? inicio : registro.desde;
    final hasta = registro.hasta.isAfter(fin) ? fin : registro.hasta;
    final previo = grupos[registro.etiqueta] ?? (cantidad: 0, dias: 0);
    grupos[registro.etiqueta] = (
      cantidad: previo.cantidad + 1,
      dias: previo.dias +
          (registro.diasPorAnio != null
              ? registro.diasPorAnio![anio] ?? 0
              : diasLicencia(desde, hasta))
    );
  }
  final keys = grupos.keys.toList()..sort();
  return [
    for (final tipo in keys)
      FichaTipoResumen(
          tipo: tipo,
          registros: grupos[tipo]!.cantidad,
          dias: grupos[tipo]!.dias)
  ];
}
