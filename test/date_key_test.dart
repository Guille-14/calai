import 'package:flutter_test/flutter_test.dart';
import 'package:calorie_lens/core/utils/date_key.dart';

void main() {
  group('formatDateKey', () {
    test('normaliza mes y día con ceros para persistencia', () {
      expect(formatDateKey(DateTime(2026, 1, 7, 23, 59)), '2026-01-07');
    });

    test('conserva el año y no depende de la hora', () {
      expect(formatDateKey(DateTime(2030, 12, 31)), '2030-12-31');
      expect(formatDateKey(DateTime(2030, 12, 31, 0, 1)), '2030-12-31');
    });
  });
}
