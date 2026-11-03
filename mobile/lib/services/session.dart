import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api.dart';
import 'realtime.dart';

/// État global : utilisateur connecté, client API et connexion temps réel.
class Session extends ChangeNotifier {
  final Api api = Api();
  final Realtime realtime = Realtime();
  AppUser? user;
  bool loading = true;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      api.token = token;
      try {
        final d = await api.get('/auth/me');
        _setUser(AppUser.fromJson(d['user'] as Map<String, dynamic>), token);
      } catch (_) {
        api.token = null;
        await prefs.remove('token');
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final d = await api.post('/auth/login', {'email': email, 'password': password});
    await _authenticated(d);
  }

  Future<void> register(Map<String, dynamic> payload) async {
    final d = await api.post('/auth/register', payload);
    await _authenticated(d);
  }

  Future<void> _authenticated(Map<String, dynamic> d) async {
    final token = d['token'] as String;
    final user = AppUser.fromJson(d['user'] as Map<String, dynamic>);
    if (user.role == 'admin') {
      throw ApiException('Les administrateurs utilisent la console web', 403);
    }
    api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    _setUser(user, token);
    notifyListeners();
  }

  void _setUser(AppUser u, String token) {
    user = u;
    realtime.connect(token);
  }

  void updateUser(AppUser u) {
    user = u;
    notifyListeners();
  }

  Future<void> logout() async {
    if (user?.isCourier == true && user!.online) {
      try {
        await api.patch('/courier/status', {'online': false});
      } catch (_) {}
    }
    realtime.disconnect();
    api.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }
}
