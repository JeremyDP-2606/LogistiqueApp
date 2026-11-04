import 'package:flutter/foundation.dart';

/// Journal de développement (n'affiche rien en production) ; remplace safePrint d'Amplify.
void safePrint(Object? message) {
  if (kDebugMode) debugPrint('$message');
}
