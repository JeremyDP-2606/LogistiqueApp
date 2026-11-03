import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../labels.dart';
import '../../models/job.dart';
import '../../models/user.dart';
import '../../services/location_tracker.dart';
import '../../services/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'active_job_screen.dart';
import 'earnings_screen.dart';

class CourierHome extends StatefulWidget {
  const CourierHome({super.key});
  @override
  State<CourierHome> createState() => _CourierHomeState();
}

class _CourierHomeState extends State<CourierHome> {
  late final Session _session;
  late final LocationTracker _tracker;
  List<Job> _available = [];
  Job? _current;
  bool _toggling = false;
  int _tab = 0;
  final List<void Function()> _offs = [];

  bool get _online => _session.user?.online ?? false;

  @override
  void initState() {
    super.initState();
    _session = context.read<Session>();
    _tracker = LocationTracker(_session);
    final rt = _session.realtime;
    _offs.add(rt.on('job:new', (d) {
      final j = Job.fromJson(Map<String, dynamic>.from(d['job'] as Map));
      if (_available.any((x) => x.id == j.id)) return;
      setState(() => _available = [j, ..._available]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nouvelle course : ${j.ref} · ${eur(j.courierEarning)}')));
      }
    }));
    _offs.add(rt.on('job:taken', (d) => setState(() => _available.removeWhere((x) => x.id == d['jobId']))));
    _refresh();
    if (_online) _tracker.start();
  }

  @override
  void dispose() {
    for (final off in _offs) {
      off();
    }
    _tracker.stop();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final cur = await _session.api.get('/courier/jobs/current');
      final av = await _session.api.get('/courier/jobs/available');
      if (!mounted) return;
      setState(() {
        _current = cur['job'] == null ? null : Job.fromJson(cur['job'] as Map<String, dynamic>);
        _available = (av['jobs'] as List).map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _toggling = true);
    try {
      if (value) {
        final ok = await _tracker.start();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Localisation indisponible : les courses de toute la zone seront affichées.')),
          );
        }
      } else {
        _tracker.stop();
      }
      final d = await _session.api.patch('/courier/status', {'online': value});
      _session.updateUser(AppUser.fromJson(d['user'] as Map<String, dynamic>));
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _accept(Job j) async {
    try {
      final d = await _session.api.post('/courier/jobs/${j.id}/accept');
      final job = Job.fromJson(d['job'] as Map<String, dynamic>);
      setState(() {
        _current = job;
        _available.removeWhere((x) => x.id == j.id);
      });
      _openCurrent();
    } catch (e) {
      if (mounted) showError(context, e);
      _refresh();
    }
  }

  Future<void> _openCurrent() async {
    if (_current == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActiveJobScreen(job: _current!)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Courses' : 'Mes gains'),
        actions: [IconButton(tooltip: 'Déconnexion', icon: const Icon(Icons.logout), onPressed: _session.logout)],
      ),
      body: _tab == 0 ? _jobsTab(user) : const EarningsScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.euro_outlined), selectedIcon: Icon(Icons.euro), label: 'Gains'),
        ],
      ),
    );
  }

  Widget _jobsTab(AppUser user) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: _online ? const Color(0xFFF0FDFA) : Colors.white,
          child: SwitchListTile(
            value: _online,
            onChanged: _toggling ? null : _toggleOnline,
            title: Text(_online ? 'Vous êtes en ligne' : 'Vous êtes hors ligne', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${vehicleLabels[user.vehicle] ?? ''} · ★ ${user.rating}'),
            secondary: Icon(vehicleIcons[user.vehicle], color: _online ? brand : Colors.black38, size: 32),
          ),
        ),
        if (_current != null) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Course en cours', style: TextStyle(fontWeight: FontWeight.w700))),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: brand, width: 2)),
            child: InkWell(
              onTap: _openCurrent,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Text(_current!.ref, style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), StatusChip(_current!.status)]),
                  const SizedBox(height: 8),
                  RouteLines(_current!),
                  const SizedBox(height: 8),
                  const Align(alignment: Alignment.centerRight, child: Text('Continuer →', style: TextStyle(color: brand, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          ),
        ],
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Courses disponibles', style: TextStyle(fontWeight: FontWeight.w700))),
        if (!_online)
          const EmptyState(icon: Icons.power_settings_new, text: 'Passez en ligne pour recevoir des courses.')
        else if (_available.isEmpty)
          const EmptyState(icon: Icons.hourglass_empty, text: 'Aucune course à proximité pour le moment.\nVous serez notifié dès qu’une course arrive.')
        else
          ..._available.map((j) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(eur(j.courierEarning), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: brandDark)),
                      const Spacer(),
                      if (j.urgency == 'express') const Chip(label: Text('Express'), avatar: Icon(Icons.bolt, size: 16)),
                    ]),
                    Text(
                      '${j.distanceKm} km de course'
                      '${j.distanceToPickupKm != null ? ' · retrait à ${j.distanceToPickupKm} km' : ''}'
                      ' · colis ${j.packageSize}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    RouteLines(j),
                    const SizedBox(height: 10),
                    FilledButton(onPressed: _current == null ? () => _accept(j) : null, child: const Text('Accepter')),
                  ]),
                ),
              )),
      ]),
    );
  }
}
