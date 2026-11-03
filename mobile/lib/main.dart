import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/client_home.dart';
import 'screens/courier/courier_home.dart';
import 'services/session.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  final session = Session();
  session.restore();
  runApp(ChangeNotifierProvider.value(value: session, child: const LogistiqueApp()));
}

class LogistiqueApp extends StatelessWidget {
  const LogistiqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LogistiqueApp',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Root(),
    );
  }
}

/// Aiguillage selon l'état de session et le rôle.
class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    if (s.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final u = s.user;
    if (u == null) return const LoginScreen();
    return u.isCourier ? CourierHome(key: ValueKey(u.id)) : ClientHome(key: ValueKey(u.id));
  }
}
