String cleanError(Object error) {
  final msg = error.toString().trim();
  if (msg.isEmpty) return 'error desconocido';

  final postgrestMessage = RegExp(
    r'PostgrestException\(message:\s*(.*?),\s*code:',
    dotAll: true,
  ).firstMatch(msg)?.group(1)?.trim();

  final clean =
      (postgrestMessage ?? msg).replaceFirst('Exception: ', '').trim();
  final lower = clean.toLowerCase();

  if (lower.contains('dias consecutivos') ||
      lower.contains('días consecutivos')) {
    return 'No se puede sacar 2 imprevistos de forma contigua.';
  }

  return clean;
}
