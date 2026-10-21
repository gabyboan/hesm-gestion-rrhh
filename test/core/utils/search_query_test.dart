import 'package:flutter_test/flutter_test.dart';

import 'package:app_horas/core/utils/search_query.dart';

void main() {
  group('SearchQuery', () {
    test('matches name and surname in either order across fields', () {
      final person = ['Pérez', 'Juan Carlos'];

      expect(SearchQuery('Juan Pérez').matches(person), isTrue);
      expect(SearchQuery('Pérez Juan').matches(person), isTrue);
    });

    test('ignores accents, case, extra whitespace, and separators', () {
      final query = SearchQuery('  PEREZ,   juan  ');

      expect(query.matches(['Pérez', 'Juan']), isTrue);
    });

    test('normalizes punctuation in formatted DNI and CUIL', () {
      expect(SearchQuery('26.628.186').matches([26628186]), isTrue);
      expect(SearchQuery('20-26628186-3').matches([20266281863]), isTrue);
    });

    test('requires every term to occur in the record', () {
      expect(SearchQuery('Juan Gómez').matches(['Pérez', 'Juan']), isFalse);
    });

    test('an empty query matches every record', () {
      expect(SearchQuery('   ').matches(['Pérez', 'Juan']), isTrue);
    });
  });
}
