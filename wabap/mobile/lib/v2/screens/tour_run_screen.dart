import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../colors.dart';
import '../common.dart';
import '../platform_api.dart';
import '../platform_models.dart';
import '../tour_position_reporter.dart';
import 'stop_screen.dart';

/// Déroulé d'une tournée côté livreur (spec §7) : liste ordonnée des points, point suivant mis en avant.
class TourRunScreen extends StatefulWidget {
  final String tourId;
  const TourRunScreen({super.key, required this.tourId});
  @override
  State<TourRunScreen> createState() => _TourRunScreenState();
}

class _TourRunScreenState extends State<TourRunScreen> {
  CourierTour? _view;
  bool _busy = false;
  final _reporter = TourPositionReporter();
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load(first: true);
    _sub = PlatformApi.onTourChanged(widget.tourId, (t) {
      if (!mounted) return;
      showInfo(context, t.notices.isNotEmpty ? t.notices.last : 'Votre tournée a été mise à jour');
      _load();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reporter.stop();
    super.dispose();
  }

  Future<void> _load({bool first = false}) async {
    try {
      final v = await PlatformApi.tourView(widget.tourId);
      if (!mounted) return;
      setState(() => _view = v);
      if (first && v.tour.status == 'IN_PROGRESS') _reporter.start();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _do(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _do(() async {
        await PlatformApi.start(widget.tourId);
        final ok = await _reporter.start();
        if (!ok && mounted) showError(context, 'Activez la localisation : elle est exigée pendant la tournée');
      });

  Future<void> _close() async {
    final v = _view!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Terminer la tournée ?'),
        content: Text('${v.doneCount} point(s) traité(s) sur ${v.stops.length}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Terminer')),
        ],
      ),
    );
    if (ok != true) return;
    await _do(() async {
      await PlatformApi.close(widget.tourId);
      _reporter.stop();
    });
  }

  Future<void> _openStop(TourStop s) async {
    final v = _view!;
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => StopScreen(tourId: v.tour.id, stop: s, presets: v.presets)));
    if (done == true) _load();
  }

  void _navigate(TourStop s) {
    if (s.place.latitude == null) return;
    launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${s.place.latitude},${s.place.longitude}&travelmode=driving'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final v = _view;
    if (v == null) return Scaffold(appBar: AppBar(backgroundColor: C.secondary), body: const Center(child: CircularProgressIndicator(color: C.primary)));
    final t = v.tour;
    final next = v.next;
    final running = t.status == 'IN_PROGRESS';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(backgroundColor: C.secondary, foregroundColor: C.white, title: Text(t.name ?? t.ref)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            StatusChip(t.status, labels: tourStatusLabels),
            const Spacer(),
            Text('${v.doneCount}/${v.stops.length} points · ${km(t.estimatedKm)}', style: const TextStyle(color: C.textColor)),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: v.stops.isEmpty ? 0 : v.doneCount / v.stops.length, color: C.primary, backgroundColor: C.primary_verylight),
          const SizedBox(height: 12),
          if (running && next != null)
            _StopCard(stop: next, highlighted: true, onTap: () => _openStop(next), onNavigate: () => _navigate(next)),
          if (running && next == null)
            Card(
              color: C.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  const Icon(Icons.flag, color: C.ok, size: 40),
                  const Text('Tous les points sont traités.', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  FilledButton(style: FilledButton.styleFrom(backgroundColor: C.primary), onPressed: _busy ? null : _close, child: const Text('Terminer la tournée')),
                ]),
              ),
            ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Tous les points', style: TextStyle(fontWeight: FontWeight.w700))),
          ...v.stops.map((s) => _StopCard(stop: s, highlighted: false, onTap: running && s.todo ? () => _openStop(s) : null, onNavigate: () => _navigate(s))),
          const SizedBox(height: 80),
        ]),
      ),
      bottomNavigationBar: t.status == 'ASSIGNED' || t.status == 'ACCEPTED'
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  if (t.status == 'ASSIGNED')
                    Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _do(() => PlatformApi.accept(t.id)), child: const Text('Accepter'))),
                  if (t.status == 'ASSIGNED') const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(50)),
                      onPressed: _busy ? null : _start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Démarrer la tournée'),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}

class _StopCard extends StatelessWidget {
  final TourStop stop;
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback onNavigate;
  const _StopCard({required this.stop, required this.highlighted, required this.onTap, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final deadlineSoon = stop.deadlineAt != null && stop.todo && stop.deadlineAt!.difference(DateTime.now()).inMinutes < 45;
    return Card(
      color: C.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlighted ? const BorderSide(color: C.primary, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: stop.todo || highlighted ? 1 : 0.6,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 13, backgroundColor: stop.isPickup ? C.blue : C.ok,
                    child: Text('${stop.sequence}', style: const TextStyle(color: C.white, fontSize: 12))),
                const SizedBox(width: 8),
                Text(stop.isPickup ? 'COLLECTE' : 'LIVRAISON',
                    style: TextStyle(fontWeight: FontWeight.w800, color: stop.isPickup ? C.blue : C.ok, letterSpacing: 0.5)),
                const SizedBox(width: 8),
                Text('${stop.parcels.length} colis', style: const TextStyle(color: C.textColor)),
                const Spacer(),
                if (!stop.todo) StatusChip(stop.status, labels: stopStatusLabels) else if (stop.eta != null) Text(hm(stop.eta!), style: const TextStyle(color: C.textColor)),
              ]),
              const SizedBox(height: 6),
              if (stop.place.name != null) Text(stop.place.name!, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(stop.place.formatted),
              if (stop.place.instructions != null) Text(stop.place.instructions!, style: const TextStyle(color: C.textColor, fontSize: 13)),
              if (stop.deadlineAt != null)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: deadlineSoon ? C.error : C.primary_verylight, borderRadius: BorderRadius.circular(6)),
                  child: Text('Avant ${hm(stop.deadlineAt!)}${stop.hard ? ' (impératif)' : ''}',
                      style: TextStyle(color: deadlineSoon ? C.white : C.secondary, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              if (stop.failureReason != null) Text(stop.failureReason!, style: const TextStyle(color: C.error)),
              if (highlighted) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: onNavigate, icon: const Icon(Icons.navigation), label: const Text('Itinéraire'))),
                  if (stop.place.phone != null) ...[
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('tel:${stop.place.phone}')), icon: const Icon(Icons.phone), label: const Text('Appeler'))),
                  ],
                ]),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(46)),
                  onPressed: onTap,
                  child: Text(stop.isPickup ? 'Je suis à la collecte' : 'Je suis à la livraison'),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
