String ensureFileExtension(String path, String extension) {
  final normalizedExtension = extension.startsWith('.')
      ? extension.toLowerCase()
      : '.$extension'.toLowerCase();

  if (path.toLowerCase().endsWith(normalizedExtension)) {
    return path;
  }

  return '$path$normalizedExtension';
}
