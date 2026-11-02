import '../../../core/utils/date_fmt.dart';
import 'parte_medico.dart';

String listadoParaEnfermeria(List<ParteMedico> partes,
    {required DateTime fechaEnvio}) {
  final ordenados = partes.where((parte) => parte.esEnfermeria).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  String limpiar(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
  final listado = ordenados.map((parte) {
    final aclaracion = limpiar(parte.aclaracionFechaTurno ?? '');
    return [
      parte.tipo.codigo,
      limpiar(parte.empleadoCompleto),
      if (parte.esArt) 'ART',
      if (aclaracion.isNotEmpty) aclaracion,
    ].join(' — ');
  }).join('\n');
  return 'Fecha: ${DateFmt.ddmmyyyy(fechaEnvio)}\n\n$listado';
}
