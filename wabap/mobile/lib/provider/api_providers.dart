import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:wabap/models/Colis.dart';
import 'package:wabap/models/ColisStatus.dart';
import 'package:wabap/models/Inscription.dart';
import 'package:wabap/models/Location.dart';
import 'package:wabap/models/Mission.dart';
import 'package:wabap/models/Status.dart';
import 'package:wabap/models/Tournee.dart';
import 'package:synchronized/synchronized.dart';
import 'dart:convert';

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


class API {

  static Future<RapportResponse> invokeLambdaRapportTournee(RapportInput input) async {
    const String graphQLMutation = '''
  mutation InvokeLambdaRapportTournee(\$input: RapportInput!) {
    invokeLambdaRapportTournee(input: \$input) {
      statusCode
      message
    }
  }
  ''';

    final request = GraphQLRequest<String>(
      document: graphQLMutation,
      variables: {
        'input': input.toMap(),
      },
    );

    final response = await Amplify.API.mutate(request: request).response;

    safePrint("Raw response: ${response.data}");

    if (response.hasErrors) {
      throw Exception("Error invoking Lambda: ${response.errors}");
    }

    if (response.data == null) {
      throw Exception("Error: response.data is null");
    }

    final Map<String, dynamic> data = jsonDecode(response.data!);
    safePrint("Decoded response: $data");

    return RapportResponse.fromMap(data['invokeLambdaRapportTournee']);
  }


  static Future<PaginationResponse<Tournee>> loadTournees(String livreurId, [String? nextToken, int limit = 50]) async {
    safePrint(">>>> loadTournees($livreurId, $nextToken, $limit)");

    const String query = '''
      query ByLivreurOrderDate(
        \$livreurId: ID!
        \$sortDirection: ModelSortDirection
        \$limit: Int
        \$nextToken: String
      ) {
        byLivreurOrderDate(
          livreurID: \$livreurId
          sortDirection: \$sortDirection
          limit: \$limit
          nextToken: \$nextToken
        ) {
          items {
            id
            owner
            name
            status
            startName
            startLongitude
            startLatitude
            livreurID
            mission {
              id
            }
            createdAt
            updatedAt
            distance
            duree
            nbColis
            deliveryChecking
            colis(limit: 1000) {
              items {
                id
                longitude
                latitude
                lastStatus {
                  id
                  owner
                  status
                }
              }
            }
            __typename
          }
          nextToken
          __typename
        }
      }
''';

    var req = GraphQLRequest<PaginatedResult<Tournee>>(
        document: query,
        modelType: const PaginatedModelType(Tournee.classType),
        variables: {'livreurId': livreurId, 'sortDirection': 'DESC', 'limit': limit, 'nextToken': nextToken},
        decodePath: "byLivreurOrderDate");

    final req2 = Amplify.API.query(request: req);
    final rep = await req2.response;
    if (rep.hasErrors) throw rep.errors;
    var tournees = rep.data?.items ?? List.empty();

    safePrint(">>>> loadTournees REP = tournees=[${tournees.length}] - nextToken=[${rep.data?.nextToken}]");

    return PaginationResponse(
        list: tournees.where((tournee) => tournee != null).toList().cast<Tournee>(), nextToken: rep.data?.nextToken);
  }

  static Future<PaginationResponse<Mission>> loadMissions([String? nextToken, int limit = 50]) async {
    safePrint(">>>> loadMissions($nextToken, $limit)");

    const String query = '''
      query MyQuery(
        \$limit: Int
        \$nextToken: String
      ) {
        listMissions(
          limit: \$limit
          nextToken: \$nextToken
        ) {
          items {
            id
            owner
            createdAt
            daysOfWeek
            generateDayBefore
            livreurID
            name
            startLatitude
            startLongitude
            startName
            startTime
            startTimeZone
            subscribers(limit: 200, filter: {unsubscribed: {eq: false}}) {
              items {
                id
                owner
                latitude
                longitude
                name
              }
              nextToken
            }
            inscriptions {
              items {
                id
                owner
                livreurID
              }
              nextToken
            }
            updatedAt
          }
          nextToken
        }
      }

''';
    var req = GraphQLRequest<PaginatedResult<Mission>>(
        document: query,
        modelType: const PaginatedModelType(Mission.classType),
        variables: {'limit': limit, 'nextToken': nextToken},
        decodePath: "listMissions");

    final rep = await Amplify.API.query(request: req).response;
    if (rep.hasErrors) throw rep.errors;
    var missions = rep.data?.items ?? [];

    safePrint(">>>> loadMissions REP = missions=[${missions.length}] - nextToken=[${rep.data?.nextToken}]");

    return PaginationResponse(list: missions.whereType<Mission>().toList(), nextToken: rep.data?.nextToken);
  }

  static Future<PaginatedResult<Mission>?> loadMission2(
      [PaginatedResult<Mission>? previousPage, int limit = 50]) async {
    safePrint(">>>> loadMission(${previousPage?.hasNextResult}, $limit)");
    if (previousPage == null) {
      final req = ModelQueries.list(Mission.classType, limit: limit);
      final rep = await Amplify.API.query(request: req).response;
      safePrint(">>>> loadMission REP = rep=[$rep]");
      if (rep.hasErrors) throw rep.errors;
      return rep.data;
    } else if (previousPage.hasNextResult) {
      final req = previousPage.requestForNextResult;
      final rep = await Amplify.API.query(request: req!).response;
      safePrint(">>>> loadMission more REP = rep=[$rep]");
      if (rep.hasErrors) throw rep.errors;
      return rep.data;
    }
    return null;
  }

  static Future<PaginationResponse<Colis>> loadColis(String tourneeId, [String? nextToken, int limit = 50]) async {
    safePrint(">>>> loadColis($tourneeId, $nextToken, $limit)");

    const String query = '''
      query ByTourneeOrderPosition(
        \$tourneeId: ID!
        \$sortDirection: ModelSortDirection
        \$limit: Int
        \$nextToken: String
      ) {
        byTourneeOrderPosition(
          tourneeColisId: \$tourneeId
          sortDirection: \$sortDirection
          limit: \$limit
          nextToken: \$nextToken
        ) {
          items {
            id
            owner
            tourneeColisId
            position
            polyline
            distance
            duration
            createdAt
            updatedAt
            address
            longitude
            latitude
            subscriberColisId
            subscriberName
            colisLastStatusId
            lastStatus {
              id
              owner
              status
              createdAt
            }
            tournee {
              id
            }
            subscriber {
              id
              owner
              name
              phone1
              phone2
              instructions
              numabo
              __typename
            }
            __typename
          }
          nextToken
          __typename
        }
      }
''';
    var req = GraphQLRequest<PaginatedResult<Colis>>(
        document: query,
        modelType: const PaginatedModelType(Colis.classType),
        variables: {'tourneeId': tourneeId, 'sortDirection': 'ASC', 'limit': limit, 'nextToken': nextToken},
        decodePath: "byTourneeOrderPosition");

    final rep = await Amplify.API.query(request: req).response;
    if (rep.hasErrors) throw rep.errors;
    var listColis = rep.data?.items ?? List.empty();

    safePrint(">>>> loadColis REP = listColis=[${listColis.length}] - nextToken=[${rep.data?.nextToken}]");

    return PaginationResponse(
        list: listColis.where((colis) => colis != null).toList().cast<Colis>(), nextToken: rep.data?.nextToken);
  }

  static Future<Colis?> updateColis(Colis updateColis) async {
    safePrint(">>>> updateColis($updateColis)");
    final req = ModelMutations.update(updateColis);
    final rep = await Amplify.API.mutate(request: req).response;
    safePrint(">>>> updateColis REP = rep=[$rep]");
    if (rep.hasErrors) throw rep.errors;
    return rep.data;
  }

  static var lockUpdateLocation = Lock();
  static void updateLocation(
      String userId, String? userName, List<Tournee> listTourneeInProgress, double lat, double lng) async {
    await lockUpdateLocation.synchronized(() async {
      safePrint(">>>> updateLocation($userId, $listTourneeInProgress, $lat, $lng)");

      final request = ModelQueries.list(
        Location.classType,
        where: Location.USERID.eq(userId),
      );
      final rep = await Amplify.API.query(request: request).response;
      if (rep.hasErrors) throw rep.errors;
      final allLocationOfUser = rep.data?.items ?? <Location?>[];

      for (final location in allLocationOfUser) {
        if (location == null) break;
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
          final req = ModelMutations.update(updateLocation);
          final rep = await Amplify.API.mutate(request: req).response;
          safePrint(">>>> updateLocation REP = rep=[${rep.data?.latitude}, ${rep.data?.longitude}]");
          if (rep.hasErrors) throw rep.errors;
          listTourneeInProgress.remove(tourneeOfLocartion);
        } else {
          final req = ModelMutations.deleteById(Location.classType, LocationModelIdentifier(id: location.id));
          final rep = await Amplify.API.mutate(request: req).response;
          safePrint(">>>> deleteLocation REP = rep=[$rep]");
        }
      }
      for (final tournee in listTourneeInProgress) {
        final updateLocation = Location(
            owner: tournee.owner,
            userId: userId,
            tourneeId: tournee.id,
            userName: userName,
            latitude: lat,
            longitude: lng,
            lastUpdate: TemporalDateTime.now());
        final req = ModelMutations.create(updateLocation);
        final rep = await Amplify.API.mutate(request: req).response;
        safePrint(">>>> createLocation REP = rep=[$rep]");
        if (rep.hasErrors) throw rep.errors;
      }
    });
  }

  static Future<Tournee?> updateTournee(Tournee updateTournee) async {
    safePrint(">>>> updateTournee($updateTournee)");
    final req = ModelMutations.update(updateTournee);
    final rep = await Amplify.API.mutate(request: req).response;
    safePrint(">>>> updateTournee REP = rep=[$rep]");
    if (rep.hasErrors) throw rep.errors;
    return rep.data;
  }

  static Future<Tournee?> getTournee(String tourneeId) async {
    safePrint(">>>> getTournee($tourneeId)");
    final req = ModelQueries.get(Tournee.classType, TourneeModelIdentifier(id: tourneeId));
    final rep = await Amplify.API.query(request: req).response;
    if (rep.hasErrors) throw rep.errors;
    return rep.data;
  }

  static Future<Colis?> getColis(String colisId) async {
    safePrint(">>>> getColis($colisId)");
    final req = ModelQueries.get(Colis.classType, ColisModelIdentifier(id: colisId));
    final rep = await Amplify.API.query(request: req).response;
    safePrint(">>>> getColis REP = rep=[$rep]");
    if (rep.hasErrors) throw rep.errors;
    return rep.data;
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
    final req = ModelMutations.create(
      ColisStatus(
        id: id,
        owner: colis.owner,
        colis: colis,
        status: status,
        message: message,
        createdAt: createdAt ?? TemporalDateTime.now(),
        latitude: latitude,
        longitude: longitude,
      ),
    );
    final rep = await Amplify.API.mutate(request: req).response;
    safePrint(">>>> createColisStatus REP = rep=[$rep]");
    if (rep.hasErrors) throw rep.errors;
    return rep.data;
  }

  static Future<ColisStatus?> getColisStatus(String id) async {
    final req = ModelQueries.get(ColisStatus.classType, ColisStatusModelIdentifier(id: id));
    final rep = await Amplify.API.query(request: req).response;
    if (rep.hasErrors) throw rep.errors;
    return rep.data;
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
    final req = ModelMutations.create(inscription);
    final rep = await Amplify.API.mutate(request: req).response;
    safePrint(">>>> createInscription REP = rep=[$rep]");
    if (rep.hasErrors) throw rep.errors;
    return rep.data;
  }

  static Future<Inscription?> deleteInscription(Inscription inscription) async {
    safePrint(">>>> deleteInscription($inscription)");
    final req = ModelMutations.deleteById(Inscription.classType, InscriptionModelIdentifier(id: inscription.id));
    final rep = await Amplify.API.mutate(request: req).response;
    safePrint(">>>> deleteInscription REP = rep=[$rep]");
    if (rep.hasErrors) throw rep.errors;
    return rep.data;
  }

}
