import 'package:adhan_dart/adhan_dart.dart' as adhan;

import 'location.dart';

/// The five prayers plus sunrise, named the way the app speaks about them.
enum AlimPrayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

String prayerLabel(AlimPrayer prayer) => switch (prayer) {
      AlimPrayer.fajr => 'Fajr',
      AlimPrayer.sunrise => 'Sunrise',
      AlimPrayer.dhuhr => 'Dhuhr',
      AlimPrayer.asr => 'Asr',
      AlimPrayer.maghrib => 'Maghrib',
      AlimPrayer.isha => 'Isha',
    };

/// The calculation methods offered in the app, keyed by profile value.
const prayerMethods = <String, String>{
  'muslimWorldLeague': 'Muslim World League',
  'egyptian': 'Egyptian Authority',
  'karachi': 'Karachi',
  'northAmerica': 'North America (ISNA)',
  'ummAlQura': 'Umm al-Qura',
  'turkiye': 'Diyanet (Turkey)',
};

adhan.Prayer _toAdhan(AlimPrayer prayer) => switch (prayer) {
      AlimPrayer.fajr => adhan.Prayer.fajr,
      AlimPrayer.sunrise => adhan.Prayer.sunrise,
      AlimPrayer.dhuhr => adhan.Prayer.dhuhr,
      AlimPrayer.asr => adhan.Prayer.asr,
      AlimPrayer.maghrib => adhan.Prayer.maghrib,
      AlimPrayer.isha => adhan.Prayer.isha,
    };

adhan.CalculationParameters _parameters(
  String method, {
  required bool asrHanafi,
}) {
  final params = switch (method) {
    'egyptian' => adhan.CalculationMethodParameters.egyptian(),
    'karachi' => adhan.CalculationMethodParameters.karachi(),
    'northAmerica' => adhan.CalculationMethodParameters.northAmerica(),
    'ummAlQura' => adhan.CalculationMethodParameters.ummAlQura(),
    'turkiye' => adhan.CalculationMethodParameters.turkiye(),
    _ => adhan.CalculationMethodParameters.muslimWorldLeague(),
  };
  params.madhab = asrHanafi ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
  return params;
}

/// One day of prayer times for one place.
class PrayerDay {
  PrayerDay(this.place, this._times);

  final AlimLocation place;
  final adhan.PrayerTimes _times;

  static PrayerDay forPlace({
    required AlimLocation place,
    required DateTime day,
    required String method,
    required bool asrHanafi,
  }) {
    return PrayerDay(
      place,
      adhan.PrayerTimes(
        date: day,
        coordinates: adhan.Coordinates(place.latitude, place.longitude),
        calculationParameters: _parameters(method, asrHanafi: asrHanafi),
      ),
    );
  }

  DateTime timeOf(AlimPrayer prayer) =>
      _times.timeForPrayer(_toAdhan(prayer)).toLocal();

  /// The prayer being waited for right now.
  AlimPrayer get next {
    final p = _times.nextPrayer();
    return switch (p) {
      adhan.Prayer.fajr || adhan.Prayer.fajrAfter => AlimPrayer.fajr,
      adhan.Prayer.sunrise => AlimPrayer.sunrise,
      adhan.Prayer.dhuhr => AlimPrayer.dhuhr,
      adhan.Prayer.asr => AlimPrayer.asr,
      adhan.Prayer.maghrib => AlimPrayer.maghrib,
      adhan.Prayer.isha || adhan.Prayer.ishaBefore => AlimPrayer.isha,
    };
  }
}

/// Degrees from true north towards the Kaaba.
double qiblaBearing(AlimLocation place) => adhan.Qibla.qibla(
      adhan.Coordinates(place.latitude, place.longitude),
    );

/// How far apart two headings are, the short way round.
double headingDelta(double a, double b) {
  var diff = (a - b) % 360;
  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;
  return diff;
}
