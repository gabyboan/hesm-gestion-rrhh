/// The same normalization rules are used by the database search functions.
/// All terms must occur in the record, in any order and across any fields.
class SearchQuery {
  SearchQuery(String? query) : terms = tokenize(query);

  final List<String> terms;

  bool matches(Iterable<Object?> fields) {
    if (terms.isEmpty) return true;
    final text = normalize(fields.whereType<Object>().join(' '));
    return terms.every(text.contains);
  }

  static List<String> tokenize(String? value) {
    final text = normalize(value);
    return text.isEmpty ? const [] : text.split(' ').toSet().toList();
  }

  static String normalize(String? value) {
    var text = (value ?? '').toLowerCase();
    const accented = 'áàäâãåéèëêíìïîóòöôõúùüûñç';
    const plain = 'aaaaaaeeeeiiiiooooouuuunc';
    for (var i = 0; i < accented.length; i++) {
      text = text.replaceAll(accented[i], plain[i]);
    }
    text = text.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
    // A formatted DNI/CUIL is one term, even alongside a name.
    text = text.replaceAllMapped(RegExp(r'[0-9]+(?:[.,-][0-9]+)+'),
        (match) => match[0]!.replaceAll(RegExp(r'[.,-]'), ''));
    return text.replaceAll(RegExp(r'[\s,;:()/\\|+\-]+'), ' ').trim();
  }
}
