import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../colors.dart';
import '../../provider/auth_provider.dart';
import '../common.dart';
import '../course_api.dart';
import '../course_models.dart';
import '../position_reporter.dart';
import 'courier_active_course_screen.dart';
import 'courier_earnings_screen.dart';

/// Courses à la demande côté livreur : disponibilité, courses proches, course en cours, gains.
class CourierCoursesScreen extends ConsumerStatefulWidget {
  const CourierCoursesScreen({super.key});
  @override
  ConsumerState<CourierCoursesScreen> createState() => _CourierCoursesScreenState();
}

class _CourierCoursesScreenState extends ConsumerState<CourierCoursesScreen> {
  final _reporter = PositionReporter();
  CourierProfile? _profile;
  List<Course> _available = [];
  Course? _current;
  bool _busy = false;
  bool _loading = true;
  int _tab = 0;
  String? _area;
  final List<StreamSubscription> _subs = [];

  bool get _online => _profile?.online ?? false;

  @override
  void initState() {
    super.initState();
    _reporter.onPosition = (p) => _watchArea(geohashEncode(p.latitude, p.longitude));
    _refresh(first: true);
  }

  @override
  void dispose() {
    _reporter.stop();
    _unwatch();
    super.dispose();
  }

  void _unwatch() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _area = null;
  }

  /// Abonnement aux courses de la zone (~40 km) où se trouve le livreur
  void _watchArea(String area) {
    if (!_online || area == _area) return;
    _unwatch();
    _area = area;
    _subs.add(CourseApi.onCourseAvailable(area, (c) {
      if (!mounted || c.vehicle != _profile?.vehicle || _available.any((x) => x.id == c.id)) return;
      setState(() => _available = [c, ..._available]);
      showInfo(context, 'Nouvelle course : ${eur(c.courierEarning)} · ${km(c.distanceKm)}');
    }));
    _subs.add(CourseApi.onCourseTaken(area, (c) {
      if (mounted) setState(() => _available.removeWhere((x) => x.id == c.id));
    }));
  }

  Future<void> _refresh({bool first = false}) async {
    final id = ref.read(authProvider).myTrueId;
    if (id == null) return;
    try {
      final profile = await CourseApi.myProfile(id);
      final current = profile?.activeCourseId != null ? await CourseApi.get(profile!.activeCourseId!) : null;
      final available = (profile?.online ?? false) ? await CourseApi.available() : <Course>[];
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _current = current;
        _available = available;
      });
      if (first && _online) _reporter.start();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _chooseVehicle() => showModalBottomSheet<String>(
        context: context,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(title: Text('Avec quel véhicule livrez-vous ?', style: TextStyle(fontWeight: FontWeight.w700))),
            ...vehicleLabels.entries.map((e) => ListTile(
                  leading: Icon(vehicleIcons[e.key], color: C.primary),
                  title: Text(e.value),
                  onTap: () => Navigator.pop(c, e.key),
                )),
          ]),
        ),
      );

  Future<void> _toggle(bool online) async {
    String? vehicle;
    if (online && _profile == null) {
      vehicle = await _chooseVehicle();
      if (vehicle == null) return;
    }
    setState(() => _busy = true);
    try {
      final p = await CourseApi.setAvailability(online, vehicle: vehicle);
      setState(() => _profile = p);
      if (online) {
        final ok = await _reporter.start();
        if (!ok && mounted) showError(context, 'Activez la localisation pour recevoir les courses proches de vous');
      } else {
        _reporter.stop();
        _unwatch();
      }
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(Course c) async {
    try {
      final course = await CourseApi.accept(c.id);
      setState(() {
        _current = course;
        _available.removeWhere((x) => x.id == c.id);
      });
      _openCurrent();
    } catch (e) {
      if (mounted) showError(context, e);
      _refresh();
    }
  }

  Future<void> _openCurrent() async {
    if (_current == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourierActiveCourseScreen(course: _current!)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(
        backgroundColor: C.secondary,
        foregroundColor: C.white,
        title: Text(_tab == 0 ? 'Courses à la demande' : 'Mes gains'),
      ),
      body: _tab == 1
          ? const CourierEarningsScreen()
          : _loading
              ? const Center(child: CircularProgressIndicator(color: C.primary))
              : RefreshIndicator(onRefresh: _refresh, child: _jobsList()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.euro_outlined), selectedIcon: Icon(Icons.euro), label: 'Gains'),
        ],
      ),
    );
  }

  Widget _jobsList() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        color: _online ? C.primary_verylight : C.white,
        child: SwitchListTile(
          value: _online,
          activeThumbColor: C.primary,
          onChanged: _busy ? null : _toggle,
          title: Text(_online ? 'Vous êtes disponible' : 'Vous êtes indisponible', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_profile == null
              ? 'Activez pour recevoir des courses près de vous'
              : '${vehicleLabels[_profile!.vehicle]} · ★ ${_profile!.rating.toStringAsFixed(1)}'),
          secondary: Icon(vehicleIcons[_profile?.vehicle ?? 'BIKE'], color: _online ? C.primary : C.textColor, size: 32),
        ),
      ),
      if (_current != null) ...[
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Course en cours', style: TextStyle(fontWeight: FontWeight.w700))),
        Card(
          color: C.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.primary, width: 2)),
          child: InkWell(
            onTap: _openCurrent,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text(_current!.ref, style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), StatusChip(_current!.status)]),
                const SizedBox(height: 6),
                StopLine(letter: 'A', color: C.primary, address: _current!.pickup.address),
                StopLine(letter: 'B', color: C.ok, address: _current!.dropoff.address),
                const Align(alignment: Alignment.centerRight, child: Text('Continuer →', style: TextStyle(color: C.secondary, fontWeight: FontWeight.w600))),
              ]),
            ),
          ),
        ),
      ],
      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Courses proches', style: TextStyle(fontWeight: FontWeight.w700))),
      if (!_online)
        const _Empty(icon: Icons.power_settings_new, text: 'Passez disponible pour voir les courses proches.')
      else if (_available.isEmpty)
        const _Empty(icon: Icons.hourglass_empty, text: 'Aucune course pour le moment.\nUne notification s’affichera dès qu’une course arrive.')
      else
        ..._available.map((c) => Card(
              color: C.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(eur(c.courierEarning), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.secondary)),
                    const Spacer(),
                    if (c.urgency == 'EXPRESS') const Chip(label: Text('Express'), avatar: Icon(Icons.bolt, size: 16)),
                  ]),
                  Text(
                    '${km(c.distanceKm)} de course'
                    '${c.distanceToPickupKm != null ? ' · retrait à ${km(c.distanceToPickupKm!)}' : ''}'
                    ' · colis ${c.packageSize}',
                    style: const TextStyle(color: C.textColor),
                  ),
                  const SizedBox(height: 6),
                  StopLine(letter: 'A', color: C.primary, address: c.pickup.address),
                  StopLine(letter: 'B', color: C.ok, address: c.dropoff.address),
                  const SizedBox(height: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(46)),
                    onPressed: _current == null ? () => _accept(c) : null,
                    child: Text(_current == null ? 'Accepter' : 'Terminez votre course en cours'),
                  ),
                ]),
              ),
            )),
    ]);
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Icon(icon, size: 48, color: C.disable),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.textColor)),
        ]),
      );
}
