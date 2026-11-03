import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../colors.dart';
import '../common.dart';
import '../course_api.dart';
import '../course_models.dart';

/// Suivi d'une course côté client, mis à jour en temps réel.
class CourseTrackingScreen extends StatefulWidget {
  final String courseId;
  const CourseTrackingScreen({super.key, required this.courseId});
  @override
  State<CourseTrackingScreen> createState() => _CourseTrackingScreenState();
}

class _CourseTrackingScreenState extends State<CourseTrackingScreen> {
  Course? _course;
  String? _code;
  LatLng? _courier;
  final List<StreamSubscription> _subs = [];
  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    _load();
    _subs.add(CourseApi.onCourseChanged(widget.courseId, (u) {
      if (mounted && _course != null) setState(() => _course = _course!.mergeUpdate(u));
    }));
    _subs.add(CourseApi.onCourierPosition(widget.courseId, (lat, lng) {
      if (mounted) setState(() => _courier = LatLng(lat, lng));
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await CourseApi.get(widget.courseId);
      final code = c.isActive ? await CourseApi.deliveryCode(widget.courseId) : null;
      if (mounted) {
        setState(() {
          _course = c;
          _code = code;
        });
      }
      _fit();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _fit() {
    final c = _course;
    if (_map == null || c == null) return;
    final pts = [LatLng(c.pickup.latitude, c.pickup.longitude), LatLng(c.dropoff.latitude, c.dropoff.longitude), if (_courier != null) _courier!];
    final sw = LatLng(pts.map((p) => p.latitude).reduce((a, b) => a < b ? a : b), pts.map((p) => p.longitude).reduce((a, b) => a < b ? a : b));
    final ne = LatLng(pts.map((p) => p.latitude).reduce((a, b) => a > b ? a : b), pts.map((p) => p.longitude).reduce((a, b) => a > b ? a : b));
    _map!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 60));
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Annuler la course ?'),
        content: const Text('Votre carte ne sera pas débitée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui, annuler')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final c = await CourseApi.cancel(widget.courseId);
      if (mounted) setState(() => _course = _course!.mergeUpdate(c));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _rate() async {
    var stars = 5;
    final comment = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Notez votre livreur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => IconButton(
                  iconSize: 36,
                  icon: Icon(i < stars ? Icons.star : Icons.star_border, color: C.primary),
                  onPressed: () => setSt(() => stars = i + 1),
                ),
              ),
            ),
            TextField(controller: comment, decoration: const InputDecoration(labelText: 'Un commentaire ? (facultatif)')),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Envoyer'),
            ),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final c = await CourseApi.rate(widget.courseId, stars, comment.text.trim());
      if (mounted) setState(() => _course = _course!.mergeUpdate(c));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _course;
    if (c == null) {
      return Scaffold(appBar: AppBar(backgroundColor: C.secondary), body: const Center(child: CircularProgressIndicator(color: C.primary)));
    }
    final showCourier = _courier != null && ['ASSIGNED', 'PICKING_UP', 'PICKED_UP', 'DELIVERING'].contains(c.status);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        backgroundColor: C.secondary,
        foregroundColor: C.white,
        title: Text(c.ref),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Align(alignment: Alignment.centerLeft, child: StatusChip(c.status)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 260,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: LatLng(c.pickup.latitude, c.pickup.longitude), zoom: 13),
                onMapCreated: (m) {
                  _map = m;
                  _fit();
                },
                zoomControlsEnabled: false,
                markers: {
                  Marker(markerId: const MarkerId('A'), position: LatLng(c.pickup.latitude, c.pickup.longitude),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange), infoWindow: const InfoWindow(title: 'Retrait')),
                  Marker(markerId: const MarkerId('B'), position: LatLng(c.dropoff.latitude, c.dropoff.longitude),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), infoWindow: const InfoWindow(title: 'Livraison')),
                  if (showCourier)
                    Marker(markerId: const MarkerId('livreur'), position: _courier!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), infoWindow: const InfoWindow(title: 'Livreur')),
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_code != null && c.isActive)
            Card(
              color: C.primary_verylight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Code de remise', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('Donnez-le au destinataire : le livreur le lui demandera.', style: TextStyle(color: C.textColor, fontSize: 13)),
                    ]),
                  ),
                  Text(_code!, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 6, color: C.secondary)),
                ]),
              ),
            ),
          Card(
            color: C.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: c.courierName != null
                  ? Row(children: [
                      CircleAvatar(backgroundColor: C.primary, child: Text(c.courierName!.isNotEmpty ? c.courierName![0] : '?', style: const TextStyle(color: C.white))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.courierName!, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${vehicleLabels[c.courierVehicle] ?? ''} · ★ ${(c.courierRating ?? 5).toStringAsFixed(1)}',
                              style: const TextStyle(color: C.textColor)),
                        ]),
                      ),
                      if (c.courierPhone != null && c.isActive)
                        IconButton.filledTonal(icon: const Icon(Icons.phone), onPressed: () => launchUrl(Uri.parse('tel:${c.courierPhone}'))),
                    ])
                  : c.status == 'PENDING'
                      ? const Row(children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: C.primary)),
                          SizedBox(width: 12),
                          Expanded(child: Text('Nous cherchons un livreur à proximité…')),
                        ])
                      : Text(statusLabels[c.status] ?? c.status),
            ),
          ),
          Card(
            color: C.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                StopLine(letter: 'A', color: C.primary, address: c.pickup.address,
                    details: [c.pickup.contactName, c.pickup.phone, c.pickup.instructions].whereType<String>().join(' · ')),
                StopLine(letter: 'B', color: C.ok, address: c.dropoff.address,
                    details: [c.dropoff.contactName, c.dropoff.phone, c.dropoff.instructions].whereType<String>().join(' · ')),
              ]),
            ),
          ),
          if (c.events.isNotEmpty)
            Card(
              color: C.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Suivi', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ...c.events.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          SizedBox(width: 48, child: Text(hm(e.at), style: const TextStyle(color: C.textColor))),
                          Icon(Icons.circle, size: 10, color: statusColor(e.status)),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${statusLabels[e.status] ?? e.status}${e.message != null ? ' — ${e.message}' : ''}')),
                        ]),
                      )),
                ]),
              ),
            ),
          Card(
            color: C.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _row('Véhicule', vehicleLabels[c.vehicle] ?? c.vehicle),
                _row('Colis', '${c.packageSize}${c.packageDescription != null ? ' — ${c.packageDescription}' : ''}'),
                _row('Délai', c.urgency == 'EXPRESS' ? 'Express' : 'Standard'),
                _row('Distance', km(c.distanceKm)),
                _row('Prix TTC', eur(c.priceTtc)),
                _row('Paiement', c.paymentMode == 'INVOICE' ? 'Facturé au mois' : _paymentLabel(c.paymentStatus)),
              ]),
            ),
          ),
          if (c.clientCanCancel)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: C.error, minimumSize: const Size.fromHeight(48)),
              onPressed: _cancel,
              icon: const Icon(Icons.close),
              label: const Text('Annuler la course'),
            ),
          if (c.status == 'COMPLETED' && c.ratingStars == null)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(48)),
              onPressed: _rate,
              icon: const Icon(Icons.star),
              label: const Text('Noter la livraison'),
            ),
          if (c.ratingStars != null)
            Center(child: Text('Votre note : ${'★' * c.ratingStars!}${'☆' * (5 - c.ratingStars!)}', style: const TextStyle(fontSize: 18))),
        ]),
      ),
    );
  }

  String _paymentLabel(String? s) => switch (s) {
        'authorized' => 'Carte autorisée, débitée à la livraison',
        'captured' => 'Payé par carte',
        'cancelled' => 'Non débité',
        'capture_failed' => 'Paiement à régulariser',
        _ => 'En attente',
      };

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(k, style: const TextStyle(color: C.textColor)),
          const Spacer(),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
