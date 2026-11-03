import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../colors.dart';
import '../../provider/auth_provider.dart';
import '../common.dart';
import '../platform_api.dart';
import '../platform_models.dart';
import 'tour_run_screen.dart';

/// Tournées du livreur (en cours, à venir, passées) et ses gains (spec §7.1).
class CourierToursScreen extends ConsumerStatefulWidget {
  const CourierToursScreen({super.key});
  @override
  ConsumerState<CourierToursScreen> createState() => _CourierToursScreenState();
}

class _CourierToursScreenState extends ConsumerState<CourierToursScreen> {
  int _tab = 0;
  List<TourSummary> _tours = [];
  MyEarnings? _earnings;
  bool _loading = true;
  String get _month => DateTime.now().toIso8601String().substring(0, 7);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ref.read(authProvider).myTrueId;
    if (id == null) return;
    try {
      final tours = await PlatformApi.myTours(id);
      final earnings = await PlatformApi.earnings(_month);
      if (mounted) setState(() { _tours = tours; _earnings = earnings; });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(TourSummary t) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TourRunScreen(tourId: t.id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(backgroundColor: C.secondary, foregroundColor: C.white, title: Text(_tab == 0 ? 'Mes tournées' : 'Mes gains')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.primary))
          : RefreshIndicator(onRefresh: _load, child: _tab == 0 ? _toursList() : _earningsView()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'Tournées'),
          NavigationDestination(icon: Icon(Icons.euro_outlined), selectedIcon: Icon(Icons.euro), label: 'Gains'),
        ],
      ),
    );
  }

  Widget _toursList() {
    final open = _tours.where((t) => t.isOpen).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
    final past = _tours.where((t) => !t.isOpen).toList();
    if (_tours.isEmpty) {
      return ListView(padding: const EdgeInsets.all(32), children: const [
        SizedBox(height: 80),
        Icon(Icons.route, size: 56, color: C.disable),
        SizedBox(height: 12),
        Text('Aucune tournée attribuée pour le moment.', textAlign: TextAlign.center, style: TextStyle(color: C.textColor)),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (open.isNotEmpty) const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('À faire', style: TextStyle(fontWeight: FontWeight.w700))),
      ...open.map((t) => _TourCard(t, onTap: () => _open(t))),
      if (past.isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Passées', style: TextStyle(fontWeight: FontWeight.w700))),
      ...past.map((t) => _TourCard(t, onTap: () => _open(t))),
    ]);
  }

  Widget _earningsView() {
    final e = _earnings;
    if (e == null) return const SizedBox();
    const statusLabel = {'TO_VALIDATE': 'En cours de validation', 'VALIDATED': 'Validé', 'PAID': 'Payé'};
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        color: C.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ce mois-ci', style: TextStyle(color: C.textColor)),
            Text(eur(e.total), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: C.secondary)),
            Text('${e.tours.length} tournée(s) · ${km(e.km)} · ${statusLabel[e.status]}', style: const TextStyle(color: C.textColor)),
          ]),
        ),
      ),
      ...e.tours.map((t) => Card(
            color: C.white,
            child: ListTile(
              title: Text('${t.ref} · ${km(t.km)}'),
              subtitle: Text('${t.date} · ${statusLabel[t.status]}'),
              trailing: Text(eur(t.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          )),
    ]);
  }
}

class _TourCard extends StatelessWidget {
  final TourSummary tour;
  final VoidCallback onTap;
  const _TourCard(this.tour, {required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        color: C.white,
        child: ListTile(
          onTap: onTap,
          leading: Icon(tour.slot == 'NIGHT' ? Icons.nightlight_round : Icons.wb_sunny_outlined, color: C.primary),
          title: Text(tour.name ?? tour.ref, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${dayTime(tour.startTime)} · ${km(tour.estimatedKm)}'),
          trailing: StatusChip(tour.status, labels: tourStatusLabels),
        ),
      );
}
