import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../labels.dart';
import '../../models/job.dart';
import '../../services/session.dart';
import '../../theme.dart';
import '../../widgets/address_search.dart';
import '../../widgets/common.dart';
import '../../widgets/delivery_map.dart';

class NewDeliveryScreen extends StatefulWidget {
  const NewDeliveryScreen({super.key});
  @override
  State<NewDeliveryScreen> createState() => _NewDeliveryScreenState();
}

class _NewDeliveryScreenState extends State<NewDeliveryScreen> {
  Stop? _pickup;
  Stop? _dropoff;
  String _size = 'S';
  String _urgency = 'standard';
  final _pickupContact = TextEditingController();
  final _pickupPhone = TextEditingController();
  final _pickupNotes = TextEditingController();
  final _dropContact = TextEditingController();
  final _dropPhone = TextEditingController();
  final _dropNotes = TextEditingController();
  final _description = TextEditingController();

  Map<String, dynamic>? _quote;
  String? _vehicle;
  bool _quoting = false;
  bool _ordering = false;

  Future<void> _pick(bool isPickup) async {
    final r = await AddressSearchScreen.open(context, isPickup ? 'Adresse de retrait' : 'Adresse de livraison');
    if (r == null) return;
    setState(() {
      final s = Stop(address: r.address, lat: r.lat, lng: r.lng);
      if (isPickup) {
        _pickup = s;
      } else {
        _dropoff = s;
      }
    });
    _refreshQuote();
  }

  Future<void> _refreshQuote() async {
    if (_pickup == null || _dropoff == null) return;
    setState(() => _quoting = true);
    try {
      final q = await context.read<Session>().api.post('/quotes', {
        'pickup': _pickup!.toJson(),
        'dropoff': _dropoff!.toJson(),
        'packageSize': _size,
        'urgency': _urgency,
      });
      final options = (q['options'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _quote = q;
        if (!options.any((o) => o['vehicle'] == _vehicle)) {
          _vehicle = options.isNotEmpty ? options.first['vehicle'] as String : null;
        }
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _order() async {
    setState(() => _ordering = true);
    final nav = Navigator.of(context);
    try {
      final d = await context.read<Session>().api.post('/jobs', {
        'pickup': _pickup!.copyWith(contactName: _pickupContact.text, phone: _pickupPhone.text, instructions: _pickupNotes.text).toJson(),
        'dropoff': _dropoff!.copyWith(contactName: _dropContact.text, phone: _dropPhone.text, instructions: _dropNotes.text).toJson(),
        'packageSize': _size,
        'urgency': _urgency,
        'vehicle': _vehicle,
        'packageDescription': _description.text,
      });
      nav.pop(Job.fromJson(d['job'] as Map<String, dynamic>));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  Widget _stopCard({required bool isPickup}) {
    final stop = isPickup ? _pickup : _dropoff;
    final color = isPickup ? brand : accent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: color, child: Text(isPickup ? 'A' : 'B', style: const TextStyle(color: Colors.white))),
            title: Text(stop?.address ?? (isPickup ? 'Où récupérer le colis ?' : 'Où le livrer ?'),
                maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: stop == null ? Colors.black45 : null)),
            trailing: const Icon(Icons.edit_location_alt_outlined),
            onTap: () => _pick(isPickup),
          ),
          if (stop != null) ...[
            Row(children: [
              Expanded(child: TextField(controller: isPickup ? _pickupContact : _dropContact, decoration: const InputDecoration(labelText: 'Contact'))),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: isPickup ? _pickupPhone : _dropPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(controller: isPickup ? _pickupNotes : _dropNotes, decoration: const InputDecoration(labelText: 'Instructions (étage, code…)')),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = ((_quote?['options'] as List?) ?? []).cast<Map<String, dynamic>>();
    final selected = options.where((o) => o['vehicle'] == _vehicle).firstOrNull;
    final price = (selected?['price'] as Map?)?['ttc'] as num?;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle livraison')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DeliveryMap(
          pickup: _pickup == null ? null : LatLng(_pickup!.lat, _pickup!.lng),
          dropoff: _dropoff == null ? null : LatLng(_dropoff!.lat, _dropoff!.lng),
          height: 200,
        ),
        const SizedBox(height: 12),
        _stopCard(isPickup: true),
        _stopCard(isPickup: false),
        const Text('Taille du colis', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sizeLabels.entries
              .map((e) => ChoiceChip(
                    label: Text('${e.key} — ${e.value}'),
                    selected: _size == e.key,
                    onSelected: (_) {
                      setState(() => _size = e.key);
                      _refreshQuote();
                    },
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description du colis (optionnel)')),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'standard', label: Text('Standard · 2h')),
            ButtonSegment(value: 'express', label: Text('Express · 45 min'), icon: Icon(Icons.bolt)),
          ],
          selected: {_urgency},
          onSelectionChanged: (s) {
            setState(() => _urgency = s.first);
            _refreshQuote();
          },
        ),
        const SizedBox(height: 16),
        if (_quoting) const LinearProgressIndicator(),
        if (_quote != null) ...[
          Text('Choisissez votre coursier · ${_quote!['distanceKm']} km', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (options.isEmpty) const Text('Aucun véhicule disponible pour cette distance ou taille.', style: TextStyle(color: Colors.red)),
          ...options.map((o) {
            final v = o['vehicle'] as String;
            final isSel = v == _vehicle;
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isSel ? brand : const Color(0xFFE2E8F0), width: isSel ? 2 : 1),
              ),
              child: ListTile(
                onTap: () => setState(() => _vehicle = v),
                leading: Icon(vehicleIcons[v], color: isSel ? brand : Colors.black54, size: 30),
                title: Text(o['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('~${o['etaMinutes']} min'),
                trailing: Text(eur((o['price'] as Map)['ttc'] as num), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            );
          }),
        ],
        const SizedBox(height: 80),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: selected == null || _ordering ? null : _order,
            child: Text(_ordering ? 'Commande…' : selected == null ? 'Renseignez les adresses' : 'Commander · ${eur(price)}'),
          ),
        ),
      ),
    );
  }
}
