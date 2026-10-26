/// Contrato compartido por el escritorio y el futuro lector móvil.
/// El código identifica un registro; nunca constituye una autorización.
class ParteMedicoQr {
  const ParteMedicoQr._(this.codigo);

  final String codigo;
  static final _formato = RegExp(r'^[0-9]{8,20}$');

  factory ParteMedicoQr.parse(String value) {
    var codigo = value.trim().toUpperCase();
    if (codigo.startsWith('HESM:PM:')) {
      const prefijo = 'HESM:PM:1:';
      if (!codigo.startsWith(prefijo)) {
        throw const FormatException('Versión de QR no compatible.');
      }
      codigo = codigo.substring(prefijo.length);
    } else if (codigo.startsWith('PM-')) {
      codigo = codigo.substring(3);
    }
    codigo = codigo.replaceAll(RegExp(r'[-\s]'), '');
    if (!_formato.hasMatch(codigo)) {
      throw const FormatException('Ingresá el código completo del parte.');
    }
    var suma = 0;
    var duplicar = false;
    for (var i = codigo.length - 1; i >= 0; i--) {
      var digito = int.parse(codigo[i]);
      if (duplicar) {
        digito *= 2;
        if (digito > 9) {
          digito -= 9;
        }
      }
      suma += digito;
      duplicar = !duplicar;
    }
    if (suma % 10 != 0) {
      throw const FormatException(
          'Revisá el código: hay un número incorrecto.');
    }
    return ParteMedicoQr._(codigo);
  }

  String get contenido => 'HESM:PM:1:$codigo';

  String get codigoManual => 'PM-${[
        for (var i = 0; i < codigo.length; i += 4)
          codigo.substring(i, i + 4 > codigo.length ? codigo.length : i + 4)
      ].join('-')}';
}
