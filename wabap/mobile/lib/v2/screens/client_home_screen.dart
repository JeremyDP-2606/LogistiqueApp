import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../colors.dart';
import '../../provider/auth_provider.dart';
import '../common.dart';
import '../platform_api.dart';
import '../platform_models.dart';
import 'new_course_screen.dart';
import 'order_tracking_screen.dart';

/// Accueil des clients (particuliers et pros occasionnels) : leurs demandes et la commande.
class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});
  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> {
  List<OrderSummary> _orders = [];
  bool _loading = true;

  /// Un particulier n'a pas d'organisation : son « client » est son compte (même règle que le serveur)
  String? get _customerId {
    final auth = ref.read(authProvider);
    final org = auth.clientName;
    if (org != null && org.isNotEmpty) return org;
    return auth.myTrueId == null ? null : 'IND-${auth.myTrueId}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cid = _customerId;
    if (cid == null) return;
    try {
      final list = await PlatformApi.myOrders(cid);
      if (mounted) setState(() => _orders = list);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newCourse() async {
    final orderId = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const NewCourseScreen()));
    if (orderId == null || !mounted) return;
    await _open(orderId);
  }

  Future<void> _open(String orderId) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: orderId)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final active = _orders.where((o) => o.isActive).toList();
    final past = _orders.where((o) => !o.isActive).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        backgroundColor: C.secondary,
        foregroundColor: C.white,
        title: Text('Bonjour ${auth.name ?? ''}'),
        actions: [IconButton(tooltip: 'Déconnexion', icon: const Icon(Icons.power_settings_new), onPressed: () => ref.read(authProvider).logout())],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.primary,
        foregroundColor: C.white,
        onPressed: _newCourse,
        icon: const Icon(Icons.add),
        label: const Text('Envoyer un colis'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: _orders.isEmpty
                  ? ListView(padding: const EdgeInsets.all(32), children: [
                      const SizedBox(height: 80),
                      SizedBox(height: 60, child: Image.asset('assets/images/colis.png')),
                      const SizedBox(height: 16),
                      const Text('Envoyez un colis d’un point A à un point B en 1, 2 ou 3 jours.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: C.text)),
                      const SizedBox(height: 8),
                      const Text('Prix immédiat, paiement par carte, suivi étape par étape.',
                          textAlign: TextAlign.center, style: TextStyle(color: C.textColor)),
                    ])
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
                      if (active.isNotEmpty) const _Section('En cours'),
                      ...active.map((o) => _OrderCard(o, onTap: () => _open(o.id))),
                      if (past.isNotEmpty) const _Section('Historique'),
                      ...past.map((o) => _OrderCard(o, onTap: () => _open(o.id))),
                    ]),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: C.text)),
      );
}

class _OrderCard extends StatelessWidget {
  final OrderSummary order;
  final VoidCallback onTap;
  const _OrderCard(this.order, {required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        color: C.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(order.ref, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                StatusChip(order.status),
              ]),
              const SizedBox(height: 6),
              StopLine(letter: 'A', color: C.primary, address: order.pickup.formatted),
              StopLine(letter: 'B', color: C.ok, address: order.delivery.formatted, details: order.delivery.name),
              Row(children: [
                Text(order.deadlineAt != null ? 'À livrer avant le ${dayTime(order.deadlineAt!)}' : dayTime(order.createdAt),
                    style: const TextStyle(color: C.textColor, fontSize: 13)),
                const Spacer(),
                if (order.priceTotal != null) Text(eur(order.priceTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        ),
      );
}
