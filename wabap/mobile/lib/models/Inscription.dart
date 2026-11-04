// Modèle Inscription (API Wabap). Classe Dart sans dépendance : même interface que l'ancien modèle généré par Amplify.
// Champs : voir backend/schema/schema.graphql (type du même nom).
// ignore_for_file: file_names

import 'json_helpers.dart';
import 'ModelProvider.dart';


class Inscription {
  static const classType = ModelType<Inscription>('Inscription');
  final String id;
  final String? _owner;
  final Mission? _mission;
  final String? _livreurID;
  final String? _missionInscriptionsId;
  final TemporalDateTime? _createdAt;
  final TemporalDateTime? _updatedAt;

  InscriptionModelIdentifier get modelIdentifier => InscriptionModelIdentifier(id: id);
  String getId() => id;
  String? get owner => _owner;
  Mission? get mission => _mission;
  String get livreurID => requireField(_livreurID, 'Inscription.livreurID');
  TemporalDateTime? get createdAt => _createdAt;
  TemporalDateTime? get updatedAt => _updatedAt;
  /// Clé étrangère de la relation mission
  String? get missionInscriptionsId => _missionInscriptionsId ?? _mission?.id;

  const Inscription._internal({required this.id, String? owner, Mission? mission, String? livreurID, String? missionInscriptionsId, TemporalDateTime? createdAt, TemporalDateTime? updatedAt}) : _owner = owner, _mission = mission, _livreurID = livreurID, _missionInscriptionsId = missionInscriptionsId, _createdAt = createdAt, _updatedAt = updatedAt;

  factory Inscription({String? id, String? owner, Mission? mission, required String livreurID}) {
    return Inscription._internal(
        id: id ?? newId(),
        owner: owner,
        mission: mission,
        livreurID: livreurID,
    );
  }

  Inscription copyWith({String? owner, Mission? mission, String? livreurID}) {
    return Inscription._internal(
        id: id,
        owner: owner ?? _owner,
        mission: mission ?? _mission,
        livreurID: livreurID ?? _livreurID,
        missionInscriptionsId: mission != null ? mission.id : _missionInscriptionsId,
        createdAt: _createdAt,
        updatedAt: _updatedAt);
  }

  Inscription.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        _owner = json['owner'] as String?,
        _mission = objectOf(json['mission']) != null ? Mission.fromJson(objectOf(json['mission'])!) : null,
        _livreurID = json['livreurID'] as String?,
        _missionInscriptionsId = json['missionInscriptionsId'] as String?,
        _createdAt = json['createdAt'] != null ? TemporalDateTime.fromString(json['createdAt']) : null,
        _updatedAt = json['updatedAt'] != null ? TemporalDateTime.fromString(json['updatedAt']) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': _owner,
        'mission': _mission?.toJson(),
        'livreurID': _livreurID,
        'missionInscriptionsId': missionInscriptionsId,
        'createdAt': _createdAt?.format(),
        'updatedAt': _updatedAt?.format(),
      };

  /// Champs envoyés aux mutations createX / updateX (relations remplacées par leurs clés étrangères).
  Map<String, dynamic> toInput() => withoutNulls({
        'id': id,
        'owner': _owner,
        'livreurID': _livreurID,
        'missionInscriptionsId': missionInscriptionsId,
      });

  @override
  bool operator ==(Object other) => identical(other, this) || other is Inscription && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() => 'Inscription {id=$id, ' 'owner=$_owner, mission=${_mission?.id}, livreurID=$_livreurID}';
}

class InscriptionModelIdentifier {
  final String id;
  const InscriptionModelIdentifier({required this.id});
  Map<String, dynamic> serializeAsMap() => {'id': id};
}
