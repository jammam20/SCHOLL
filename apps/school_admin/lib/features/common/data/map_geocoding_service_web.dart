import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'map_geocoding_service.dart';

/// Reads the Maps API key straight out of the `<script>` tag `index.html`
/// already loads it through — see `map_geocoding_service.dart`'s doc
/// comment for why this, rather than a copy of the key in Dart source.
String? _findApiKeyFromLoadedScript() {
  final scripts = web.document.querySelectorAll('script');
  for (var i = 0; i < scripts.length; i++) {
    final src = (scripts.item(i) as web.HTMLScriptElement?)?.src ?? '';
    if (!src.contains('maps.googleapis.com')) continue;
    final uri = Uri.tryParse(src);
    final key = uri?.queryParameters['key'];
    if (key != null && key.isNotEmpty) return key;
  }
  return null;
}

Future<List<GeoSearchResult>> searchAddress(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];

  final apiKey = _findApiKeyFromLoadedScript();
  if (apiKey == null) {
    throw const GeocodingUnavailableException(
      "This app's map isn't loaded yet — try again in a moment.",
    );
  }

  final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
    'address': trimmed,
    'key': apiKey,
  });

  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw const GeocodingUnavailableException(
      "Couldn't reach the location search service — check your connection.",
    );
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final status = body['status'] as String?;
  if (status == 'ZERO_RESULTS') return const [];
  if (status != 'OK') {
    throw GeocodingUnavailableException(
      body['error_message'] as String? ??
          "Couldn't search for that location right now.",
    );
  }

  final results = (body['results'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>();
  return results.map((result) {
    final location =
        (result['geometry'] as Map<String, dynamic>)['location']
            as Map<String, dynamic>;
    return GeoSearchResult(
      label: result['formatted_address'] as String? ?? trimmed,
      position: LatLng(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      ),
    );
  }).toList();
}
