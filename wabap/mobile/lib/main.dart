import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/models/ModelProvider.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/screen/error_screen.dart';
import 'package:wabap/screen/home_screen.dart';
import 'package:wabap/screen/login_screen.dart';
import 'package:wabap/screen/splash_screen.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:wabap/services/colis_status_sync_service.dart';

import 'package:wabap/v2/payment.dart';
import 'package:wabap/v2/screens/client_home_screen.dart';

import 'amplifyconfiguration.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: WabapApp()));
}

final initApp = FutureProvider<void>((ref) async {
  await Amplify.addPlugins(
      [AmplifyAPI(modelProvider: ModelProvider.instance, baseHttpClient: IdTokenHttpClient()), AmplifyAuthCognito(),AmplifyStorageS3(),
      ]);
  await Amplify.configure(amplifyconfig);

  // Must come BEFORE the first fetchSession(): the Amplify hub is a broadcast
  // stream, and the launch-time SESSION_EXPIRED is emitted by that very fetch.
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

class IdTokenHttpClient extends AWSBaseHttpClient {
  @override
  Future<AWSBaseHttpRequest> transformRequest(
    AWSBaseHttpRequest request,
  ) async {
    if (request.path != "/graphql") return request;
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      // valueOrNull, never .value: with an expired refresh token
      // fetchAuthSession() returns a session whose userPoolTokensResult is an
      // error result, and `.value` rethrows SessionExpiredException from inside
      // the HTTP layer, where nothing catches it. Skipping the header instead
      // lets AppSync answer 401, which the API error handling already covers —
      // and this very fetchAuthSession() is what makes Amplify emit the
      // SESSION_EXPIRED hub event that drives the sign-out.
      final idToken = session is CognitoAuthSession
          ? session.userPoolTokensResult.valueOrNull?.idToken.raw
          : null;
      if (idToken != null) {
        request.headers.addAll({AWSHeaders.authorization: idToken});
      } else {
        safePrint('IdTokenHttpClient: no usable ID token, header left as-is.');
      }
    } catch (e) {
      safePrint('IdTokenHttpClient: could not attach ID token ($e).');
    }
    return request;
  }
}
