// ignore_for_file: constant_identifier_names

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

// Fournie au build : flutter run --dart-define=GOOGLE_MAPS_API_KEY=...
const GOOGLE_API_KEY = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

const MARTINIQUE = LatLng(14.64, -61.02);
formatMinute(int? duration) {
  if (duration == null) return "? min";
  return "${(duration / 60).floor()}h ${duration % 60}m";
}

formatDate(DateTime? date) {
  if (date == null) return "?";
  return DateFormat("dd/MM/yyyy").format(date);
}

const STYLE_MAP = '''[
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.business",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  }
]''';
