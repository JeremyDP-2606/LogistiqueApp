import 'package:flutter/material.dart';

import '../../colors.dart';
import '../common.dart';
import '../course_api.dart';
import '../course_models.dart';

/// Gains du livreur sur les courses à la demande.
class CourierEarningsScreen extends StatefulWidget {
  const CourierEarningsScreen({super.key});
  @override
  State<CourierEarningsScreen> createState() => _CourierEarningsScreenState();
}

class _CourierEarningsScreenState extends State<CourierEarningsScreen> {
  CourierEarnings? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await CourseApi.earnings();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _tile(String label, EarningsTotal t) => Expanded(
        child: Card(
          color: C.white,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: C.textColor)),
              const SizedBox(height: 4),
              Text(eur(t.amount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.secondary)),
              Text('${t.count} course${t.count > 1 ? 's' : ''}', style: const TextStyle(color: C.textColor, fontSize: 13)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) return const Center(child: CircularProgressIndicator(color: C.primary));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [_tile('Aujourd’hui', d.today), const SizedBox(width: 12), _tile('Cette semaine', d.week)]),
        Card(
          color: C.white,
          child: ListTile(
            leading: const Icon(Icons.emoji_events_outlined, color: C.primary),
            title: Text('Total : ${eur(d.total.amount)}'),
            subtitle: Text('${d.total.count} livraisons · ${km(d.total.distanceKm ?? 0)} · ★ ${d.rating.toStringAsFixed(1)}'),
          ),
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Dernières courses', style: TextStyle(fontWeight: FontWeight.w700))),
        if (d.recent.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Vos courses livrées apparaîtront ici.', textAlign: TextAlign.center, style: TextStyle(color: C.textColor)),
          ),
        ...d.recent.map((r) => Card(
              color: C.white,
              child: ListTile(
                title: Text('${r.ref} · ${km(r.distanceKm)}'),
                subtitle: Text(r.dropoffAddress ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(eur(r.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(dayTime(r.at), style: const TextStyle(fontSize: 12, color: C.textColor)),
                ]),
              ),
            )),
      ]),
    );
  }
}
