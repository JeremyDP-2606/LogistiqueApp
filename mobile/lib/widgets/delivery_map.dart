import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme.dart';

/// Carte OpenStreetMap avec points de retrait (A), livraison (B) et position du coursier.
class DeliveryMap extends StatefulWidget {
  final LatLng? pickup;
  final LatLng? dropoff;
  final LatLng? courier;
  final double height;
  const DeliveryMap({super.key, this.pickup, this.dropoff, this.courier, this.height = 260});

  @override
  State<DeliveryMap> createState() => _DeliveryMapState();
}

class _DeliveryMapState extends State<DeliveryMap> {
  final _controller = MapController();
  bool _ready = false;

  List<LatLng> get _points => [widget.pickup, widget.dropoff, widget.courier].whereType<LatLng>().toList();

  void _fit() {
    if (!_ready) return;
    final pts = _points;
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _controller.move(pts.first, 14);
    } else {
      _controller.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(48)));
    }
  }

  @override
  void didUpdateWidget(covariant DeliveryMap old) {
    super.didUpdateWidget(old);
    if (old.pickup != widget.pickup || old.dropoff != widget.dropoff) _fit();
  }

  Marker _pin(LatLng p, Color color, Widget child) => Marker(
        point: p,
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          alignment: Alignment.center,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: _points.isNotEmpty ? _points.first : const LatLng(48.8566, 2.3522),
            initialZoom: 12,
            onMapReady: () {
              _ready = true;
              _fit();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'fr.logistiqueapp.mobile',
            ),
            if (widget.pickup != null && widget.dropoff != null)
              PolylineLayer(polylines: [
                Polyline(points: [widget.pickup!, widget.dropoff!], color: brand, strokeWidth: 3, pattern: const StrokePattern.dotted()),
              ]),
            MarkerLayer(markers: [
              if (widget.pickup != null) _pin(widget.pickup!, brand, const Text('A', style: label)),
              if (widget.dropoff != null) _pin(widget.dropoff!, accent, const Text('B', style: label)),
              if (widget.courier != null)
                _pin(widget.courier!, const Color(0xFF1E293B), const Icon(Icons.navigation, color: Colors.white, size: 18)),
            ]),
            const SimpleAttributionWidget(source: Text('OpenStreetMap')),
          ],
        ),
      ),
    );
  }
}
