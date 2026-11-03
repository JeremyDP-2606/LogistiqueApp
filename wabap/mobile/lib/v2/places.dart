// Saisie d'adresse avec suggestions Google Places (API Places « New »).
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../const.dart';

class PlaceSuggestion {
  final String placeId;
  final String text;
  PlaceSuggestion(this.placeId, this.text);
}

class PlaceResult {
  final String address;
  final double latitude;
  final double longitude;
  PlaceResult(this.address, this.latitude, this.longitude);
}

class Places {
  static const _base = 'https://places.googleapis.com/v1';

  static Map<String, String> _headers(String fieldMask) => {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': GOOGLE_API_KEY,
        'X-Goog-FieldMask': fieldMask,
      };

  /// [sessionToken] regroupe les frappes d'une même recherche (facturation Google à la session).
  static Future<List<PlaceSuggestion>> autocomplete(String input, {required String sessionToken, double? lat, double? lng}) async {
    if (GOOGLE_API_KEY.isEmpty) throw Exception('Clé Google Maps absente (--dart-define=GOOGLE_MAPS_API_KEY)');
    final res = await http.post(
      Uri.parse('$_base/places:autocomplete'),
      headers: _headers('suggestions.placePrediction.placeId,suggestions.placePrediction.text.text'),
      body: jsonEncode({
        'input': input,
        'languageCode': 'fr',
        'sessionToken': sessionToken,
        'includedRegionCodes': ['fr', 'mq', 'gp', 'gf', 're', 'yt'],
        if (lat != null && lng != null)
          'locationBias': {
            'circle': {'center': {'latitude': lat, 'longitude': lng}, 'radius': 30000.0}
          },
      }),
    );
    if (res.statusCode != 200) throw Exception('Recherche d’adresse indisponible (${res.statusCode})');
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return ((data['suggestions'] as List?) ?? const [])
        .map((s) => (s as Map)['placePrediction'] as Map?)
        .whereType<Map>()
        .map((p) => PlaceSuggestion(p['placeId'] as String, ((p['text'] as Map)['text']) as String))
        .toList();
  }

  static Future<PlaceResult> details(String placeId, {required String sessionToken}) async {
    final res = await http.get(
      Uri.parse('$_base/places/$placeId?languageCode=fr&sessionToken=$sessionToken'),
      headers: _headers('formattedAddress,location'),
    );
    if (res.statusCode != 200) throw Exception('Adresse introuvable (${res.statusCode})');
    final d = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final loc = d['location'] as Map;
    return PlaceResult(d['formattedAddress'] as String, (loc['latitude'] as num).toDouble(), (loc['longitude'] as num).toDouble());
  }

  /// Adresse d'une position GPS (« Utiliser ma position »).
  static Future<String> reverse(double lat, double lng) async {
    final res = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&language=fr&key=$GOOGLE_API_KEY'));
    if (res.statusCode == 200) {
      final results = (jsonDecode(utf8.decode(res.bodyBytes))['results'] as List?) ?? const [];
      if (results.isNotEmpty) return results.first['formatted_address'] as String;
    }
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }
}
