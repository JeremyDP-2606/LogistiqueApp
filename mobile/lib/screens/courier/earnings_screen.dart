import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../labels.dart';
import '../../services/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<Session>().api.get('/courier/earnings');
      setState(() => _data = d);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _tile(String label, Map<String, dynamic> m) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              Text(eur(m['amount'] as num), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: brandDark)),
              Text('${m['count']} course(s)', style: const TextStyle(color: Colors.black54, fontSize: 13)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final recent = (d['recent'] as List).cast<Map<String, dynamic>>();
    final total = d['total'] as Map<String, dynamic>;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          _tile('Aujourd’hui', d['today'] as Map<String, dynamic>),
          const SizedBox(width: 12),
          _tile('Cette semaine', d['week'] as Map<String, dynamic>),
        ]),
        Card(
          child: ListTile(
            leading: const Icon(Icons.emoji_events_outlined, color: brand),
            title: Text('Total : ${eur(total['amount'] as num)}'),
            subtitle: Text('${total['count']} livraisons · ${total['distanceKm']} km · ★ ${d['rating']}'),
          ),
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Dernières courses', style: TextStyle(fontWeight: FontWeight.w700))),
        if (recent.isEmpty) const EmptyState(icon: Icons.receipt_long_outlined, text: 'Vos courses livrées apparaîtront ici.'),
        ...recent.map((r) => Card(
              child: ListTile(
                title: Text('${r['ref']} · ${r['distanceKm']} km'),
                subtitle: Text('${r['to']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(eur(r['amount'] as num), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(dayTime(DateTime.parse(r['at'] as String).toLocal()), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
              ),
            )),
      ]),
    );
  }
}
