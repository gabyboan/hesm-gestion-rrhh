import '../../../core/utils/date_fmt.dart';
import 'parte_medico.dart';

String listadoParaEnfermeria(List<ParteMedico> partes, DateTime fecha) {
  final ordenados = partes.where((parte) => parte.esEnfermeria).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  String limpiar(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return [
    'Partes médicos para Enfermería — ${DateFmt.ddmmyyyy(fecha)}',
    'Total: ${ordenados.length}',
    '',
    for (var i = 0; i < ordenados.length; i++) ...[
      '${i + 1}. ${ordenados[i].tipo.codigo} — ${limpiar(ordenados[i].empleadoCompleto)}',
      'DNI: ${ordenados[i].dni} · '
          '${ordenados[i].empleadoLegajo == null ? 'Sin legajo' : 'Legajo: ${ordenados[i].empleadoLegajo}'}'
          '${ordenados[i].esArt ? ' · ART' : ''}',
      'Solicitud: ${ordenados[i].tipo.label} · Parte N.º ${ordenados[i].id}',
      if (ordenados[i].tipo.requiereFamiliar)
        'Familiar: ${limpiar(ordenados[i].familiarApellidoNombre ?? '')}'
            '${ordenados[i].familiarDni == null ? '' : ' · DNI: ${ordenados[i].familiarDni}'}'
            '${ordenados[i].familiarParentesco == null ? '' : ' · ${limpiar(ordenados[i].familiarParentesco!)}'}'
            '${ordenados[i].familiarEdadMeses != null ? ' · ${ordenados[i].familiarEdadMeses} meses' : ordenados[i].familiarEdad != null ? ' · ${ordenados[i].familiarEdad} años' : ''}',
      'Observaciones: ${limpiar(ordenados[i].aclaracionFechaTurno ?? '').isEmpty ? 'Sin aclaraciones' : limpiar(ordenados[i].aclaracionFechaTurno!)}',
      if (ordenados[i].qr != null) 'Código: ${ordenados[i].qr!.codigoManual}',
      '',
    ],
  ].join('\n').trimRight();
}
