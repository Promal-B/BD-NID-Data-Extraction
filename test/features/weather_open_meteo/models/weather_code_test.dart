import 'package:flutter_test/flutter_test.dart';
import 'package:poc_kyc/features/weather_open_meteo/models/weather_code.dart';

void main() {
  group('WeatherCode.fromCode', () {
    test('maps Open-Meteo weather codes to their descriptions', () {
      expect(WeatherCode.fromCode(0), WeatherCode.clearSky);
      expect(WeatherCode.fromCode(61), WeatherCode.slightRain);
      expect(WeatherCode.fromCode(99), WeatherCode.thunderstormWithHeavyHail);
    });

    test('maps unrecognized codes to unknown', () {
      expect(WeatherCode.fromCode(999), WeatherCode.unknown);
    });
  });
}
