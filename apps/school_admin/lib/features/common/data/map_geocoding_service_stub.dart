import 'map_geocoding_service.dart';

/// Non-web fallback — see `map_geocoding_service.dart`'s own doc comment
/// for why address search is web-only for now (it reuses the Maps API key
/// already embedded in `web/index.html` rather than duplicating it into
/// committed Dart source).
Future<List<GeoSearchResult>> searchAddress(String query) {
  throw const GeocodingUnavailableException(
    'Address search needs the web app for now — use "My location" or tap '
    'the map directly.',
  );
}
