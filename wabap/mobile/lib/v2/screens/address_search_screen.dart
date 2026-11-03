import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../colors.dart';
import '../common.dart';
import '../places.dart';

/// Recherche d'adresse plein écran : suggestions Google ou position actuelle.
class AddressSearchScreen extends StatefulWidget {
  final String title;
  const AddressSearchScreen({super.key, required this.title});

  static Future<PlaceResult?> open(BuildContext context, String title) =>
      Navigator.of(context).push<PlaceResult>(MaterialPageRoute(builder: (_) => AddressSearchScreen(title: title)));

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _session = '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(1 << 30)}';
  Timer? _debounce;
  List<PlaceSuggestion> _results = [];
  bool _loading = false;
  String? _error;
  Position? _here;

  @override
  void initState() {
    super.initState();
    // Future.sync : sur le web, la méthode lève une exception au lieu de renvoyer une erreur asynchrone
    Future.sync(Geolocator.getLastKnownPosition).then((p) => _here = p).catchError((_) => null);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final r = await Places.autocomplete(q, sessionToken: _session, lat: _here?.latitude, lng: _here?.longitude);
        if (mounted) setState(() => _results = r);
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _select(PlaceSuggestion s) async {
    final nav = Navigator.of(context);
    try {
      nav.pop(await Places.details(s.placeId, sessionToken: _session));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _useMyPosition() async {
    final nav = Navigator.of(context);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw Exception('Autorisez la localisation dans les réglages du téléphone');
      }
      final p = await Geolocator.getCurrentPosition();
      nav.pop(PlaceResult(await Places.reverse(p.latitude, p.longitude), p.latitude, p.longitude));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: C.secondary, foregroundColor: C.white),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Numéro, rue, ville…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        ListTile(leading: const Icon(Icons.my_location, color: C.primary), title: const Text('Utiliser ma position actuelle'), onTap: _useMyPosition),
        if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: C.error))),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(_results[i].text),
              onTap: () => _select(_results[i]),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Suggestions fournies par Google', style: TextStyle(color: C.textColor, fontSize: 11)),
        ),
      ]),
    );
  }
}
