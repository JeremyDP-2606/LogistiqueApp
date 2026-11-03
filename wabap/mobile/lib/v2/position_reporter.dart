// Envoie la position du livreur pendant qu'il est disponible (et pendant une course).
// Au plus une mise à jour toutes les 15 s ou tous les 50 m, pour limiter batterie et coûts.
import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'course_api.dart';

class PositionReporter {
  StreamSubscription<Position>? _sub;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  Position? last;
  void Function(Position)? onPosition;

  Future<bool> start() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return false;
    final first = await Geolocator.getCurrentPosition();
    await _send(first, force: true);
    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 50),
    ).listen((p) => _send(p));
    return true;
  }

  Future<void> _send(Position p, {bool force = false}) async {
    last = p;
    onPosition?.call(p);
    final now = DateTime.now();
    if (!force && now.difference(_lastSent) < const Duration(seconds: 15)) return;
    _lastSent = now;
    try {
      await CourseApi.updatePosition(p.latitude, p.longitude);
    } catch (_) {
      // Réseau coupé : la prochaine position repartira
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
