import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../labels.dart';
import '../../models/job.dart';
import '../../services/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/delivery_map.dart';

/// Déroulé d'une course côté coursier : retrait → livraison → code de remise.
class ActiveJobScreen extends StatefulWidget {
  final Job job;
  const ActiveJobScreen({super.key, required this.job});
  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen> {
  late Job _job = widget.job;
  bool _busy = false;
  void Function()? _off;

  @override
  void initState() {
    super.initState();
    _off = context.read<Session>().realtime.on('job:updated', (d) {
      final j = Job.fromJson(Map<String, dynamic>.from(d['job'] as Map));
      if (j.id == _job.id) setState(() => _job = j);
    });
  }

  @override
  void dispose() {
    _off?.call();
    super.dispose();
  }

  // Étape suivante selon le statut courant
  ({String status, String label, IconData icon})? get _next => switch (_job.status) {
        'assigned' => (status: 'picking_up', label: 'Je pars vers le retrait', icon: Icons.directions),
        'picking_up' => (status: 'picked_up', label: 'Colis récupéré', icon: Icons.inventory_2),
        'picked_up' => (status: 'delivering', label: 'Je pars livrer', icon: Icons.local_shipping),
        'delivering' => (status: 'delivered', label: 'Valider la livraison', icon: Icons.check_circle),
        _ => null,
      };

  Stop get _target => ['assigned', 'picking_up'].contains(_job.status) ? _job.pickup : _job.dropoff;

  Future<void> _advance() async {
    final next = _next;
    if (next == null) return;
    String? code;
    if (next.status == 'delivered') {
      code = await _askCode();
      if (code == null) return;
    }
    await _send({'status': next.status, if (code != null) 'code': code});
  }

  Future<void> _send(Map<String, dynamic> body) async {
    setState(() => _busy = true);
    try {
      final d = await context.read<Session>().api.post('/courier/jobs/${_job.id}/status', body);
      setState(() => _job = Job.fromJson(d['job'] as Map<String, dynamic>));
      if (_job.status == 'delivered' && mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.celebration, color: brand, size: 48),
            title: const Text('Livraison validée !'),
            content: Text('Vous avez gagné ${eur(_job.courierEarning)}.'),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askCode() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Code de remise'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Demandez au destinataire son code à 4 chiffres.'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Valider')),
        ],
      ),
    );
  }

  Future<void> _reportFailure() async {
    const reasons = ['Destinataire absent', 'Adresse introuvable', 'Colis refusé', 'Colis endommagé'];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Motif de l’échec', style: TextStyle(fontWeight: FontWeight.w700))),
          ...reasons.map((r) => ListTile(title: Text(r), onTap: () => Navigator.pop(c, r))),
        ]),
      ),
    );
    if (reason != null) await _send({'status': 'failed', 'reason': reason});
  }

  void _navigate() {
    final t = _target;
    launchUrl(Uri.parse('geo:${t.lat},${t.lng}?q=${t.lat},${t.lng}(${Uri.encodeComponent(t.address)})'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    final t = _target;
    final toPickup = ['assigned', 'picking_up'].contains(_job.status);
    return Scaffold(
      appBar: AppBar(title: Text(_job.ref), actions: [Padding(padding: const EdgeInsets.only(right: 12), child: StatusChip(_job.status))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DeliveryMap(pickup: _job.pickup.latLng, dropoff: _job.dropoff.latLng, height: 240),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 14, backgroundColor: toPickup ? brand : accent,
                    child: Text(toPickup ? 'A' : 'B', style: const TextStyle(color: Colors.white, fontSize: 13))),
                const SizedBox(width: 8),
                Text(toPickup ? 'Retrait' : 'Livraison', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
              const SizedBox(height: 8),
              Text(t.address, style: const TextStyle(fontSize: 16)),
              if (t.contactName.isNotEmpty) Text('Contact : ${t.contactName}'),
              if (t.instructions.isNotEmpty) Text('Instructions : ${t.instructions}', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _navigate, icon: const Icon(Icons.navigation), label: const Text('Itinéraire'))),
                if (t.phone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:${t.phone}')),
                      icon: const Icon(Icons.phone),
                      label: const Text('Appeler'),
                    ),
                  ),
                ],
              ]),
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              _row('Colis', '${_job.packageSize}${_job.packageDescription.isNotEmpty ? ' — ${_job.packageDescription}' : ''}'),
              _row('Distance', '${_job.distanceKm} km'),
              _row('Rémunération', eur(_job.courierEarning)),
            ]),
          ),
        ),
        if (_job.status == 'delivering')
          TextButton.icon(
            onPressed: _busy ? null : _reportFailure,
            icon: const Icon(Icons.report_problem_outlined, color: Colors.red),
            label: const Text('Signaler un problème de livraison', style: TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 80),
      ]),
      bottomNavigationBar: next == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(onPressed: _busy ? null : _advance, icon: Icon(next.icon), label: Text(next.label)),
              ),
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
