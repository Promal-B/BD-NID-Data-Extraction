import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poc_kyc/features/weather_open_meteo/services/reverse_geocoding_service.dart';

void main() {
  group('ReverseGeocodingService', () {
    test('returns a concise locality and country name', () async {
      final service = ReverseGeocodingService(
        client: MockClient((request) async {
          expect(request.url.host, 'nominatim.openstreetmap.org');
          expect(request.url.path, '/reverse');
          expect(request.url.queryParameters['format'], 'jsonv2');
          expect(request.headers['User-Agent'], contains('poc_kyc'));
          return http.Response(
            '{"address":{"city":"Dhaka","country":"Bangladesh"},'
            '"display_name":"Dhaka, Bangladesh"}',
            200,
          );
        }),
      );

      expect(
        await service.reverseGeocode(latitude: 23.8103, longitude: 90.4125),
        'Dhaka, Bangladesh',
      );
    });

    test('uses the display name when no locality fields are present', () async {
      final service = ReverseGeocodingService(
        client: MockClient((_) async {
          return http.Response(
            '{"address":{"country":"Bangladesh"},'
            '"display_name":"Gazipur, Bangladesh"}',
            200,
          );
        }),
      );

      expect(
        await service.reverseGeocode(latitude: 24.0, longitude: 90.0),
        'Gazipur, Bangladesh',
      );
    });

    test('caches results for nearby coordinates', () async {
      var requestCount = 0;
      final service = ReverseGeocodingService(
        client: MockClient((_) async {
          requestCount++;
          return http.Response(
            '{"address":{"city":"Dhaka","country":"Bangladesh"}}',
            200,
          );
        }),
      );

      final firstName = await service.reverseGeocode(
        latitude: 23.81031,
        longitude: 90.41251,
      );
      final cachedName = await service.reverseGeocode(
        latitude: 23.81032,
        longitude: 90.41252,
      );

      expect(firstName, 'Dhaka, Bangladesh');
      expect(cachedName, firstName);
      expect(requestCount, 1);
    });

    test('reports an HTTP failure instead of returning a fake place name', () {
      final service = ReverseGeocodingService(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );

      expect(
        service.reverseGeocode(latitude: 23.8, longitude: 90.4),
        throwsA(isA<ReverseGeocodingException>()),
      );
    });

    test('rejects invalid coordinates before making a request', () {
      final service = ReverseGeocodingService(
        client: MockClient((_) async {
          fail('Invalid coordinates must not trigger a request.');
        }),
      );

      expect(
        service.reverseGeocode(latitude: 91, longitude: 90),
        throwsA(isA<ReverseGeocodingException>()),
      );
    });
  });
}
