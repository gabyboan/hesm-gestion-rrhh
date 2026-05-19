// lib/features/horas/domain/tipo_hora.dart

/// Tipos de horas soportados por el sistema.
enum TipoHora {
  particular,
  enfermedad,
  oficial,
}

extension TipoHoraDb on TipoHora {
  /// Valor esperado por Supabase/Postgres.
  String get db {
    switch (this) {
      case TipoHora.particular:
        return 'PARTICULAR';
      case TipoHora.enfermedad:
        return 'ENFERMEDAD';
      case TipoHora.oficial:
        return 'OFICIAL';
    }
  }

  /// Etiqueta visible para UI.
  String get label {
    switch (this) {
      case TipoHora.particular:
        return 'Particular';
      case TipoHora.enfermedad:
        return 'Enfermedad';
      case TipoHora.oficial:
        return 'Oficial';
    }
  }

  /// Indica si el tipo requiere cargar cantidad de minutos.
  bool get requiereMinutos {
    switch (this) {
      case TipoHora.particular:
      case TipoHora.oficial:
        return true;
      case TipoHora.enfermedad:
        return false;
    }
  }

  bool get esParticular => this == TipoHora.particular;

  bool get esEnfermedad => this == TipoHora.enfermedad;

  bool get esOficial => this == TipoHora.oficial;
}

extension TipoHoraParser on TipoHora {
  /// Convierte un valor de base de datos a [TipoHora].
  ///
  /// Acepta valores con espacios o diferencias de mayúsculas/minúsculas.
  static TipoHora fromDb(String value) {
    final normalized = value.trim().toUpperCase();

    switch (normalized) {
      case 'PARTICULAR':
        return TipoHora.particular;
      case 'ENFERMEDAD':
        return TipoHora.enfermedad;
      case 'OFICIAL':
        return TipoHora.oficial;
      default:
        throw FormatException('TipoHora desconocido: $value');
    }
  }

  /// Versión tolerante.
  ///
  /// Devuelve `null` si el valor no coincide con ningún tipo soportado.
  static TipoHora? tryFromDb(String? value) {
    if (value == null) return null;

    try {
      return fromDb(value);
    } catch (_) {
      return null;
    }
  }
}
