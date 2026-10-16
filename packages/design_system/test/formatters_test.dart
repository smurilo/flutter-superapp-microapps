import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('formats and parses BRL using integer cents', () {
    expect(Money.format(123456), r'R$ 1.234,56');
    expect(Money.format(-8000), r'-R$ 80,00');
    expect(Money.parse('1.234,56'), 123456);
    expect(Money.parse(r'R$ 10,5'), 1050);
    expect(Money.parse('99.90'), 9990);
    expect(Money.parse('12,345'), isNull);
    expect(Money.parse('abc'), isNull);
  });

  test('relative day headers', () {
    final now = DateTime(2026, 3, 5, 12);
    expect(Dates.dayHeader(DateTime(2026, 3, 5, 8), now: now), 'Hoje');
    expect(Dates.dayHeader(DateTime(2026, 3, 4, 23), now: now), 'Ontem');
    expect(Dates.dayHeader(DateTime(2026, 3, 2), now: now), 'Segunda-feira, 2 de março');
  });
}
