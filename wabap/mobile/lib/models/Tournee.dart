// Modèle Tournee (API Wabap). Classe Dart sans dépendance : même interface que l'ancien modèle généré par Amplify.
// Champs : voir backend/schema/schema.graphql (type du même nom).
// ignore_for_file: file_names

import 'json_helpers.dart';
import 'ModelProvider.dart';


class Tournee {
  static const classType = ModelType<Tournee>('Tournee');
  final String id;
  final String? _owner;
  final String? _name;
  final Status? _status;
  final List<Colis>? _colis;
  final String? _startName;
  final double? _startLongitude;
  final double? _startLatitude;
  final String? _livreurID;
  final Mission? _mission;
  final TemporalDateTime? _createdAt;
  final int? _distance;
  final int? _duree;
  final int? _nbColis;
  final bool? _deliveryChecking;
  final String? _missionTourneeId;
  final TemporalDateTime? _updatedAt;

  TourneeModelIdentifier get modelIdentifier => TourneeModelIdentifier(id: id);
  String getId() => id;
  String get owner => requireField(_owner, 'Tournee.owner');
  String get name => requireField(_name, 'Tournee.name');
  Status get status => requireField(_status, 'Tournee.status');
  List<Colis>? get colis => _colis;
  String? get startName => _startName;
  double get startLongitude => requireField(_startLongitude, 'Tournee.startLongitude');
  double get startLatitude => requireField(_startLatitude, 'Tournee.startLatitude');
  String get livreurID => requireField(_livreurID, 'Tournee.livreurID');
  Mission get mission => requireField(_mission, 'Tournee.mission');
  TemporalDateTime get createdAt => requireField(_createdAt, 'Tournee.createdAt');
  int? get distance => _distance;
  int? get duree => _duree;
  int? get nbColis => _nbColis;
  bool? get deliveryChecking => _deliveryChecking;
  TemporalDateTime? get updatedAt => _updatedAt;
  /// Clé étrangère de la relation mission
  String? get missionTourneeId => _missionTourneeId ?? _mission?.id;

  const Tournee._internal({required this.id, String? owner, String? name, Status? status, List<Colis>? colis, String? startName, double? startLongitude, double? startLatitude, String? livreurID, Mission? mission, TemporalDateTime? createdAt, int? distance, int? duree, int? nbColis, bool? deliveryChecking, String? missionTourneeId, TemporalDateTime? updatedAt}) : _owner = owner, _name = name, _status = status, _colis = colis, _startName = startName, _startLongitude = startLongitude, _startLatitude = startLatitude, _livreurID = livreurID, _mission = mission, _createdAt = createdAt, _distance = distance, _duree = duree, _nbColis = nbColis, _deliveryChecking = deliveryChecking, _missionTourneeId = missionTourneeId, _updatedAt = updatedAt;

  factory Tournee({String? id, required String owner, required String name, required Status status, List<Colis>? colis, String? startName, required double startLongitude, required double startLatitude, required String livreurID, required Mission mission, required TemporalDateTime createdAt, int? distance, int? duree, int? nbColis, bool? deliveryChecking}) {
    return Tournee._internal(
        id: id ?? newId(),
        owner: owner,
        name: name,
        status: status,
        colis: colis != null ? List<Colis>.unmodifiable(colis) : null,
        startName: startName,
        startLongitude: startLongitude,
        startLatitude: startLatitude,
        livreurID: livreurID,
        mission: mission,
        createdAt: createdAt,
        distance: distance,
        duree: duree,
        nbColis: nbColis,
        deliveryChecking: deliveryChecking,
    );
  }

  Tournee copyWith({String? owner, String? name, Status? status, List<Colis>? colis, String? startName, double? startLongitude, double? startLatitude, String? livreurID, Mission? mission, TemporalDateTime? createdAt, int? distance, int? duree, int? nbColis, bool? deliveryChecking}) {
    return Tournee._internal(
        id: id,
        owner: owner ?? _owner,
        name: name ?? _name,
        status: status ?? _status,
        colis: colis ?? _colis,
        startName: startName ?? _startName,
        startLongitude: startLongitude ?? _startLongitude,
        startLatitude: startLatitude ?? _startLatitude,
        livreurID: livreurID ?? _livreurID,
        mission: mission ?? _mission,
        createdAt: createdAt ?? _createdAt,
        distance: distance ?? _distance,
        duree: duree ?? _duree,
        nbColis: nbColis ?? _nbColis,
        deliveryChecking: deliveryChecking ?? _deliveryChecking,
        missionTourneeId: mission != null ? mission.id : _missionTourneeId,
        updatedAt: _updatedAt);
  }

  Tournee.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        _owner = json['owner'] as String?,
        _name = json['name'] as String?,
        _status = enumFromString<Status>(json['status'], Status.values),
        _colis = listOf(json['colis'])?.map((e) => Colis.fromJson(e)).toList(),
        _startName = json['startName'] as String?,
        _startLongitude = (json['startLongitude'] as num?)?.toDouble(),
        _startLatitude = (json['startLatitude'] as num?)?.toDouble(),
        _livreurID = json['livreurID'] as String?,
        _mission = objectOf(json['mission']) != null ? Mission.fromJson(objectOf(json['mission'])!) : null,
        _createdAt = json['createdAt'] != null ? TemporalDateTime.fromString(json['createdAt']) : null,
        _distance = (json['distance'] as num?)?.toInt(),
        _duree = (json['duree'] as num?)?.toInt(),
        _nbColis = (json['nbColis'] as num?)?.toInt(),
        _deliveryChecking = asBool(json['deliveryChecking']),
        _missionTourneeId = json['missionTourneeId'] as String?,
        _updatedAt = json['updatedAt'] != null ? TemporalDateTime.fromString(json['updatedAt']) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': _owner,
        'name': _name,
        'status': _status?.name,
        'colis': _colis?.map((e) => e.toJson()).toList(),
        'startName': _startName,
        'startLongitude': _startLongitude,
        'startLatitude': _startLatitude,
        'livreurID': _livreurID,
        'mission': _mission?.toJson(),
        'createdAt': _createdAt?.format(),
        'distance': _distance,
        'duree': _duree,
        'nbColis': _nbColis,
        'deliveryChecking': _deliveryChecking,
        'missionTourneeId': missionTourneeId,
        'updatedAt': _updatedAt?.format(),
      };

  /// Champs envoyés aux mutations createX / updateX (relations remplacées par leurs clés étrangères).
  Map<String, dynamic> toInput() => withoutNulls({
        'id': id,
        'owner': _owner,
        'name': _name,
        'status': _status?.name,
        'startName': _startName,
        'startLongitude': _startLongitude,
        'startLatitude': _startLatitude,
        'livreurID': _livreurID,
        'createdAt': _createdAt?.format(),
        'distance': _distance,
        'duree': _duree,
        'nbColis': _nbColis,
        'deliveryChecking': _deliveryChecking,
        'missionTourneeId': missionTourneeId,
      });

  @override
  bool operator ==(Object other) => identical(other, this) || other is Tournee && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() => 'Tournee {id=$id, ' 'owner=$_owner, name=$_name, status=$_status, startName=$_startName, startLongitude=$_startLongitude, startLatitude=$_startLatitude, livreurID=$_livreurID, mission=${_mission?.id}, createdAt=$_createdAt, distance=$_distance, duree=$_duree, nbColis=$_nbColis, deliveryChecking=$_deliveryChecking}';
}

class TourneeModelIdentifier {
  final String id;
  const TourneeModelIdentifier({required this.id});
  Map<String, dynamic> serializeAsMap() => {'id': id};
}
