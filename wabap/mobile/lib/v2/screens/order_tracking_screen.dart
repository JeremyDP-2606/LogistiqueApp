import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../colors.dart';
import '../common.dart';
import '../platform_api.dart';
import '../platform_models.dart';

/// Suivi par étapes d'une demande (spec §11) : pas de carte, preuves consultables.
class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});
  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Tracking? _t;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await PlatformApi.tracking(widget.orderId);
      if (mounted) setState(() => _t = t);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Annuler la demande ?'),
        content: const Text('Vous serez remboursé intégralement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui, annuler')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PlatformApi.cancel(widget.orderId);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _label() async {
    try {
      final url = await PlatformApi.labelUrl(widget.orderId);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) {
      return Scaffold(appBar: AppBar(backgroundColor: C.secondary), body: const Center(child: CircularProgressIndicator(color: C.primary)));
    }
    final o = t.order;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(backgroundColor: C.secondary, foregroundColor: C.white, title: Text(o.ref)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Align(alignment: Alignment.centerLeft, child: StatusChip(o.status)),
          const SizedBox(height: 12),
          Card(
            color: C.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (final (i, s) in t.steps.indexed)
                  _StepRow(step: s, current: s.key == t.currentStep, last: i == t.steps.length - 1),
              ]),
            ),
          ),
          if (t.otpCode != null && o.isActive)
            Card(
              color: C.primary_verylight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Code de confirmation', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('Transmettez-le au destinataire : le livreur le lui demandera.', style: TextStyle(color: C.textColor, fontSize: 13)),
                    ]),
                  ),
                  Text(t.otpCode!, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 6, color: C.secondary)),
                ]),
              ),
            ),
          Card(
            color: C.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                StopLine(letter: 'A', color: C.primary, address: o.pickup.formatted, details: o.pickup.name),
                StopLine(letter: 'B', color: C.ok, address: o.delivery.formatted,
                    details: [o.delivery.name, o.delivery.instructions].whereType<String>().join(' · ')),
              ]),
            ),
          ),
          if (t.proofs.isNotEmpty)
            Card(
              color: C.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Preuves', style: TextStyle(fontWeight: FontWeight.w700)),
                  ...t.proofs.map((p) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${dayTime(p.at)} · ${p.type == 'DELIVERED' ? 'Livré' : p.type == 'PICKED_UP' ? 'Collecté' : 'Échec'}'
                          '${p.signerName != null ? ' · signé par ${p.signerName}' : ''}'
                          '${p.photoKeys.isNotEmpty ? ' · ${p.photoKeys.length} photo(s)' : ''}'
                          '${p.comment != null ? ' · ${p.comment}' : ''}',
                        ),
                      )),
                ]),
              ),
            ),
          if (t.priceLines.isNotEmpty)
            Card(
              color: C.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  ...t.priceLines.map((l) => Row(children: [Expanded(child: Text(l.label)), Text(eur(l.amount))])),
                  const Divider(),
                  Row(children: [const Expanded(child: Text('Total payé', style: TextStyle(fontWeight: FontWeight.w700))), Text(eur(o.priceTotal))]),
                ]),
              ),
            ),
          if (o.isActive)
            OutlinedButton.icon(onPressed: _label, icon: const Icon(Icons.qr_code_2), label: const Text('Télécharger l’étiquette à coller sur le colis')),
          if (o.cancellable)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: C.error),
              onPressed: _cancel,
              icon: const Icon(Icons.close),
              label: const Text('Annuler la demande'),
            ),
        ]),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final TrackingStep step;
  final bool current;
  final bool last;
  const _StepRow({required this.step, required this.current, required this.last});

  @override
  Widget build(BuildContext context) {
    final done = step.at != null;
    final failed = step.key == 'FAILED' || step.key == 'CANCELLED';
    final color = failed ? C.error : done ? C.ok : C.disable;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Icon(done ? (failed ? Icons.cancel : Icons.check_circle) : Icons.radio_button_unchecked, color: color, size: 22),
          if (!last) Expanded(child: Container(width: 2, color: done ? C.ok.withValues(alpha: 0.4) : C.disable)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.label, style: TextStyle(fontWeight: current ? FontWeight.w800 : FontWeight.w500, color: done ? C.text : C.textColor)),
              if (step.at != null) Text(dayTime(step.at!), style: const TextStyle(color: C.textColor, fontSize: 12)),
              if (step.detail != null) Text(step.detail!, style: const TextStyle(fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }
}
