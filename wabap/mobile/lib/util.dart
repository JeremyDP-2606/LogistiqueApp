import 'package:flutter/material.dart';
import 'package:google_static_maps_controller/google_static_maps_controller.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/models/Status.dart';

class Util {
  static String statusName(Status status) {
    switch (status) {
      case Status.PENDING:
        return "En attente";
      case Status.IN_PROGRESS:
        return "En cours";
      case Status.ISSUE:
        return "Incident";
      case Status.COMPLETED:
        return "Accomplie";
      default:
        return "??";
    }
  }

  static Color statusColor(Status status) {
    switch (status) {
      case Status.PENDING:
        return C.nok;
      case Status.IN_PROGRESS:
        return C.blue;
      case Status.ISSUE:
        return C.error;
      case Status.COMPLETED:
        return C.ok;
      default:
        return C.error;
    }
  }

  static IconData statusIcon(Status status) {
    switch (status) {
      case Status.PENDING:
        return Icons.hourglass_empty_outlined;
      case Status.IN_PROGRESS:
        return Icons.autorenew;
      case Status.ISSUE:
        return Icons.warning_amber;
      case Status.COMPLETED:
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  static String inscriptionName(InscriptionState inscription) {
    switch (inscription) {
      case InscriptionState.PENDING:
        return "En attente";
      case InscriptionState.ACCEPTED:
        return "Accéptée";
      case InscriptionState.NO:
        return "Pas postulé";
      default:
        return "??";
    }
  }

  static Color inscriptionColor(InscriptionState inscription) {
    switch (inscription) {
      case InscriptionState.PENDING:
        return C.blue;
      case InscriptionState.ACCEPTED:
        return C.ok;
      case InscriptionState.NO:
        return C.nok;
      default:
        return C.error;
    }
  }

  static IconData inscriptionIcon(InscriptionState inscription) {
    switch (inscription) {
      case InscriptionState.PENDING:
        return Icons.hourglass_empty_outlined;
      case InscriptionState.ACCEPTED:
        return Icons.check_circle_outline;
      case InscriptionState.NO:
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  static String formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds - hours * 3600) ~/ 60;
    String result = "";
    if (hours > 0) {
      result += "${hours}h";
    }
    if (minutes > 0 || hours > 0) {
      result += "${minutes}m";
    }
    return result.trim();
  }

  static String formatCoordonate(double lat, double lng) {
    return "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}";
  }

  static String formatDistance(int meters) {
    if (meters > 1000) {
      return "${(meters / 10).round() / 100} km";
    } else {
      return "${meters.round()} m";
    }
  }

  static Widget smallCircularProgressIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(25.0),
        child: SizedBox(
          width: 25.0,
          height: 25.0,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
          ),
        ),
      ),
    );
  }

  static final retroMapStyle = [
    const MapStyle(
      element: StyleElement.geometry,
      rules: [
        StyleRule.color(Color(0xffebe3cd)),
      ],
    ),
    MapStyle(
      element: StyleElement.labels.text,
      rules: const [
        StyleRule.color(Color(0xFF523735)),
      ],
    ),
    MapStyle(
      element: StyleElement.labels.text.stroke,
      rules: const [
        StyleRule.color(Color(0xFFf5f1e6)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry.stroke,
      feature: StyleFeature.administrative,
      rules: const [
        StyleRule.color(Color(0xFFc9b2a6)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry.stroke,
      feature: StyleFeature.administrative.landParcel,
      rules: const [
        StyleRule.color(Color(0xFFdcd2be)),
      ],
    ),
    MapStyle(
      element: StyleElement.labels.text.fill,
      feature: StyleFeature.administrative.landParcel,
      rules: const [
        StyleRule.color(Color(0xFFae9e90)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry,
      feature: StyleFeature.landscape.natural,
      rules: const [
        StyleRule.color(Color(0xFFdfd2ae)),
      ],
    ),
    const MapStyle(
      element: StyleElement.geometry,
      feature: StyleFeature.poi,
      rules: [
        StyleRule.color(Color(0xFFdfd2ae)),
      ],
    ),
    MapStyle(
      element: StyleElement.labels.text.fill,
      feature: StyleFeature.poi,
      rules: const [
        StyleRule.color(Color(0xFF93817c)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry.fill,
      feature: StyleFeature.poi.park,
      rules: const [
        StyleRule.color(Color(0xFFa5b076)),
      ],
    ),
    MapStyle(
      element: StyleElement.labels.text.fill,
      feature: StyleFeature.poi.park,
      rules: const [
        StyleRule.color(Color(0xFF447530)),
      ],
    ),
    const MapStyle(
      element: StyleElement.geometry,
      feature: StyleFeature.road,
      rules: [
        StyleRule.color(Color(0xFFf5f1e6)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry,
      feature: StyleFeature.road.arterial,
      rules: const [
        StyleRule.color(Color(0xFFfdfcf8)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry,
      feature: StyleFeature.road.highway,
      rules: const [
        StyleRule.color(Color(0xFFf8c967)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry.stroke,
      feature: StyleFeature.road.highway,
      rules: const [
        StyleRule.color(Color(0xFFe9bc62)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry,
      feature: StyleFeature.road.highway.controlledAccess,
      rules: const [
        StyleRule.color(Color(0xFFe98d58)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry.stroke,
      feature: StyleFeature.road.highway.controlledAccess,
      rules: const [
        StyleRule.color(Color(0xFFdb8555)),
      ],
    ),
    MapStyle(
      element: StyleElement.labels.text.fill,
      feature: StyleFeature.road.local,
      rules: const [
        StyleRule.color(Color(0xFF806b63)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry,
      feature: StyleFeature.transit.line,
      rules: const [
        StyleRule.color(Color(0xFFdfd2ae)),
      ],
    ),
    MapStyle(
      element: StyleElement.labels.text.fill,
      feature: StyleFeature.transit.line,
      rules: const [
        StyleRule.color(Color(0xFF8f7d77)),
      ],
    ),
    MapStyle(
      element: StyleElement.labels.text.stroke,
      feature: StyleFeature.transit.line,
      rules: const [
        StyleRule.color(Color(0xFFebe3cd)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry,
      feature: StyleFeature.transit.station,
      rules: const [
        StyleRule.color(Color(0xFFdfd2ae)),
      ],
    ),
    MapStyle(
      element: StyleElement.geometry.fill,
      feature: StyleFeature.water,
      rules: const [
        StyleRule.color(Color(0xFFb9d3c2)),
      ],
    ),
    MapStyle(
      element: StyleElement.labels.text.fill,
      feature: StyleFeature.water,
      rules: const [
        StyleRule.color(Color(0xFF92998d)),
      ],
    ),
    const MapStyle(element: StyleElement.labels, rules: [StyleRule.visibility(VisibilityRule.off)])
  ];
}

// ignore: constant_identifier_names
enum InscriptionState { PENDING, ACCEPTED, NO }
