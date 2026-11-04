import 'package:wabap/backend/backend.dart';
import 'package:wabap/models/json_helpers.dart';
import 'package:wabap/models/Colis.dart';
import 'package:wabap/models/ColisStatus.dart';
import 'package:wabap/models/Inscription.dart';
import 'package:wabap/models/Location.dart';
import 'package:wabap/models/Mission.dart';
import 'package:wabap/models/Status.dart';
import 'package:wabap/models/Tournee.dart';
import 'package:synchronized/synchronized.dart';

class PaginationResponse<T> {
  final List<T> list;
  final String? nextToken;
  PaginationResponse({required this.list, this.nextToken});
}

class RapportInput {
  final String tourneeId;
  final String message;

  RapportInput({required this.tourneeId, required this.message});

  Map<String, dynamic> toMap() {
    return {
      'tourneeId': tourneeId,
      'message': message,
    };
  }
}

class RapportResponse {
  final int statusCode;
  final String? message; // <-- Make message nullable

  RapportResponse({required this.statusCode, this.message}); // <-- Allow null

  factory RapportResponse.fromMap(Map<String, dynamic> map) {
    return RapportResponse(
      statusCode: map['statusCode'],
      message: map['message'] ?? "No message provided", // <-- Handle null safely
    );
  }
}


// Accès aux données V1 (tournées, colis, missions, positions) par l'API Wabap.
class API {
  // Champs demandés à l'API pour chaque modèle
  static const _missionLite = 'mission { id owner name livreurID startName startLongitude startLatitude startTimeZone deliveryChecking }';
  static const _tourneeFields = 'id owner name status startName startLongitude startLatitude livreurID missionTourneeId createdAt updatedAt distance duree nbColis deliveryChecking $_missionLite';
  static const _colisStatusFields = 'id owner colisLogsId status message createdAt updatedAt longitude latitude';
  static const _colisFields = 'id owner tourneeColisId position polyline distance duration createdAt updatedAt address longitude latitude '
      'subscriberColisId subscriberName colisLastStatusId lastStatus { id owner status message createdAt } tournee { id } '
      'subscriber { id owner name phone1 phone2 instructions numabo }';
  static const _locationFields = 'id owner userId userName tourneeId latitude longitude lastUpdate createdAt updatedAt';
  static const _inscriptionFields = 'id owner livreurID missionInscriptionsId createdAt updatedAt';

  static Map<String, dynamic>? _obj(Map<String, dynamic> data, String key) =>
      data[key] == null ? null : Map<String, dynamic>.from(data[key] as Map);

  static Future<RapportResponse> invokeLambdaRapportTournee(RapportInput input) async {
    final data = await Api.graphql(
        r'mutation InvokeLambdaRapportTournee($input: RapportInput!) { invokeLambdaRapportTournee(input: $input) { statusCode message } }',
        {'input': input.toMap()});
    safePrint("Rapport : $data");
    final r = _obj(data, 'invokeLambdaRapportTournee');
    if (r == null) throw Exception("Error: response.data is null");
    return RapportResponse.fromMap(r);
  }

  static Future<PaginationResponse<Tournee>> loadTournees(String livreurId, [String? nextToken, int limit = 50]) async {
    safePrint(">>>> loadTournees($livreurId, $nextToken, $limit)");
    final data = await Api.graphql(
        'query ByLivreurOrderDate(\$livreurId: ID!, \$sortDirection: ModelSortDirection, \$limit: Int, \$nextToken: String) { '
        'byLivreurOrderDate(livreurID: \$livreurId, sortDirection: \$sortDirection, limit: \$limit, nextToken: \$nextToken) { '
        'items { $_tourneeFields colis(limit: 1000) { items { id longitude latitude lastStatus { id owner status } } } } nextToken } }',
        {'livreurId': livreurId, 'sortDirection': 'DESC', 'limit': limit, 'nextToken': nextToken});
    final page = data['byLivreurOrderDate'] as Map;
    final tournees = listOf(page['items'])!.map(Tournee.fromJson).toList();
    safePrint(">>>> loadTournees REP = tournees=[${tournees.length}] - nextToken=[${page['nextToken']}]");
    return PaginationResponse(list: tournees, nextToken: page['nextToken'] as String?);
  }

  static Future<PaginationResponse<Mission>> loadMissions([String? nextToken, int limit = 50]) async {
    safePrint(">>>> loadMissions($nextToken, $limit)");
    final data = await Api.graphql(
        r'query MyQuery($limit: Int, $nextToken: String) { listMissions(limit: $limit, nextToken: $nextToken) { items { '
        r'id owner createdAt daysOfWeek generateDayBefore livreurID name startLatitude startLongitude startName startTime startTimeZone deliveryChecking '
        r'subscribers(limit: 200, filter: {unsubscribed: {eq: false}}) { items { id owner latitude longitude name type nb } nextToken } '
        r'inscriptions { items { id owner livreurID } nextToken } updatedAt } nextToken } }',
        {'limit': limit, 'nextToken': nextToken});
    final page = data['listMissions'] as Map;
    final missions = listOf(page['items'])!.map(Mission.fromJson).toList();
    safePrint(">>>> loadMissions REP = missions=[${missions.length}] - nextToken=[${page['nextToken']}]");
    return PaginationResponse(list: missions, nextToken: page['nextToken'] as String?);
  }

  static Future<PaginationResponse<Colis>> loadColis(String tourneeId, [String? nextToken, int limit = 50]) async {
    safePrint(">>>> loadColis($tourneeId, $nextToken, $limit)");
    final data = await Api.graphql(
        'query ByTourneeOrderPosition(\$tourneeId: ID!, \$sortDirection: ModelSortDirection, \$limit: Int, \$nextToken: String) { '
        'byTourneeOrderPosition(tourneeColisId: \$tourneeId, sortDirection: \$sortDirection, limit: \$limit, nextToken: \$nextToken) { '
        'items { $_colisFields } nextToken } }',
        {'tourneeId': tourneeId, 'sortDirection': 'ASC', 'limit': limit, 'nextToken': nextToken});
    final page = data['byTourneeOrderPosition'] as Map;
    final listColis = listOf(page['items'])!.map(Colis.fromJson).toList();
    safePrint(">>>> loadColis REP = listColis=[${listColis.length}] - nextToken=[${page['nextToken']}]");
    return PaginationResponse(list: listColis, nextToken: page['nextToken'] as String?);
  }

  static Future<Colis?> updateColis(Colis updateColis) async {
    safePrint(">>>> updateColis($updateColis)");
    final data = await Api.graphql('mutation U(\$input: UpdateColisInput!) { updateColis(input: \$input) { $_colisFields } }',
        {'input': updateColis.toInput()});
    final c = _obj(data, 'updateColis');
    return c == null ? null : Colis.fromJson(c);
  }

  static var lockUpdateLocation = Lock();
  static void updateLocation(
      String userId, String? userName, List<Tournee> listTourneeInProgress, double lat, double lng) async {
    await lockUpdateLocation.synchronized(() async {
      safePrint(">>>> updateLocation($userId, $listTourneeInProgress, $lat, $lng)");
      final data = await Api.graphql(
          'query L(\$userId: ID!) { listLocations(filter: { userId: { eq: \$userId } }, limit: 1000) { items { $_locationFields } } }',
          {'userId': userId});
      final allLocationOfUser = listOf((data['listLocations'] as Map)['items'])!.map(Location.fromJson).toList();

      for (final location in allLocationOfUser) {
        Tournee? tourneeOfLocartion;
        try {
          tourneeOfLocartion = listTourneeInProgress.firstWhere((tournee) => tournee.id == location.tourneeId);
        } catch (e) {} // ignore: empty_catches
        if (tourneeOfLocartion != null) {
          final updateLocation = Location(
              owner: location.owner,
              id: location.id,
              tourneeId: location.tourneeId,
              userId: userId,
              userName: userName,
              latitude: lat,
              longitude: lng,
              lastUpdate: TemporalDateTime.now());
          await Api.graphql('mutation U(\$input: UpdateLocationInput!) { updateLocation(input: \$input) { $_locationFields } }',
              {'input': updateLocation.toInput()});
          listTourneeInProgress.remove(tourneeOfLocartion);
        } else {
          await Api.graphql(r'mutation D($input: DeleteLocationInput!) { deleteLocation(input: $input) { id } }', {
            'input': {'id': location.id}
          });
        }
      }
      for (final tournee in listTourneeInProgress) {
        final newLocation = Location(
            owner: tournee.owner,
            userId: userId,
            tourneeId: tournee.id,
            userName: userName,
            latitude: lat,
            longitude: lng,
            lastUpdate: TemporalDateTime.now());
        await Api.graphql('mutation C(\$input: CreateLocationInput!) { createLocation(input: \$input) { $_locationFields } }',
            {'input': newLocation.toInput()});
      }
    });
  }

  static Future<Tournee?> updateTournee(Tournee updateTournee) async {
    safePrint(">>>> updateTournee($updateTournee)");
    final data = await Api.graphql('mutation U(\$input: UpdateTourneeInput!) { updateTournee(input: \$input) { $_tourneeFields } }',
        {'input': updateTournee.toInput()});
    final t = _obj(data, 'updateTournee');
    return t == null ? null : Tournee.fromJson(t);
  }

  static Future<Tournee?> getTournee(String tourneeId) async {
    safePrint(">>>> getTournee($tourneeId)");
    final data = await Api.graphql('query G(\$id: ID!) { getTournee(id: \$id) { $_tourneeFields } }', {'id': tourneeId});
    final t = _obj(data, 'getTournee');
    return t == null ? null : Tournee.fromJson(t);
  }

  static Future<Colis?> getColis(String colisId) async {
    safePrint(">>>> getColis($colisId)");
    final data = await Api.graphql('query G(\$id: ID!) { getColis(id: \$id) { $_colisFields } }', {'id': colisId});
    final c = _obj(data, 'getColis');
    return c == null ? null : Colis.fromJson(c);
  }

  static Future<ColisStatus?> createColisStatus(
    Status status,
    String? message,
    Colis colis, {
    String? id,
    double? latitude,
    double? longitude,
    TemporalDateTime? createdAt,
  }) async {
    safePrint(">>>> createColisStatus($status, id=$id)");
    final input = ColisStatus(
      id: id,
      owner: colis.owner,
      colis: colis,
      status: status,
      message: message,
      createdAt: createdAt ?? TemporalDateTime.now(),
      latitude: latitude,
      longitude: longitude,
    ).toInput();
    final data = await Api.graphql(
        'mutation C(\$input: CreateColisStatusInput!) { createColisStatus(input: \$input) { $_colisStatusFields } }', {'input': input});
    final st = _obj(data, 'createColisStatus');
    return st == null ? null : ColisStatus.fromJson(st);
  }

  static Future<ColisStatus?> getColisStatus(String id) async {
    final data = await Api.graphql('query G(\$id: ID!) { getColisStatus(id: \$id) { $_colisStatusFields } }', {'id': id});
    final st = _obj(data, 'getColisStatus');
    return st == null ? null : ColisStatus.fromJson(st);
  }

  /// Idempotently applies a colis status change to the backend: creates the
  /// `ColisStatus` row (with a client-provided [statusId]) then points the colis
  /// `colisLastStatusId` at it. Safe to call multiple times for the same
  /// [statusId] (used by both the optimistic write path and the offline sync).
  static Future<void> pushColisStatus({
    required Colis colis,
    required String statusId,
    required Status status,
    String? message,
    double? latitude,
    double? longitude,
    required TemporalDateTime createdAt,
  }) async {
    final colisStatus = ColisStatus(
      id: statusId,
      owner: colis.owner,
      status: status,
      message: message,
      createdAt: createdAt,
      latitude: latitude,
      longitude: longitude,
    );

    try {
      await createColisStatus(
        status,
        message,
        colis,
        id: statusId,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
      );
    } catch (e) {
      // If the status row already exists (a previous attempt created it but
      // failed before marking synced), treat it as success and continue.
      final existing = await getColisStatus(statusId);
      if (existing == null) rethrow;
      safePrint(">>>> pushColisStatus: status $statusId already exists, skipping create");
    }

    final newColis = colis.copyWith(lastStatus: colisStatus, colisLastStatusId: statusId);
    await updateColis(newColis);
  }

  static Future<Inscription?> createInscription(Inscription inscription) async {
    safePrint(">>>> createInscription($inscription)");
    final data = await Api.graphql(
        'mutation C(\$input: CreateInscriptionInput!) { createInscription(input: \$input) { $_inscriptionFields } }', {'input': inscription.toInput()});
    final i = _obj(data, 'createInscription');
    return i == null ? null : Inscription.fromJson(i);
  }

  static Future<Inscription?> deleteInscription(Inscription inscription) async {
    safePrint(">>>> deleteInscription($inscription)");
    final data = await Api.graphql(
        'mutation D(\$input: DeleteInscriptionInput!) { deleteInscription(input: \$input) { $_inscriptionFields } }', {
      'input': {'id': inscription.id}
    });
    final i = _obj(data, 'deleteInscription');
    return i == null ? null : Inscription.fromJson(i);
  }
}
