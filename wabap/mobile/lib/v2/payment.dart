// Paiement par carte des courses (Stripe PaymentSheet).
// La carte est seulement autorisée à la commande ; la Lambda encaisse à la livraison.
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../colors.dart';

class Payment {
  /// Clé publique Stripe, fournie au build : --dart-define=STRIPE_PUBLISHABLE_KEY=pk_...
  static const publishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  static Future<void> init() async {
    if (publishableKey.isEmpty) return;
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
  }

  /// Affiche le formulaire de paiement. Renvoie false si le client l'a fermé sans payer.
  static Future<bool> authorize(String clientSecret) async {
    if (publishableKey.isEmpty) {
      throw Exception('Paiement non configuré dans cette version de l’app (STRIPE_PUBLISHABLE_KEY)');
    }
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Wabap',
        style: ThemeMode.light,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(primary: C.primary),
        ),
      ),
    );
    try {
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return false;
      throw Exception(e.error.localizedMessage ?? 'Paiement refusé');
    }
  }
}
