import 'package:alim/services/notifications.dart';
import 'package:alim/services/prayer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adhan prayers round trip through csv', () {
    final csv = Notifications.prayersToCsv([AlimPrayer.fajr, AlimPrayer.isha]);
    expect(csv, 'fajr,isha');
    expect(Notifications.prayersFromCsv(csv), [
      AlimPrayer.fajr,
      AlimPrayer.isha,
    ]);
    expect(Notifications.prayersFromCsv(null), isEmpty);
    expect(Notifications.prayersFromCsv(''), isEmpty);
  });

  test('adhan ids do not collide across a month', () {
    final ids = <int>{};
    for (var day = 0; day < Notifications.adhanHorizonDays; day++) {
      for (final prayer in Notifications.adhanPrayers) {
        expect(prayer, isNot(AlimPrayer.sunrise));
        final id = Notifications.adhanSlotId(day, prayer);
        expect(ids.add(id), isTrue);
        expect(id, inInclusiveRange(100, 999));
      }
    }
  });
}
