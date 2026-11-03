import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../labels.dart';
import '../../models/job.dart';
import '../../services/session.dart';
import '../../widgets/common.dart';
import 'job_tracking_screen.dart';
import 'new_delivery_screen.dart';

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});
  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  List<Job> _jobs = [];
  bool _loading = true;
  void Function()? _off;

  @override
  void initState() {
    super.initState();
    _load();
    _off = context.read<Session>().realtime.on('job:updated', (d) {
      final j = Job.fromJson(Map<String, dynamic>.from(d['job'] as Map));
      setState(() => _jobs = _jobs.map((x) => x.id == j.id ? x.merge(j) : x).toList());
    });
  }

  @override
  void dispose() {
    _off?.call();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<Session>().api.get('/jobs');
      setState(() => _jobs = (d['jobs'] as List).map((j) => Job.fromJson(j as Map<String, dynamic>)).toList());
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newDelivery() async {
    final job = await Navigator.of(context).push<Job>(MaterialPageRoute(builder: (_) => const NewDeliveryScreen()));
    if (job == null || !mounted) return;
    setState(() => _jobs = [job, ..._jobs]);
    _open(job);
  }

  Future<void> _open(Job j) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobTrackingScreen(jobId: j.id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    final active = _jobs.where((j) => j.isActive).toList();
    final past = _jobs.where((j) => !j.isActive).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour ${session.user?.name.split(' ').first ?? ''}'),
        actions: [IconButton(tooltip: 'Déconnexion', icon: const Icon(Icons.logout), onPressed: session.logout)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newDelivery,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle livraison'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _jobs.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      EmptyState(icon: Icons.inventory_2_outlined, text: 'Aucune livraison pour l’instant.\nAppuyez sur « Nouvelle livraison ».'),
                    ])
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
                      if (active.isNotEmpty) const _Section('En cours'),
                      ...active.map((j) => _JobCard(j, onTap: () => _open(j))),
                      if (past.isNotEmpty) const _Section('Historique'),
                      ...past.map((j) => _JobCard(j, onTap: () => _open(j))),
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
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      );
}

class _JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  const _JobCard(this.job, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(vehicleIcons[job.vehicle], color: Colors.black54),
              const SizedBox(width: 8),
              Text(job.ref, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              StatusChip(job.status),
            ]),
            const SizedBox(height: 8),
            RouteLines(job),
            const SizedBox(height: 6),
            Row(children: [
              Text('${dayTime(job.createdAt)} · ${job.distanceKm} km', style: const TextStyle(color: Colors.black54, fontSize: 13)),
              const Spacer(),
              Text(eur(job.priceTtc), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ),
    );
  }
}
