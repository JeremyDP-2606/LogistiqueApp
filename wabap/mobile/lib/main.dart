import 'package:wabap/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/screen/error_screen.dart';
import 'package:wabap/screen/home_screen.dart';
import 'package:wabap/screen/login_screen.dart';
import 'package:wabap/screen/splash_screen.dart';
import 'package:wabap/services/colis_status_sync_service.dart';

import 'package:wabap/v2/payment.dart';
import 'package:wabap/v2/screens/client_home_screen.dart';

import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: WabapApp()));
}

final initApp = FutureProvider<void>((ref) async {
  // Chaque appel à l'API porte le jeton d'identité Cognito (rafraîchi si besoin) ;
  // une session devenue inutilisable déclenche la déconnexion.
  Api.tokenProvider = () async {
    try {
      return (await CognitoAuth.instance.currentSession())?.idToken;
    } on AuthException catch (e) {
      if (e.failure == AuthFailure.sessionExpired) CognitoAuth.instance.reportExpired();
      return null;
    }
  };

  // À faire avant le premier fetchSession() : les événements de session ne sont pas rejoués.
  ref.read(authProvider).initHubListener();

  await ref.read(authProvider).fetchSession();

  // Start replaying any colis statuses left pending from a previous session and
  // listen for connectivity coming back.
  ColisStatusSyncService.instance.init();

  // Wabap V2 : paiement des courses à la demande
  await Payment.init();
});

class WabapApp extends ConsumerWidget {
  const WabapApp({super.key});

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initAsyncValue = ref.watch(initApp);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      navigatorKey: navigatorKey,
      home: initAsyncValue.when(
        data: (_) {
          final auth = ref.watch(authProvider);
          safePrint(">>>>>>>>>>> IS LOGIN : ${auth.isLogin()}");
          if (!auth.isLogin()) return const LoginScreen();
          return auth.usesTourneeHome ? const HomeScreen() : const ClientHomeScreen();
        },
        loading: () => const SplashScreen(),
        error: (e, __) => ErrorScreen(e.toString()),
      ),
    );
  }
}
