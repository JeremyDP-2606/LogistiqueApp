// Client de l'API Wabap : GraphQL (HTTP), temps réel (WebSocket, protocole graphql-transport-ws),
// routes REST (/v1/...) et envoi de fichiers par lien temporaire. Le jeton d'identité Cognito est
// ajouté à chaque appel.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'log.dart';

/// Erreur renvoyée par l'API (message lisible, type d'erreur du serveur)
class ApiException implements Exception {
  final String message;
  final String? errorType;
  final int? statusCode;
  const ApiException(this.message, {this.errorType, this.statusCode});

  bool get isUnauthorized => statusCode == 401 || errorType == 'UnauthorizedException';
  bool get isConditionFailed => errorType == 'DynamoDB:ConditionalCheckFailedException';

  @override
  String toString() => message;
}

/// Fournit le jeton à joindre aux appels (null si déconnecté)
typedef TokenProvider = Future<String?> Function();

class Api {
  /// Adresse de l'API (modifiable pour la démonstration)
  static String endpoint = BackendConfig.apiUrl;
  static TokenProvider tokenProvider = () async => null;
  static http.Client httpClient = http.Client();
  static Duration timeout = const Duration(seconds: 30);

  static Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': token};
  }

  /// Requête ou mutation GraphQL : renvoie `data`, lève [ApiException] en cas d'erreur.
  static Future<Map<String, dynamic>> graphql(String document, [Map<String, dynamic>? variables]) async {
    final res = await httpClient
        .post(Uri.parse(endpoint), headers: await _headers(), body: jsonEncode({'query': document, 'variables': variables ?? {}}))
        .timeout(timeout);
    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Réponse invalide du serveur (${res.statusCode})', statusCode: res.statusCode);
    }
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final e = errors.first as Map;
      throw ApiException('${e['message']}', errorType: e['errorType'] as String?, statusCode: res.statusCode);
    }
    if (res.statusCode >= 400) throw ApiException('Erreur ${res.statusCode}', statusCode: res.statusCode);
    return Map<String, dynamic>.from(body['data'] as Map? ?? {});
  }

  /// Route REST du serveur (/v1/...)
  static Future<dynamic> rest(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('${endpoint.replaceFirst(RegExp(r'/graphql/?$'), '')}/v1$path'))..headers.addAll(await _headers());
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await httpClient.send(req).timeout(timeout));
    final data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) throw ApiException('${(data is Map ? data['error'] : null) ?? 'Erreur ${res.statusCode}'}', statusCode: res.statusCode);
    return data;
  }

  /// Envoi d'un fichier (photo, signature) : lien temporaire demandé à l'API puis dépôt direct.
  /// [key] : emplacement V1 (tournee_<id>/<fichier>), sinon rangé par le serveur. Renvoie la clé finale.
  static Future<String> upload(Uint8List bytes, {required String kind, required String contentType, String? tourId, String? key}) async {
    final data = await graphql(
      r'mutation U($kind: String!, $contentType: String!, $tourId: ID, $key: String) { createUploadUrl(kind: $kind, contentType: $contentType, tourId: $tourId, key: $key) }',
      {'kind': kind, 'contentType': contentType, 'tourId': tourId, 'key': key},
    );
    final raw = data['createUploadUrl'];
    final up = Map<String, dynamic>.from(raw is String ? jsonDecode(raw) as Map : raw as Map);
    final res = await httpClient
        .put(Uri.parse(up['url'] as String), headers: Map<String, String>.from(up['headers'] as Map? ?? {'Content-Type': contentType}), body: bytes)
        .timeout(const Duration(minutes: 2));
    if (res.statusCode >= 300) throw ApiException("Envoi du fichier refusé (${res.statusCode})", statusCode: res.statusCode);
    return up['key'] as String;
  }

  /// Abonnement temps réel : flux des `data` reçues. Reconnexion automatique tant que le flux est écouté.
  static Stream<Map<String, dynamic>> subscribe(String document, [Map<String, dynamic>? variables]) {
    late StreamController<Map<String, dynamic>> controller;
    WebSocketChannel? channel;
    StreamSubscription? sub;
    Timer? retry;
    var closed = false;
    var attempt = 0;
    late void Function() schedule;

    void connect() async {
      if (closed) return;
      try {
        channel = WebSocketChannel.connect(Uri.parse(endpoint.replaceFirst(RegExp('^http'), 'ws')), protocols: ['graphql-transport-ws']);
        await channel!.ready;
        channel!.sink.add(jsonEncode({'type': 'connection_init', 'payload': {'Authorization': await tokenProvider()}}));
        sub = channel!.stream.listen((raw) {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          switch (msg['type']) {
            case 'connection_ack':
              attempt = 0;
              channel!.sink.add(jsonEncode({'id': '1', 'type': 'subscribe', 'payload': {'query': document, 'variables': variables ?? {}}}));
              break;
            case 'next':
              final payload = msg['payload'] as Map;
              if (payload['data'] != null) controller.add(Map<String, dynamic>.from(payload['data'] as Map));
              break;
            case 'ping':
              channel!.sink.add(jsonEncode({'type': 'pong'}));
              break;
            case 'error':
              safePrint('Temps réel : erreur ${msg['payload']}');
              break;
          }
        }, onDone: () => schedule(), onError: (_) => schedule(), cancelOnError: true);
      } catch (e) {
        schedule();
      }
    }

    schedule = () {
      if (closed) return;
      sub?.cancel();
      retry?.cancel();
      final delay = Duration(seconds: [1, 2, 5, 10, 30][attempt.clamp(0, 4)]);
      attempt++;
      retry = Timer(delay, connect);
    };

    controller = StreamController<Map<String, dynamic>>(
      onListen: connect,
      onCancel: () async {
        closed = true;
        retry?.cancel();
        await sub?.cancel();
        try {
          channel?.sink.add(jsonEncode({'id': '1', 'type': 'complete'}));
        } catch (_) {}
        await channel?.sink.close();
      },
    );
    return controller.stream;
  }
}
