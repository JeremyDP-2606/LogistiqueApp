import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../labels.dart';
import '../../models/job.dart';
import '../../services/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/delivery_map.dart';

/// Suivi en direct d'une livraison côté client.
class JobTrackingScreen extends StatefulWidget {
  final String jobId;
  const JobTrackingScreen({super.key, required this.jobId});
  @override
  State<JobTrackingScreen> createState() => _JobTrackingScreenState();
}

class _JobTrackingScreenState extends State<JobTrackingScreen> {
  Job? _job;
  final List<void Function()> _offs = [];
  late final Session _session;

  @override
  void initState() {
    super.initState();
    _session = context.read<Session>();
    _load();
    final rt = _session.realtime;
    rt.subscribeJob(widget.jobId);
    _offs.add(rt.on('job:updated', (d) {
      final j = Job.fromJson(Map<String, dynamic>.from(d['job'] as Map));
      if (j.id == widget.jobId && _job != null) setState(() => _job = _job!.merge(j));
    }));
    _offs.add(rt.on('courier:location', (d) {
      final loc = parseLatLng(d['location']);
      if (d['jobId'] == widget.jobId && loc != null && _job != null) {
        setState(() => _job = _job!.withCourierLocation(loc));
      }
    }));
  }

  @override
  void dispose() {
    for (final off in _offs) {
      off();
    }
    _session.realtime.unsubscribeJob(widget.jobId);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await _session.api.get('/jobs/${widget.jobId}');
      setState(() => _job = Job.fromJson(d['job'] as Map<String, dynamic>));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Annuler la livraison ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui, annuler')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final d = await _session.api.post('/jobs/${widget.jobId}/cancel');
      setState(() => _job = Job.fromJson(d['job'] as Map<String, dynamic>));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _rate() async {
    int stars = 5;
    final comment = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Notez votre coursier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => IconButton(
                    iconSize: 36,
                    icon: Icon(i < stars ? Icons.star : Icons.star_border, color: Colors.amber),
                    onPressed: () => setSt(() => stars = i + 1),
                  )),
            ),
            TextField(controller: comment, decoration: const InputDecoration(labelText: 'Commentaire (optionnel)')),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Envoyer')),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final d = await _session.api.post('/jobs/${widget.jobId}/rate', {'stars': stars, 'comment': comment.text});
      setState(() => _job = Job.fromJson(d['job'] as Map<String, dynamic>));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = _job;
    if (j == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    final courier = j.courier;
    final canCancel = ['pending', 'assigned', 'picking_up'].contains(j.status);

    return Scaffold(
      appBar: AppBar(title: Text(j.ref), actions: [Padding(padding: const EdgeInsets.only(right: 12), child: StatusChip(j.status))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          DeliveryMap(
            pickup: j.pickup.latLng,
            dropoff: j.dropoff.latLng,
            courier: j.isActive ? courier?.location : null,
            height: 280,
          ),
          const SizedBox(height: 12),
          if (j.deliveryCode != null && j.isActive)
            Card(
              color: const Color(0xFFF0FDFA),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Code de remise', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('À communiquer au destinataire', style: TextStyle(color: Colors.black54, fontSize: 13)),
                    ]),
                  ),
                  Text(j.deliveryCode!, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 6, color: brandDark)),
                ]),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: courier != null
                  ? Row(children: [
                      CircleAvatar(backgroundColor: brand, child: Text(courier.name.isNotEmpty ? courier.name[0] : '?', style: const TextStyle(color: Colors.white))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(courier.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${vehicleLabels[courier.vehicle] ?? ''} · ★ ${courier.rating}', style: const TextStyle(color: Colors.black54)),
                        ]),
                      ),
                      if (courier.phone.isNotEmpty && j.isActive)
                        IconButton.filledTonal(icon: const Icon(Icons.phone), onPressed: () => launchUrl(Uri.parse('tel:${courier.phone}'))),
                    ])
                  : j.status == 'pending'
                      ? const Row(children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Expanded(child: Text('Nous cherchons un coursier à proximité…')),
                        ])
                      : const Text('Aucun coursier'),
            ),
          ),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: RouteLines(j, showContacts: true))),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Suivi', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...j.history.map((h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        SizedBox(width: 48, child: Text(hm(h.at), style: const TextStyle(color: Colors.black54))),
                        Icon(Icons.circle, size: 10, color: statusColor(h.status)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${statusLabels[h.status] ?? h.status}${h.reason != null ? ' — ${h.reason}' : ''}')),
                      ]),
                    )),
              ]),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _row('Véhicule', vehicleLabels[j.vehicle] ?? j.vehicle),
                _row('Colis', '${j.packageSize}${j.packageDescription.isNotEmpty ? ' — ${j.packageDescription}' : ''}'),
                _row('Délai', j.urgency == 'express' ? 'Express' : 'Standard'),
                _row('Distance', '${j.distanceKm} km'),
                _row('Prix TTC', eur(j.priceTtc)),
              ]),
            ),
          ),
          if (canCancel)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, minimumSize: const Size.fromHeight(48)),
              onPressed: _cancel,
              icon: const Icon(Icons.close),
              label: const Text('Annuler la livraison'),
            ),
          if (j.status == 'delivered' && j.ratingStars == null)
            FilledButton.icon(onPressed: _rate, icon: const Icon(Icons.star), label: const Text('Noter la livraison')),
          if (j.ratingStars != null)
            Center(child: Text('Votre note : ${'★' * j.ratingStars!}${'☆' * (5 - j.ratingStars!)}', style: const TextStyle(fontSize: 18))),
        ]),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(k, style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
