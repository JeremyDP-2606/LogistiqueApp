import 'package:flutter/material.dart';
import '../labels.dart';
import '../models/job.dart';
import '../theme.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(statusLabels[status] ?? status, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class RouteLines extends StatelessWidget {
  final Job job;
  final bool showContacts;
  const RouteLines(this.job, {super.key, this.showContacts = false});

  Widget _line(Color color, String label, Stop s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 10),
            child: CircleAvatar(radius: 5, backgroundColor: color),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.address, maxLines: showContacts ? 3 : 1, overflow: TextOverflow.ellipsis),
              if (showContacts && (s.contactName.isNotEmpty || s.phone.isNotEmpty || s.instructions.isNotEmpty))
                Text(
                  [s.contactName, s.phone, s.instructions].where((x) => x.isNotEmpty).join(' · '),
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Column(children: [
        _line(brand, 'Retrait', job.pickup),
        _line(accent, 'Livraison', job.dropoff),
      ]);
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFB91C1C)));
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Colors.black26),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          ]),
        ),
      );
}
