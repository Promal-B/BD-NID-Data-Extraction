import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ReverseGeocodingService {
  ReverseGeocodingService({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  static const _userAgent = 'poc_kyc-weather-feature/1.0.0';
  static const _minimumRequestInterval = Duration(seconds: 1);

  final http.Client _client;
  final bool _ownsClient;
  final Map<String, String> _cache = {};
  DateTime? _lastRequestAt;
  Future<void> _requestQueue = Future<void>.value();

  Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const ReverseGeocodingException(
        'The coordinates are outside the valid range.',
      );
    }

    final cacheKey =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    final cachedName = _cache[cacheKey];
    if (cachedName != null) return cachedName;

    await _waitForRequestSlot();
    final nameAfterWait = _cache[cacheKey];
    if (nameAfterWait != null) return nameAfterWait;

    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '10',
      'lat': latitude.toStringAsFixed(6),
      'lon': longitude.toStringAsFixed(6),
    });

    late final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {if (!kIsWeb) 'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
    } on http.ClientException catch (error) {
      throw ReverseGeocodingException(
        'The place-name service request failed: ${error.message}',
      );
    } on TimeoutException {
      throw const ReverseGeocodingException(
        'The place-name service did not respond in time.',
      );
    }

    if (response.statusCode != 200) {
      throw ReverseGeocodingException(
        'The place-name service returned HTTP ${response.statusCode}.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw ReverseGeocodingException(
        'The place-name service returned invalid data: ${error.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ReverseGeocodingException(
        'The place-name service returned an unexpected response.',
      );
    }

    final name = _locationName(decoded);
    if (name == null) {
      throw const ReverseGeocodingException(
        'No place name was found for these coordinates.',
      );
    }

    _cache[cacheKey] = name;
    return name;
  }

  Future<void> _waitForRequestSlot() async {
    final previousRequest = _requestQueue;
    final requestSlot = Completer<void>();
    _requestQueue = requestSlot.future;

    await previousRequest;
    try {
      final lastRequestAt = _lastRequestAt;
      if (lastRequestAt != null) {
        final wait = lastRequestAt
            .add(_minimumRequestInterval)
            .difference(DateTime.now());
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastRequestAt = DateTime.now();
    } finally {
      requestSlot.complete();
    }
  }

  String? _locationName(Map<String, dynamic> response) {
    final rawAddress = response['address'];
    final address = rawAddress is Map<String, dynamic>
        ? rawAddress
        : const <String, dynamic>{};

    final locality = _firstNonEmpty(address, const [
      'city',
      'town',
      'village',
      'municipality',
      'suburb',
      'city_district',
      'county',
      'state',
    ]);
    final country = address['country'];
    final displayName = response['display_name'];
    final fallback = displayName is String
        ? displayName.split(',').first.trim()
        : null;
    final place = locality ?? fallback;
    final countryName = country is String && country.trim().isNotEmpty
        ? country.trim()
        : null;
    if (place == null || place.isEmpty) return countryName;
    if (countryName == null) return place;
    if (place.toLowerCase() == countryName.toLowerCase()) return countryName;
    return '$place, $countryName';
  }

  String? _firstNonEmpty(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = values[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class ReverseGeocodingException implements Exception {
  const ReverseGeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}
