// Point d'entrée de DÉMONSTRATION (vidéo, présentation commerciale), jamais publié en production.
//
//   flutter build web -t lib/main_demo.dart --no-web-resources-cdn --dart-define=GOOGLE_MAPS_API_KEY=demo
//   puis ouvrir index.html?persona=client ou ?persona=livreur
//
// Différences avec l'app réelle :
//  - utilisateur déjà connecté (profil fictif, sans Cognito) ;
//  - API servie par le serveur Wabap en mode démonstration (backend : DEMO_SEED=true, données fictives) ;
//  - paiement Stripe, appareil photo, scanner et envoi des preuves simulés (DemoHooks).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:wabap/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'colors.dart';
import 'provider/auth_provider.dart';
import 'theme.dart';
import 'v2/demo_hooks.dart';
import 'v2/screens/client_home_screen.dart';
import 'v2/screens/courier_tours_screen.dart';

class DemoPersona {
  final String id;
  final String name;
  final List<String> groups;
  final String apiKey;
  const DemoPersona(this.id, this.name, this.groups, this.apiKey);
}

const personas = {
  'client': DemoPersona('part-demo', 'Jessica', [], 'demo-client'),
  'livreur': DemoPersona('livreur-lea', 'Léa', ['livreur'], 'demo-livreur'),
};

/// Session fictive : remplace la session Cognito.
class DemoAuthModel extends AuthModel {
  final DemoPersona p;
  DemoAuthModel(this.p);
  @override
  String? get myId => p.id;
  @override
  String? get myTrueId => p.id;
  @override
  String? get name => p.name;
  @override
  String? get clientName => null;
  @override
  bool get isAdmin => false;
  @override
  bool get isSuperAdmin => false;
  @override
  List<String> get groups => p.groups;
  @override
  bool isLogin() => true;
  @override
  Future<void> logout() async {}
}

final _navigatorKey = GlobalKey<NavigatorState>();
int _uploads = 0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final persona = personas[Uri.base.queryParameters['persona']] ?? personas['client']!;
  // Serveur Wabap en mode démonstration (AUTH_MODE=dev) : jeton de démo du profil choisi
  Api.endpoint = Uri.base.queryParameters['api'] ?? 'https://api.wabap-demo.test/graphql';
  Api.tokenProvider = () async => persona.apiKey;

  DemoHooks.pay = (_) => _demoPaymentSheet();
  DemoHooks.takePhoto = _demoPhoto;
  DemoHooks.upload = (data, kind) async => 'demo/$kind-${++_uploads}.jpg';
  // Scanner simulé : « lit » l'étiquette du prochain colis du point (vrai code signé, vérifié par le serveur)
  DemoHooks.scan = (stop, scanned) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    for (final p in stop.parcels) {
      if (!scanned.contains(p.id)) return p.code;
    }
    return null;
  };

  runApp(ProviderScope(
    overrides: [authProvider.overrideWith((ref) => DemoAuthModel(persona))],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      navigatorKey: _navigatorKey,
      home: persona.groups.contains('livreur') ? const CourierToursScreen() : const ClientHomeScreen(),
    ),
  ));
}

/// Photo de démonstration générée (pas d'appareil photo dans une démo web)
Future<Uint8List?> _demoPhoto() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 640, 480), Paint()..color = const Color(0xFFE9DFCF));
  canvas.drawRect(const Rect.fromLTWH(200, 150, 240, 180), Paint()..color = const Color(0xFFB98A52));
  final img = await recorder.endRecording().toImage(640, 480);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

/// Formulaire de paiement de test (Stripe ne fonctionne pas dans une démo web hors ligne)
Future<bool> _demoPaymentSheet() async {
  final context = _navigatorKey.currentContext!;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => const _DemoPaymentSheet(),
  );
  return ok ?? false;
}

class _DemoPaymentSheet extends StatefulWidget {
  const _DemoPaymentSheet();
  @override
  State<_DemoPaymentSheet> createState() => _DemoPaymentSheetState();
}

class _DemoPaymentSheetState extends State<_DemoPaymentSheet> {
  bool _busy = false;

  InputDecoration _deco(String label) => InputDecoration(labelText: label, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)));

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.lock_outline, size: 18, color: C.textColor),
            const SizedBox(width: 6),
            const Text('Paiement sécurisé', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: C.primary_verylight, borderRadius: BorderRadius.circular(99)),
              child: const Text('Démonstration · carte de test', style: TextStyle(fontSize: 11, color: C.secondary)),
            ),
          ]),
          const SizedBox(height: 16),
          TextField(controller: TextEditingController(text: '4242 4242 4242 4242'), decoration: _deco('Numéro de carte')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: TextEditingController(text: '12 / 28'), decoration: _deco('Expiration'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: TextEditingController(text: '123'), decoration: _deco('CVC'))),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.primary, minimumSize: const Size.fromHeight(50)),
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await Future<void>.delayed(const Duration(milliseconds: 900));
                    if (context.mounted) Navigator.pop(context, true);
                  },
            child: Text(_busy ? 'Paiement…' : 'Payer'),
          ),
        ]),
      );
}
