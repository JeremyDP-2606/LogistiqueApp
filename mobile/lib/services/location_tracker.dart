import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'session.dart';

/// Envoie la position GPS du coursier au serveur tant qu'il est en ligne.
class LocationTracker {
  final Session session;
  StreamSubscription<Position>? _sub;
  Position? last;

  LocationTracker(this.session);

  Future<bool> start() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return false;

    final first = await Geolocator.getCurrentPosition();
    _push(first, viaHttp: true);
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
    ).listen((p) => _push(p));
    return true;
  }

  void _push(Position p, {bool viaHttp = false}) {
    last = p;
    if (viaHttp) {
      // HTTP pour la première position : garantit qu'elle est enregistrée avant la recherche de courses
      session.api.post('/courier/location', {'lat': p.latitude, 'lng': p.longitude}).catchError((_) => <String, dynamic>{});
    } else {
      session.realtime.sendLocation(p.latitude, p.longitude);
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
