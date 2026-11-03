import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../labels.dart';
import '../../services/session.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _role = 'client';
  String _vehicle = 'bike';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      await context.read<Session>().register({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'role': _role,
        if (_role == 'courier') 'vehicle': _vehicle,
      });
      nav.popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'client', label: Text('J’expédie'), icon: Icon(Icons.inventory_2_outlined)),
            ButtonSegment(value: 'courier', label: Text('Je livre'), icon: Icon(Icons.pedal_bike)),
          ],
          selected: {_role},
          onSelectionChanged: (s) => setState(() => _role = s.first),
        ),
        const SizedBox(height: 20),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom complet')),
        const SizedBox(height: 12),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone')),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe (6+ caractères)')),
        if (_role == 'courier') ...[
          const SizedBox(height: 20),
          const Text('Votre véhicule', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: vehicleLabels.entries
                .map((e) => ChoiceChip(
                      avatar: Icon(vehicleIcons[e.key], size: 18),
                      label: Text(e.value),
                      selected: _vehicle == e.key,
                      onSelected: (_) => setState(() => _vehicle = e.key),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 28),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Création…' : 'Créer mon compte')),
      ]),
    );
  }
}
