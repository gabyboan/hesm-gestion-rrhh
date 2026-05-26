import 'package:intl/intl.dart';

class DateFmt {
  static final _ddmmyyyy = DateFormat('dd/MM/yyyy');
  static final _yyyymmdd = DateFormat('yyyy-MM-dd');

  // UI: mes/año en español
  static final _mesSoloEs = DateFormat('MMMM', 'es'); // "febrero"
  static final _anio = DateFormat('yyyy'); // "2026"

  static String ddmmyyyy(DateTime d) => _ddmmyyyy.format(d);
  static String ddmm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  static String yyyymmdd(DateTime d) => _yyyymmdd.format(d);

  static String hhmmCorto(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return "$m'";
    return "$h:${m.toString().padLeft(2, '0')}";
  }

  static String resumenFechasDdmm(Map<DateTime, int> porDia) {
    if (porDia.isEmpty) return '';
    final dias = porDia.keys.toList()..sort();
    return dias.map(ddmm).join(' | ');
  }

  static String resumenMinutosConFecha(Map<DateTime, int> porDia) {
    if (porDia.isEmpty) return '';
    final dias = porDia.keys.toList()..sort();
    return dias.map((d) => '${hhmmCorto(porDia[d]!)} ${ddmm(d)}').join(' | ');
  }

  /// Primer día del mes de una fecha.
  static DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);

  /// Periodo actual = primer día del mes actual.
  static DateTime periodoActual() => monthStart(DateTime.now());

  /// Suma/resta meses (maneja rollover año/mes).
  static DateTime addMonths(DateTime d, int delta) =>
      DateTime(d.year, d.month + delta, 1);

  /// Nombre del mes en español (capitalizado) ej: "Febrero"
  static String mesNombre(DateTime d) {
    final s = _mesSoloEs.format(d);
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Alias para la UI (DateFmt.mes(periodo))
  static String mes(DateTime d) => mesNombre(d);

  /// Año ej: "2026"
  static String anio(DateTime d) => _anio.format(d);

  /// Base robusta: devuelve el mes más “nuevo” entre dos fechas
  /// (comparando por año/mes y normalizando al primer día).
  static DateTime maxMonthStart(DateTime a, DateTime b) {
    final aa = monthStart(a);
    final bb = monthStart(b);

    if (aa.year != bb.year) return aa.year > bb.year ? aa : bb;
    return aa.month >= bb.month ? aa : bb;
  }

  /// Lista de meses hacia atrás (incluye el base).
  static List<DateTime> mesesHaciaAtras({
    required DateTime base,
    int count = 36,
  }) {
    final b = monthStart(base);
    return List.generate(count, (i) => addMonths(b, -i));
  }
}
