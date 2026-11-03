import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../colors.dart';
import '../../provider/auth_provider.dart';
import '../common.dart';
import '../course_api.dart';
import '../course_models.dart';
import 'course_tracking_screen.dart';
import 'new_course_screen.dart';

/// Accueil des clients (particuliers et professionnels) : leurs courses et la commande.
class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});
  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> {
  List<Course> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ref.read(authProvider).myTrueId;
    if (id == null) return;
    try {
      final list = await CourseApi.myCourses(id);
      if (mounted) setState(() => _courses = list);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newCourse() async {
    final course = await Navigator.of(context).push<Course>(MaterialPageRoute(builder: (_) => const NewCourseScreen()));
    if (course == null || !mounted) return;
    _open(course);
  }

  Future<void> _open(Course c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseTrackingScreen(courseId: c.id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final active = _courses.where((c) => c.isActive).toList();
    final past = _courses.where((c) => !c.isActive).toList();
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
        label: const Text('Nouvelle course'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: _courses.isEmpty
                  ? ListView(padding: const EdgeInsets.all(32), children: [
                      const SizedBox(height: 80),
                      SizedBox(height: 60, child: Image.asset('assets/images/colis.png')),
                      const SizedBox(height: 16),
                      const Text('Envoyez un colis en ville en moins d’une heure.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: C.text)),
                      const SizedBox(height: 8),
                      const Text('Prix immédiat, paiement par carte, suivi du livreur en direct.',
                          textAlign: TextAlign.center, style: TextStyle(color: C.textColor)),
                    ])
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
                      if (active.isNotEmpty) const _Section('En cours'),
                      ...active.map((c) => _CourseCard(c, onTap: () => _open(c))),
                      if (past.isNotEmpty) const _Section('Historique'),
                      ...past.map((c) => _CourseCard(c, onTap: () => _open(c))),
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

class _CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  const _CourseCard(this.course, {required this.onTap});

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
                Icon(vehicleIcons[course.vehicle], color: C.textColor),
                const SizedBox(width: 8),
                Text(course.ref, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                StatusChip(course.status),
              ]),
              const SizedBox(height: 6),
              StopLine(letter: 'A', color: C.primary, address: course.pickup.address),
              StopLine(letter: 'B', color: C.ok, address: course.dropoff.address),
              Row(children: [
                Text('${dayTime(course.createdAt)} · ${km(course.distanceKm)}', style: const TextStyle(color: C.textColor, fontSize: 13)),
                const Spacer(),
                Text(eur(course.priceTtc), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        ),
      );
}
