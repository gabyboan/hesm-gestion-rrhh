enum TipoHora { particular, enfermedad, oficial }

extension TipoHoraDb on TipoHora {
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

  bool get requiereMinutos =>
      this == TipoHora.particular || this == TipoHora.oficial;
}
