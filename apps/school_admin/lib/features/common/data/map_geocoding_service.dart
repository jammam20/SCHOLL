import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_geocoding_service_stub.dart'
    if (dart.library.html) 'map_geocoding_service_web.dart' as impl;

/// One address-search result (Feature: Map Search).
class GeoSearchResult {
  const GeoSearchResult({required this.label, required this.position});
  final String label;
  final LatLng position;
}

/// Thrown when address search genuinely can't run on this platform/build —
/// distinct from a network failure, so the UI can explain *why* rather than
/// implying a transient error worth retrying.
class GeocodingUnavailableException implements Exception {
  const GeocodingUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Address search, backed by the Google Geocoding Web Service — never a
/// hand-rolled/fake list of guesses.
///
/// This reuses the exact Maps API key already embedded in `web/index.html`
/// (read out of that already-loaded `<script>` tag at call time — see
/// map_geocoding_service_web.dart) rather than duplicating the key into
/// committed Dart source, matching this project's established rule that the
/// real key never enters git. That means, honestly, this only works on the
/// Flutter Web build for now (where that script tag exists); on other
/// platforms it throws [GeocodingUnavailableException] instead of silently
/// returning nothing, so the UI can say so rather than looking broken.
abstract class MapGeocodingService {
  static Future<List<GeoSearchResult>> search(String query) =>
      impl.searchAddress(query);
}
