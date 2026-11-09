import 'package:open_meteo/open_meteo.dart';

class WeatherResult {
  const WeatherResult({
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.timezone,
    required this.timezoneAbbreviation,
    required this.utcOffset,
    required this.model,
    required this.currentData,
    required this.observedAt,
  });

  final String locationName;
  final double latitude;
  final double longitude;
  final double elevation;
  final String? timezone;
  final String? timezoneAbbreviation;
  final Duration utcOffset;
  final OpenMeteoModel model;
  final Map<WeatherCurrent, ParameterValue> currentData;
  final DateTime observedAt;
}
