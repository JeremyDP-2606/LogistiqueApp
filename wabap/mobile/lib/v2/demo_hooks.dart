// Points d'accroche de DÉMONSTRATION. En production ils restent tous à null et l'app utilise
// les vrais services (Stripe, appareil photo, scanner, S3). Seul lib/main_demo.dart les renseigne.
import 'dart:typed_data';

import 'platform_models.dart';

class DemoHooks {
  /// Paiement : renvoie true si payé
  static Future<bool> Function(String clientSecret)? pay;

  /// Photo : renvoie les octets d'une image
  static Future<Uint8List?> Function()? takePhoto;

  /// Scan : renvoie le code lu pour ce point (déjà scannés exclus)
  static Future<String?> Function(TourStop stop, Set<String> scannedParcelIds)? scan;

  /// Envoi d'une preuve : renvoie la clé du fichier
  static Future<String> Function(Uint8List data, String kind)? upload;
}
