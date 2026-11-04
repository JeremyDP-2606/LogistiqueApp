// Envoi des preuves (photos, signatures) : lien d'envoi temporaire fourni par l'API Wabap.
// Rangées par le serveur sous proofs/<livreur>/<tournée>/ (fichiers privés).
import 'dart:typed_data';

import 'package:wabap/backend/backend.dart';

import 'demo_hooks.dart';

class ProofUpload {
  static Future<String> bytes(Uint8List data, {required String tourId, required String kind, String ext = 'jpg'}) async {
    if (DemoHooks.upload != null) return DemoHooks.upload!(data, kind);
    return Api.upload(data, kind: kind, contentType: ext == 'png' ? 'image/png' : 'image/jpeg', tourId: tourId);
  }
}
