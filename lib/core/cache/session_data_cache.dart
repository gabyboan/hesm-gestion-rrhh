/// Caché acotada en memoria. Los errores no se conservan y las lecturas
/// simultáneas de la misma clave comparten una sola solicitud.
class SessionDataCache {
  SessionDataCache({this.maxEntries = 48, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final int maxEntries;
  final DateTime Function() _now;
  final _entries = <Object, _CacheEntry>{};
  bool _disposed = false;
  int get length => _entries.length;

  Future<T> read<T>(String group, Object key, Future<T> Function() load,
      {Duration ttl = const Duration(seconds: 30)}) {
    if (_disposed) return Future<T>.sync(load);
    final cacheKey = (group, key);
    final previous = _entries.remove(cacheKey);
    if (previous != null &&
        (previous.expires == null || _now().isBefore(previous.expires!))) {
      _entries[cacheKey] = previous;
      return previous.future as Future<T>;
    }
    final entry = _CacheEntry();
    final future = Future<T>.sync(load).then((value) {
      entry.expires = _now().add(ttl);
      return value;
    }, onError: (Object error, StackTrace stack) {
      if (identical(_entries[cacheKey], entry)) _entries.remove(cacheKey);
      Error.throwWithStackTrace(error, stack);
    });
    entry.future = future;
    _entries[cacheKey] = entry;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return future;
  }

  void invalidate(String group) =>
      _entries.removeWhere((key, _) => (key as (String, Object)).$1 == group);

  void clear() => _entries.clear();

  void dispose() {
    _disposed = true;
    clear();
  }
}

class _CacheEntry {
  late Future<dynamic> future;
  DateTime? expires;
}
