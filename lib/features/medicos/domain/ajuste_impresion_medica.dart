class AjusteImpresionMedica {
  const AjusteImpresionMedica({
    this.horizontalMm = 0,
    this.verticalMm = 0,
  });

  // Ajustes adicionales a la calibración del formulario. Positivo mueve
  // hacia la derecha / abajo; negativo hacia la izquierda / arriba.
  final double horizontalMm;
  final double verticalMm;
  static const limiteMm = 10.0;

  bool get esValido =>
      horizontalMm.isFinite &&
      verticalMm.isFinite &&
      horizontalMm.abs() <= limiteMm &&
      verticalMm.abs() <= limiteMm;

  Map<String, double> toJson() => {
        'horizontal_mm': horizontalMm,
        'vertical_mm': verticalMm,
      };

  factory AjusteImpresionMedica.fromJson(Map<String, dynamic> json) {
    final horizontal = json['horizontal_mm'];
    final vertical = json['vertical_mm'];
    if (horizontal is! num || vertical is! num) {
      throw const FormatException('Ajuste de impresión inválido.');
    }
    final ajuste = AjusteImpresionMedica(
      horizontalMm: horizontal.toDouble(),
      verticalMm: vertical.toDouble(),
    );
    if (!ajuste.esValido) {
      throw const FormatException('Ajuste de impresión fuera de rango.');
    }
    return ajuste;
  }
}
