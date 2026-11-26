import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/features/location/ui/place_maps_link.dart';

void main() {
  const point = GeoPoint(23.8679331, 90.4053536);

  test('links to the spot and Google\'s place', () {
    final uri = googleMapsUri(point: point, placeId: 'ChIJabc123')!;
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['query'], '23.8679331,90.4053536');
    expect(uri.queryParameters['query_place_id'], 'ChIJabc123');
  });

  test('app-made place ids are not sent as Google places', () {
    for (final id in ['dev:abc', 'usr:xyz']) {
      final uri = googleMapsUri(point: point, placeId: id)!;
      expect(uri.queryParameters.containsKey('query_place_id'), isFalse);
    }
  });

  test('nothing to link without a point or Google id', () {
    expect(googleMapsUri(), isNull);
    expect(googleMapsUri(placeId: 'dev:abc'), isNull);
    expect(canOpenInMaps(placeId: 'ChIJabc123'), isTrue);
  });
}
