import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);
  @override
  String toString() => message;
}

/// Client HTTP minimal pour l'API LogistiqueApp.
class Api {
  String? token;

  Uri _uri(String path) => Uri.parse('$apiUrl/api$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String path) => _send(http.get(_uri(path), headers: _headers));
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _send(http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));
  Future<Map<String, dynamic>> patch(String path, [Map<String, dynamic>? body]) =>
      _send(http.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> _send(Future<http.Response> req) async {
    final http.Response res;
    try {
      res = await req.timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Serveur injoignable ($apiUrl)', 0);
    }
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode >= 400) {
      throw ApiException(data['error'] as String? ?? 'Erreur ${res.statusCode}', res.statusCode);
    }
    return data;
  }
}
