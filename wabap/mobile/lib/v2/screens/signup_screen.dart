// Inscription libre des clients (particuliers et professionnels) : e-mail vérifié par code.
import 'package:wabap/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../colors.dart';
import '../../provider/auth_provider.dart';
import '../common.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _awaitingCode = false;
  bool _busy = false;

  /// Cognito attend un numéro au format international (+596…, +33…)
  String? _e164(String raw) {
    var p = raw.replaceAll(RegExp(r'[\s.\-]'), '');
    if (p.isEmpty) return null;
    if (p.startsWith('00')) p = '+${p.substring(2)}';
    if (p.startsWith('0')) p = '+33${p.substring(1)}';
    return RegExp(r'^\+\d{8,15}$').hasMatch(p) ? p : null;
  }

  Future<void> _signUp() async {
    final email = _email.text.trim();
    if (_name.text.trim().isEmpty || email.isEmpty || _password.text.length < 8) {
      showError(context, 'Renseignez votre nom, votre e-mail et un mot de passe de 8 caractères minimum');
      return;
    }
    final phone = _e164(_phone.text);
    if (_phone.text.trim().isNotEmpty && phone == null) {
      showError(context, 'Numéro de téléphone invalide (ex. 0696 12 34 56 ou +596 696 12 34 56)');
      return;
    }
    setState(() => _busy = true);
    try {
      final confirmed = await CognitoAuth.instance.signUp(email, _password.text, {
        'email': email,
        'given_name': _name.text.trim(),
        if (phone != null) 'phone_number': phone,
      });
      if (confirmed) {
        await _signIn();
      } else {
        setState(() => _awaitingCode = true);
      }
    } on AuthException catch (e) {
      if (mounted) showError(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await CognitoAuth.instance.confirmSignUp(_email.text.trim(), _code.text.trim());
      await _signIn();
    } on AuthException catch (e) {
      if (mounted) showError(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await CognitoAuth.instance.resendSignUpCode(_email.text.trim());
      if (mounted) showInfo(context, 'Nouveau code envoyé à ${_email.text.trim()}');
    } on AuthException catch (e) {
      if (mounted) showError(context, e.message);
    }
  }

  Future<void> _signIn() async {
    final nav = Navigator.of(context);
    final error = await ref.read(authProvider).signInUser(_email.text.trim(), _password.text);
    if (error != null) {
      if (mounted) {
        showError(context, error == AuthError.networkError
            ? 'Compte créé, mais pas de connexion internet : reconnectez-vous plus tard'
            : 'Compte créé : connectez-vous avec votre e-mail et votre mot de passe');
      }
      nav.popUntil((r) => r.isFirst);
      return;
    }
    nav.popUntil((r) => r.isFirst);
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: C.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte'), backgroundColor: C.secondary, foregroundColor: C.white),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (!_awaitingCode) ...[
          const Text('Commandez une course en quelques secondes, payez par carte et suivez votre livreur en direct.',
              style: TextStyle(color: C.textColor)),
          const SizedBox(height: 20),
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: _deco('Prénom et nom', Icons.person_outline)),
          const SizedBox(height: 12),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: _deco('E-mail', Icons.mail_outline)),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: _deco('Téléphone (pour le livreur)', Icons.phone_outlined)),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true, decoration: _deco('Mot de passe (8 caractères min.)', Icons.lock_outline)),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(50)),
            onPressed: _busy ? null : _signUp,
            child: Text(_busy ? 'Création…' : 'Créer mon compte'),
          ),
        ] else ...[
          Text('Nous avons envoyé un code à ${_email.text.trim()}.', style: const TextStyle(fontSize: 16, color: C.text)),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w700),
            decoration: _deco('Code de vérification', Icons.verified_outlined),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(50)),
            onPressed: _busy ? null : _confirm,
            child: Text(_busy ? 'Vérification…' : 'Valider'),
          ),
          TextButton(onPressed: _resend, child: const Text('Renvoyer le code')),
        ],
      ]),
    );
  }
}
