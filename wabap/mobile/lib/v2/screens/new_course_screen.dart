import 'package:flutter/material.dart';

import '../../colors.dart';
import '../common.dart';
import '../payment.dart';
import '../platform_api.dart';
import '../platform_models.dart';
import 'address_search_screen.dart';

/// Commande d'une course ponctuelle (spec §11) : A → B, délai 1, 2 ou 3 jours, taille et poids,
/// prix détaillé, paiement immédiat. Renvoie l'identifiant de la demande créée.
class NewCourseScreen extends StatefulWidget {
  const NewCourseScreen({super.key});
  @override
  State<NewCourseScreen> createState() => _NewCourseScreenState();
}

class _NewCourseScreenState extends State<NewCourseScreen> {
  Map<String, dynamic>? _pickup;
  Map<String, dynamic>? _delivery;
  final _pickupName = TextEditingController();
  final _pickupPhone = TextEditingController();
  final _pickupNotes = TextEditingController();
  final _deliveryName = TextEditingController();
  final _deliveryPhone = TextEditingController();
  final _deliveryNotes = TextEditingController();
  final _weight = TextEditingController();
  final _promo = TextEditingController();
  String _size = 'S';
  int _maxDays = 2;
  Quote? _quote;
  String? _quoteError;
  bool _quoting = false;
  bool _ordering = false;

  Future<void> _pick(bool isPickup) async {
    final r = await AddressSearchScreen.open(context, isPickup ? 'Adresse de collecte' : 'Adresse de livraison');
    if (r == null) return;
    setState(() {
      final a = {'formatted': r.address, 'street': r.address, 'latitude': r.latitude, 'longitude': r.longitude};
      isPickup ? _pickup = a : _delivery = a;
    });
    _refreshQuote();
  }

  Map<String, dynamic> _input() => {
        'pickup': {'address': _pickup, 'name': _pickupName.text.trim(), 'phone': _pickupPhone.text.trim(), 'instructions': _pickupNotes.text.trim()},
        'delivery': {'address': _delivery, 'name': _deliveryName.text.trim(), 'phone': _deliveryPhone.text.trim(), 'instructions': _deliveryNotes.text.trim()},
        'size': _size,
        'maxDays': _maxDays,
        if (_weight.text.trim().isNotEmpty) 'weightKg': double.tryParse(_weight.text.trim().replaceAll(',', '.')),
        if (_promo.text.trim().isNotEmpty) 'promoCode': _promo.text.trim(),
      };

  Future<void> _refreshQuote() async {
    if (_pickup == null || _delivery == null) return;
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    try {
      final q = await PlatformApi.quote(_input());
      if (mounted) setState(() => _quote = q);
    } catch (e) {
      if (mounted) {
        setState(() {
          _quote = null;
          _quoteError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _order() async {
    if (_deliveryName.text.trim().isEmpty) {
      showError(context, 'Indiquez le nom du destinataire');
      return;
    }
    setState(() => _ordering = true);
    final nav = Navigator.of(context);
    try {
      final r = await PlatformApi.createCourse(_input());
      if (r.clientSecret != null) {
        final paid = await Payment.authorize(r.clientSecret!);
        if (!paid) {
          // Paiement abandonné : la demande est annulée, rien n'est débité
          await PlatformApi.cancel(r.orderId, reason: 'Paiement abandonné').catchError((_) {});
          if (mounted) showInfo(context, 'Paiement annulé : la course n’a pas été commandée');
          return;
        }
        await PlatformApi.confirmPayment(r.orderId);
      }
      nav.pop(r.orderId);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  Widget _pointCard({required bool isPickup}) {
    final addr = isPickup ? _pickup : _delivery;
    return Card(
      color: C.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: isPickup ? C.primary : C.ok, child: Text(isPickup ? 'A' : 'B', style: const TextStyle(color: C.white))),
            title: Text(addr?['formatted'] as String? ?? (isPickup ? 'Où récupérer le colis ?' : 'Où le livrer ?'),
                style: TextStyle(color: addr == null ? C.textColor : C.text)),
            trailing: const Icon(Icons.edit_location_alt_outlined),
            onTap: () => _pick(isPickup),
          ),
          Row(children: [
            Expanded(child: TextField(controller: isPickup ? _pickupName : _deliveryName, decoration: InputDecoration(labelText: isPickup ? 'Contact' : 'Destinataire'))),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(controller: isPickup ? _pickupPhone : _deliveryPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone')),
            ),
          ]),
          TextField(controller: isPickup ? _pickupNotes : _deliveryNotes, decoration: const InputDecoration(labelText: 'Instructions (étage, code…)')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F2),
      appBar: AppBar(title: const Text('Envoyer un colis'), backgroundColor: C.secondary, foregroundColor: C.white),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _pointCard(isPickup: true),
        _pointCard(isPickup: false),
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
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Poids (kg, facultatif)'),
          onSubmitted: (_) => _refreshQuote(),
        ),
        const SizedBox(height: 16),
        const Text('Délai de livraison', style: TextStyle(fontWeight: FontWeight.w700, color: C.text)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1 jour')),
            ButtonSegment(value: 2, label: Text('2 jours')),
            ButtonSegment(value: 3, label: Text('3 jours')),
          ],
          selected: {_maxDays},
          onSelectionChanged: (s) {
            setState(() => _maxDays = s.first);
            _refreshQuote();
          },
        ),
        TextField(controller: _promo, decoration: const InputDecoration(labelText: 'Code promo (facultatif)'), onSubmitted: (_) => _refreshQuote()),
        const SizedBox(height: 16),
        if (_quoting) const LinearProgressIndicator(color: C.primary),
        if (_quoteError != null) Text(_quoteError!, style: const TextStyle(color: C.error)),
        if (q != null)
          Card(
            color: C.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Détail du prix', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...q.lines.map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [Expanded(child: Text(l.label)), Text(eur(l.amount))]),
                    )),
                const Divider(),
                Row(children: [
                  const Expanded(child: Text('Total TTC', style: TextStyle(fontWeight: FontWeight.w700))),
                  Text(eur(q.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ]),
                Text('dont TVA ${eur(q.vat)}${q.deadlineAt != null ? ' · livré avant le ${dayTime(q.deadlineAt!)}' : ''}',
                    style: const TextStyle(color: C.textColor, fontSize: 12)),
              ]),
            ),
          ),
        const SizedBox(height: 80),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(52)),
            onPressed: q == null || _ordering ? null : _order,
            child: Text(_ordering ? 'Commande…' : q == null ? 'Indiquez les deux adresses' : 'Payer ${eur(q.total)} et commander'),
          ),
        ),
      ),
    );
  }
}
