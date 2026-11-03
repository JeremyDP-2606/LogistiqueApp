import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/session.dart';

class AddressResult {
  final String address;
  final double lat;
  final double lng;
  AddressResult(this.address, this.lat, this.lng);
}

/// Écran plein de recherche d'adresse (autocomplétion + position actuelle).
class AddressSearchScreen extends StatefulWidget {
  final String title;
  const AddressSearchScreen({super.key, required this.title});

  static Future<AddressResult?> open(BuildContext context, String title) =>
      Navigator.of(context).push<AddressResult>(MaterialPageRoute(builder: (_) => AddressSearchScreen(title: title)));

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  Timer? _debounce;
  List<AddressResult> _results = [];
  bool _loading = false;
  String? _error;

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
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await context.read<Session>().api.get('/geo/search?q=${Uri.encodeComponent(q)}');
      setState(() => _results = (d['results'] as List)
          .map((r) => AddressResult(r['address'] as String, (r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()))
          .toList());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useMyLocation() async {
    final api = context.read<Session>().api;
    final nav = Navigator.of(context);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw Exception('Autorisez la localisation dans les réglages');
      }
      final pos = await Geolocator.getCurrentPosition();
      final d = await api.get('/geo/reverse?lat=${pos.latitude}&lng=${pos.longitude}');
      nav.pop(AddressResult(d['address'] as String, pos.latitude, pos.longitude));
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Rechercher une adresse',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.my_location),
          title: const Text('Utiliser ma position actuelle'),
          onTap: _useMyLocation,
        ),
        if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(_results[i].address, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.of(context).pop(_results[i]),
            ),
          ),
        ),
      ]),
    );
  }
}
