import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../colors.dart';
import '../common.dart';
import '../course_api.dart';
import '../course_models.dart';
import '../payment.dart';
import 'address_search_screen.dart';

/// Commande d'une course : adresses, colis, délai, devis par véhicule, paiement.
/// Renvoie la course créée et confirmée (ou null si le client abandonne).
class NewCourseScreen extends StatefulWidget {
  const NewCourseScreen({super.key});
  @override
  State<NewCourseScreen> createState() => _NewCourseScreenState();
}

class _NewCourseScreenState extends State<NewCourseScreen> {
  CourseStop? _pickup;
  CourseStop? _dropoff;
  String _size = 'S';
  String _urgency = 'STANDARD';
  final _pickupContact = TextEditingController();
  final _pickupPhone = TextEditingController();
  final _pickupNotes = TextEditingController();
  final _dropContact = TextEditingController();
  final _dropPhone = TextEditingController();
  final _dropNotes = TextEditingController();
  final _description = TextEditingController();
  CourseQuote? _quote;
  String? _vehicle;
  bool _quoting = false;
  bool _ordering = false;
  GoogleMapController? _map;

  Future<void> _pick(bool isPickup) async {
    final r = await AddressSearchScreen.open(context, isPickup ? 'Adresse de retrait' : 'Adresse de livraison');
    if (r == null) return;
    setState(() {
      final s = CourseStop(address: r.address, latitude: r.latitude, longitude: r.longitude);
      isPickup ? _pickup = s : _dropoff = s;
    });
    _fitMap();
    _refreshQuote();
  }

  void _fitMap() {
    final pts = [_pickup, _dropoff].whereType<CourseStop>().map((s) => LatLng(s.latitude, s.longitude)).toList();
    if (_map == null || pts.isEmpty) return;
    if (pts.length == 1) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 15));
      return;
    }
    final sw = LatLng(
      pts.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
      pts.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
    );
    final ne = LatLng(
      pts.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
      pts.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
    );
    _map!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 50));
  }

  Future<void> _refreshQuote() async {
    if (_pickup == null || _dropoff == null) return;
    setState(() => _quoting = true);
    try {
      final q = await CourseApi.quote(pickup: _pickup!, dropoff: _dropoff!, packageSize: _size, urgency: _urgency);
      setState(() {
        _quote = q;
        if (!q.options.any((o) => o.vehicle == _vehicle)) _vehicle = q.options.isEmpty ? null : q.options.first.vehicle;
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
      final created = await CourseApi.create(
        pickup: _pickup!.copyWith(contactName: _pickupContact.text.trim(), phone: _pickupPhone.text.trim(), instructions: _pickupNotes.text.trim()),
        dropoff: _dropoff!.copyWith(contactName: _dropContact.text.trim(), phone: _dropPhone.text.trim(), instructions: _dropNotes.text.trim()),
        packageSize: _size,
        urgency: _urgency,
        vehicle: _vehicle!,
        packageDescription: _description.text.trim(),
      );
      if (created.paymentClientSecret != null) {
        final paid = await Payment.authorize(created.paymentClientSecret!);
        if (!paid) {
          // Commande abandonnée au paiement : on l'annule pour libérer l'autorisation
          await CourseApi.cancel(created.course.id, reason: 'Paiement abandonné').catchError((_) => created.course);
          if (mounted) showInfo(context, 'Paiement annulé : la course n’a pas été commandée');
          return;
        }
      }
      final confirmed = await CourseApi.confirmPayment(created.course.id);
      nav.pop(confirmed);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  Widget _stopCard(bool isPickup) {
    final stop = isPickup ? _pickup : _dropoff;
    final color = isPickup ? C.primary : C.ok;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: color, child: Text(isPickup ? 'A' : 'B', style: const TextStyle(color: C.white))),
            title: Text(stop?.address ?? (isPickup ? 'Où récupérer le colis ?' : 'Où le livrer ?'),
                style: TextStyle(color: stop == null ? C.textColor : C.text)),
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
            TextField(controller: isPickup ? _pickupNotes : _dropNotes, decoration: const InputDecoration(labelText: 'Instructions (étage, code…)')),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _quote?.options.where((o) => o.vehicle == _vehicle).firstOrNull;
    final markers = <Marker>{
      if (_pickup != null)
        Marker(markerId: const MarkerId('A'), position: LatLng(_pickup!.latitude, _pickup!.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)),
      if (_dropoff != null)
        Marker(markerId: const MarkerId('B'), position: LatLng(_dropoff!.latitude, _dropoff!.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle course'), backgroundColor: C.secondary, foregroundColor: C.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 180,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: LatLng(14.6037, -61.0731), zoom: 11),
              markers: markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (c) {
                _map = c;
                _fitMap();
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _stopCard(true),
        _stopCard(false),
        const Text('Taille du colis', style: TextStyle(fontWeight: FontWeight.w700, color: C.text)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sizeLabels.entries
              .map((e) => ChoiceChip(
                    label: Text('${e.key} — ${e.value}'),
                    selected: _size == e.key,
                    selectedColor: C.primary_verylight,
                    onSelected: (_) {
                      setState(() => _size = e.key);
                      _refreshQuote();
                    },
                  ))
              .toList(),
        ),
        TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description du colis (facultatif)')),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'STANDARD', label: Text('Standard · 2 h')),
            ButtonSegment(value: 'EXPRESS', label: Text('Express · 45 min'), icon: Icon(Icons.bolt)),
          ],
          selected: {_urgency},
          onSelectionChanged: (s) {
            setState(() => _urgency = s.first);
            _refreshQuote();
          },
        ),
        const SizedBox(height: 16),
        if (_quoting) const LinearProgressIndicator(color: C.primary),
        if (_quote != null) ...[
          Text('Choisissez votre livreur · ${km(_quote!.distanceKm)}', style: const TextStyle(fontWeight: FontWeight.w700, color: C.text)),
          const SizedBox(height: 8),
          if (_quote!.options.isEmpty)
            const Text('Aucun véhicule ne peut faire cette course (distance ou taille du colis).', style: TextStyle(color: C.error)),
          ..._quote!.options.map((o) {
            final isSel = o.vehicle == _vehicle;
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isSel ? C.primary : C.disable, width: isSel ? 2 : 1),
              ),
              child: ListTile(
                onTap: () => setState(() => _vehicle = o.vehicle),
                leading: Icon(vehicleIcons[o.vehicle], color: isSel ? C.primary : C.textColor, size: 30),
                title: Text(vehicleLabels[o.vehicle] ?? o.vehicle, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Arrivée estimée ~${o.etaMinutes} min'),
                trailing: Text(eur(o.priceTtc), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            );
          }),
          if (selected != null)
            Text('dont TVA ${eur(selected.priceTva)}. Votre carte est débitée à la livraison.',
                style: const TextStyle(color: C.textColor, fontSize: 12)),
        ],
        const SizedBox(height: 80),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(52)),
            onPressed: selected == null || _ordering ? null : _order,
            child: Text(_ordering ? 'Commande…' : selected == null ? 'Indiquez les deux adresses' : 'Commander et payer · ${eur(selected.priceTtc)}'),
          ),
        ),
      ),
    );
  }
}
