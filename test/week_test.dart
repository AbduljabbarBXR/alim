import 'package:alim/data/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the journey week starts on Monday', () {
    final tuesday = DateTime(2026, 10, 20, 23, 30);
    final start = AlimStore.startOfWeek(tuesday);
    expect(start, DateTime(2026, 10, 19));
    expect(start.weekday, DateTime.monday);
  });

  test('the journey week starts on Monday across a month boundary', () {
    final sunday = DateTime(2026, 11, 1, 8);
    final start = AlimStore.startOfWeek(sunday);
    expect(start, DateTime(2026, 10, 26));
    expect(start.weekday, DateTime.monday);
  });
}
