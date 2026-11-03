import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../colors.dart';
import '../common.dart';
import '../course_api.dart';
import '../course_models.dart';

/// Déroulé d'une course côté livreur : retrait → livraison → code de remise.
class CourierActiveCourseScreen extends StatefulWidget {
  final Course course;
  const CourierActiveCourseScreen({super.key, required this.course});
  @override
  State<CourierActiveCourseScreen> createState() => _CourierActiveCourseScreenState();
}

class _CourierActiveCourseScreenState extends State<CourierActiveCourseScreen> {
  late Course _course = widget.course;
  bool _busy = false;

  ({String status, String label, IconData icon})? get _next => switch (_course.status) {
        'ASSIGNED' => (status: 'PICKING_UP', label: 'Je pars vers le retrait', icon: Icons.directions),
        'PICKING_UP' => (status: 'PICKED_UP', label: 'Colis récupéré', icon: Icons.inventory_2),
        'PICKED_UP' => (status: 'DELIVERING', label: 'Je pars livrer', icon: Icons.local_shipping),
        'DELIVERING' => (status: 'COMPLETED', label: 'Valider la livraison', icon: Icons.check_circle),
        _ => null,
      };

  bool get _toPickup => ['ASSIGNED', 'PICKING_UP'].contains(_course.status);
  CourseStop get _target => _toPickup ? _course.pickup : _course.dropoff;

  Future<void> _advance() async {
    final next = _next;
    if (next == null) return;
    String? code;
    if (next.status == 'COMPLETED') {
      code = await _askCode();
      if (code == null) return;
    }
    await _send(next.status, code: code);
  }

  Future<void> _send(String status, {String? code, String? reason}) async {
    setState(() => _busy = true);
    try {
      final c = await CourseApi.step(_course.id, status, code: code, reason: reason);
      setState(() => _course = c);
      if (c.status == 'COMPLETED' && mounted) {
        await showDialog<void>(
          context: context,
          builder: (d) => AlertDialog(
            icon: const Icon(Icons.celebration, color: C.primary, size: 48),
            title: const Text('Livraison validée'),
            content: Text('Vous avez gagné ${eur(c.courierEarning)}.'),
            actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      } else if (c.status == 'ISSUE' && mounted) {
        showInfo(context, 'Problème signalé : Wabap va recontacter le client');
        Navigator.of(context).pop();
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
      builder: (d) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.primary),
            onPressed: () => Navigator.pop(d, ctrl.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _reportIssue() async {
    const reasons = ['Destinataire absent', 'Adresse introuvable', 'Colis refusé', 'Colis endommagé'];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Quel est le problème ?', style: TextStyle(fontWeight: FontWeight.w700))),
          ...reasons.map((r) => ListTile(title: Text(r), onTap: () => Navigator.pop(c, r))),
        ]),
      ),
    );
    if (reason != null) await _send('ISSUE', reason: reason);
  }

  void _navigate() {
    final t = _target;
    launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${t.latitude},${t.longitude}&travelmode=driving'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    final t = _target;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(backgroundColor: C.secondary, foregroundColor: C.white, title: Text(_course.ref)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Align(alignment: Alignment.centerLeft, child: StatusChip(_course.status)),
        const SizedBox(height: 10),
        Card(
          color: C.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_toPickup ? 'Retrait' : 'Livraison', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Text(t.address, style: const TextStyle(fontSize: 17, color: C.text)),
              if (t.contactName != null) Text('Contact : ${t.contactName}'),
              if (t.instructions != null) Text('Instructions : ${t.instructions}', style: const TextStyle(color: C.textColor)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _navigate, icon: const Icon(Icons.navigation), label: const Text('Itinéraire'))),
                if (t.phone != null) ...[
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
          color: C.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              StopLine(letter: 'A', color: C.primary, address: _course.pickup.address),
              StopLine(letter: 'B', color: C.ok, address: _course.dropoff.address),
              const Divider(),
              _row('Colis', '${_course.packageSize}${_course.packageDescription != null ? ' — ${_course.packageDescription}' : ''}'),
              _row('Distance', km(_course.distanceKm)),
              _row('Votre rémunération', eur(_course.courierEarning)),
            ]),
          ),
        ),
        if (_course.status == 'DELIVERING')
          TextButton.icon(
            onPressed: _busy ? null : _reportIssue,
            icon: const Icon(Icons.report_problem_outlined, color: C.error),
            label: const Text('Signaler un problème de livraison', style: TextStyle(color: C.error)),
          ),
        const SizedBox(height: 80),
      ]),
      bottomNavigationBar: next == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(52)),
                  onPressed: _busy ? null : _advance,
                  icon: Icon(next.icon),
                  label: Text(next.label),
                ),
              ),
            ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(k, style: const TextStyle(color: C.textColor)),
          const Spacer(),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
