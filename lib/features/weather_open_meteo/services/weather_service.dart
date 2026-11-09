import 'package:geolocator/geolocator.dart';
import 'package:open_meteo/open_meteo.dart';

import '../models/weather_result.dart';
import 'reverse_geocoding_service.dart';

class WeatherLocation {
  const WeatherLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.warningMessage,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? warningMessage;
}

class WeatherService {
  WeatherService({
    WeatherApi? weatherApi,
    GeocodingApi? geocodingApi,
    ReverseGeocodingService? reverseGeocodingService,
  }) : _weatherApi =
           weatherApi ??
           WeatherApi(
             userAgent: 'poc_kyc-weather-feature',
             temperatureUnit: TemperatureUnit.celsius,
             windspeedUnit: WindspeedUnit.kmh,
           ),
       _geocodingApi =
           geocodingApi ??
           const GeocodingApi(userAgent: 'poc_kyc-weather-feature'),
       _reverseGeocodingService =
           reverseGeocodingService ?? ReverseGeocodingService();

  final WeatherApi _weatherApi;
  final GeocodingApi _geocodingApi;
  final ReverseGeocodingService _reverseGeocodingService;

  void dispose() => _reverseGeocodingService.close();

  Future<List<WeatherLocation>> searchLocations(String query) async {
    final response = await _geocodingApi.requestJson(name: query, count: 8);
    final results = response['results'];
    if (results is! List) return const [];

    return results.whereType<Map>().map((result) {
      final latitude = (result['latitude'] as num?)?.toDouble();
      final longitude = (result['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        throw const FormatException('Open-Meteo returned an invalid location.');
      }

      final name = result['name'] as String? ?? 'Unknown location';
      final country = result['country'] as String?;
      return WeatherLocation(
        name: country == null ? name : '$name, $country',
        latitude: latitude,
        longitude: longitude,
      );
    }).toList();
  }

  Future<WeatherLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const WeatherLocationException(
        'Location services are disabled. Enable them and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const WeatherLocationException('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const WeatherLocationException(
        'Location permission is permanently denied. Enable it in Settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition();
    var name = 'Current location';
    String? warningMessage;
    try {
      name = await _reverseGeocodingService.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on ReverseGeocodingException catch (error) {
      warningMessage =
          'Could not resolve the place name (${error.message}); '
          'showing weather for your current location.';
    }

    return WeatherLocation(
      name: name,
      latitude: position.latitude,
      longitude: position.longitude,
      warningMessage: warningMessage,
    );
  }

  Future<WeatherResult> getWeather(WeatherLocation location) async {
    final response = await _weatherApi.request(
      locations: {
        OpenMeteoLocation(
          latitude: location.latitude,
          longitude: location.longitude,
        ),
      },
      current: {...WeatherCurrent.values},
    );

    if (response.segments.isEmpty) {
      throw const FormatException('Open-Meteo returned no weather data.');
    }

    final segment = response.segments.first;
    final current = segment.currentData;

    final temperature = current[WeatherCurrent.temperature_2m];
    if (temperature == null) {
      throw const FormatException(
        'Open-Meteo omitted the current observation time.',
      );
    }

    return WeatherResult(
      locationName: location.name,
      latitude: segment.latitude,
      longitude: segment.longitude,
      elevation: segment.elevation,
      timezone: segment.timezone,
      timezoneAbbreviation: segment.timezoneAbbreviation,
      utcOffset: segment.utcOffset,
      model: segment.model,
      currentData: Map.unmodifiable(current),
      observedAt: temperature.time,
    );
  }
}

class WeatherLocationException implements Exception {
  const WeatherLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}
