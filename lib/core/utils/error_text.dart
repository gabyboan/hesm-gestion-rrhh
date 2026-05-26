String cleanError(Object error) {
  final msg = error.toString().trim();
  if (msg.isEmpty) return 'error desconocido';

  return msg.replaceFirst('Exception: ', '');
}
