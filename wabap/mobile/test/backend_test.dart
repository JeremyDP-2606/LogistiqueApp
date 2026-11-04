// Accès au serveur sans Amplify : client GraphQL, envoi de fichiers, lecture des modèles V1.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wabap/backend/backend.dart';
import 'package:wabap/models/ModelProvider.dart';

void main() {
  setUp(() {
    Api.endpoint = 'https://api.test/graphql';
    Api.tokenProvider = () async => 'jeton-id';
  });

  group('Api.graphql', () {
    test('envoie le jeton et la requête, renvoie data', () async {
      late http.Request sent;
      Api.httpClient = MockClient((req) async {
        sent = req;
        return http.Response(jsonEncode({'data': {'getTournee': {'id': 't1'}}}), 200);
      });
      final data = await Api.graphql(r'query($id: ID!) { getTournee(id: $id) { id } }', {'id': 't1'});
      expect(data['getTournee'], {'id': 't1'});
      expect(sent.url.toString(), 'https://api.test/graphql');
      expect(sent.headers['Authorization'], 'jeton-id');
      expect(jsonDecode(sent.body)['variables'], {'id': 't1'});
    });

    test('erreur GraphQL : ApiException avec son type', () async {
      // Réponse UTF-8 comme celle du serveur (accents compris)
      Api.httpClient = MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'data': null, 'errors': [{'message': 'Accès refusé', 'errorType': 'Unauthorized'}]})), 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      await expectLater(
        Api.graphql('{ listTournees { items { id } } }'),
        throwsA(isA<ApiException>().having((e) => e.errorType, 'errorType', 'Unauthorized').having((e) => e.message, 'message', 'Accès refusé')),
      );
    });

    test('jeton refusé : 401 reconnu', () async {
      Api.httpClient = MockClient((_) async => http.Response(jsonEncode({'errors': [{'message': 'Jeton absent', 'errorType': 'UnauthorizedException'}]}), 401));
      try {
        await Api.graphql('{ __typename }');
        fail('exception attendue');
      } on ApiException catch (e) {
        expect(e.isUnauthorized, isTrue);
      }
    });
  });

  test('Api.upload : lien temporaire demandé puis fichier déposé', () async {
    final calls = <http.Request>[];
    Api.httpClient = MockClient((req) async {
      calls.add(req);
      if (req.url.path == '/graphql') {
        final vars = jsonDecode(req.body)['variables'];
        expect(vars['key'], 'tournee_T1/signature_picking.jpg');
        return http.Response(
            jsonEncode({
              'data': {
                'createUploadUrl': jsonEncode({'key': 'public/tournee_T1/signature_picking.jpg', 'url': 'https://s3.test/depot?sig=1', 'headers': {'Content-Type': 'image/jpeg'}})
              }
            }),
            200);
      }
      return http.Response('', 200);
    });
    final key = await Api.upload(Uint8List.fromList([1, 2, 3]), kind: 'preuve', contentType: 'image/jpeg', key: 'tournee_T1/signature_picking.jpg');
    expect(key, 'public/tournee_T1/signature_picking.jpg');
    expect(calls.last.method, 'PUT');
    expect(calls.last.url.host, 's3.test');
    expect(calls.last.bodyBytes, [1, 2, 3]);
    expect(calls.last.headers['Content-Type'], startsWith('image/jpeg'));
  });

  group('modèles V1', () {
    final colisJson = {
      'id': 'C1',
      'owner': 'France-Antilles',
      'tourneeColisId': 'T1',
      'position': 2,
      'createdAt': '2026-11-04T10:00:00.000Z',
      'address': '5 rue Victor Hugo',
      'longitude': -61.07,
      'latitude': 14.6,
      'subscriberName': 'Dupont',
      'colisLastStatusId': 'S1',
      'lastStatus': {'id': 'S1', 'status': 'PICKED_UP', 'createdAt': '2026-11-04T10:05:00.000Z'},
      'tournee': {'id': 'T1'},
      'subscriber': {'id': 'A1', 'name': 'Dupont', 'phone1': '0696'},
      'logs': {'items': [{'id': 'S0', 'status': 'PENDING', 'createdAt': '2026-11-04T09:00:00.000Z'}]},
    };

    test('lecture du JSON de l\'API (objets imbriqués et connexions)', () {
      final c = Colis.fromJson(colisJson);
      expect(c.position, 2);
      expect(c.lastStatus.status, Status.PICKED_UP);
      expect(c.lastStatus.createdAt.getDateTimeInUtc(), DateTime.utc(2026, 11, 4, 10, 5));
      expect(c.tournee.id, 'T1');
      expect(c.subscriber?.phone1, '0696');
      expect(c.logs!.single.status, Status.PENDING);
    });

    test('entrée de mutation : clés étrangères, sans relations ni valeurs nulles', () {
      final updated = Colis.fromJson(colisJson).copyWith(colisLastStatusId: 'S2');
      final input = updated.toInput();
      expect(input['colisLastStatusId'], 'S2');
      expect(input['tourneeColisId'], 'T1');
      expect(input['subscriberColisId'], 'A1');
      expect(input.containsKey('tournee'), isFalse);
      expect(input.containsKey('polyline'), isFalse);
      expect(input['createdAt'], '2026-11-04T10:00:00.000Z');
    });

    test('nouveau statut rattaché à son colis', () {
      final st = ColisStatus(colis: Colis.fromJson(colisJson), status: Status.COMPLETED, createdAt: TemporalDateTime(DateTime.utc(2026, 11, 4, 11)), owner: 'France-Antilles');
      final input = st.toInput();
      expect(input['colisLogsId'], 'C1');
      expect(input['status'], 'COMPLETED');
      expect(input['id'], hasLength(36));
    });

    test('ancien format local (serializedData) toujours lisible', () {
      final t = Tournee.fromJson({
        'id': 'T1',
        'owner': 'FA',
        'name': 'Tournée',
        'status': 'IN_PROGRESS',
        'startLongitude': 1,
        'startLatitude': 2,
        'livreurID': 'L1',
        'createdAt': '2026-11-04T05:00:00.000Z',
        'deliveryChecking': true,
        'mission': {'serializedData': {'id': 'M1', 'name': 'Secteur A'}},
      });
      expect(t.mission.name, 'Secteur A');
      expect(t.deliveryChecking, isTrue);
      expect(t.toInput()['missionTourneeId'], 'M1');
    });

    test('champ obligatoire non demandé : erreur explicite', () {
      final t = Tournee.fromJson({'id': 'T1'});
      expect(() => t.name, throwsA(isA<StateError>()));
    });
  });
}
