// Remontée de la position du livreur pendant une tournée en cours uniquement (spec §8, RGPD).
import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'platform_api.dart';

class TourPositionReporter {
  Timer? _timer;
  Position? last;

  Future<bool> start() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return false;
    await _tick();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _tick());
    return true;
  }

  Future<void> _tick() async {
    try {
      final p = await Geolocator.getCurrentPosition();
      last = p;
      await PlatformApi.position(p.latitude, p.longitude);
    } catch (_) {
      // Réseau coupé ou tournée terminée : la position suivante repartira
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
