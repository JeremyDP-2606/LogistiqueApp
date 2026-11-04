// Modèle Subscriber (API Wabap). Classe Dart sans dépendance : même interface que l'ancien modèle généré par Amplify.
// Champs : voir backend/schema/schema.graphql (type du même nom).
// ignore_for_file: file_names

import 'json_helpers.dart';
import 'ModelProvider.dart';


class Subscriber {
  static const classType = ModelType<Subscriber>('Subscriber');
  final String id;
  final String? _owner;
  final String? _name;
  final String? _address;
  final String? _numabo;
  final String? _secteur;
  final String? _phone1;
  final String? _phone2;
  final String? _instructions;
  final double? _longitude;
  final double? _latitude;
  final Mission? _mission;
  final List<Colis>? _colis;
  final String? _type;
  final int? _nb;
  final bool? _unsubscribed;
  final String? _missionSubscribersId;
  final TemporalDateTime? _createdAt;
  final TemporalDateTime? _updatedAt;

  SubscriberModelIdentifier get modelIdentifier => SubscriberModelIdentifier(id: id);
  String getId() => id;
  String get owner => requireField(_owner, 'Subscriber.owner');
  String get name => requireField(_name, 'Subscriber.name');
  String? get address => _address;
  String? get numabo => _numabo;
  String? get secteur => _secteur;
  String? get phone1 => _phone1;
  String? get phone2 => _phone2;
  String? get instructions => _instructions;
  double? get longitude => _longitude;
  double? get latitude => _latitude;
  Mission? get mission => _mission;
  List<Colis>? get colis => _colis;
  String get type => requireField(_type, 'Subscriber.type');
  int get nb => requireField(_nb, 'Subscriber.nb');
  bool? get unsubscribed => _unsubscribed;
  TemporalDateTime? get createdAt => _createdAt;
  TemporalDateTime? get updatedAt => _updatedAt;
  /// Clé étrangère de la relation mission
  String? get missionSubscribersId => _missionSubscribersId ?? _mission?.id;

  const Subscriber._internal({required this.id, String? owner, String? name, String? address, String? numabo, String? secteur, String? phone1, String? phone2, String? instructions, double? longitude, double? latitude, Mission? mission, List<Colis>? colis, String? type, int? nb, bool? unsubscribed, String? missionSubscribersId, TemporalDateTime? createdAt, TemporalDateTime? updatedAt}) : _owner = owner, _name = name, _address = address, _numabo = numabo, _secteur = secteur, _phone1 = phone1, _phone2 = phone2, _instructions = instructions, _longitude = longitude, _latitude = latitude, _mission = mission, _colis = colis, _type = type, _nb = nb, _unsubscribed = unsubscribed, _missionSubscribersId = missionSubscribersId, _createdAt = createdAt, _updatedAt = updatedAt;

  factory Subscriber({String? id, required String owner, required String name, String? address, String? numabo, String? secteur, String? phone1, String? phone2, String? instructions, double? longitude, double? latitude, Mission? mission, List<Colis>? colis, required String type, required int nb, bool? unsubscribed}) {
    return Subscriber._internal(
        id: id ?? newId(),
        owner: owner,
        name: name,
        address: address,
        numabo: numabo,
        secteur: secteur,
        phone1: phone1,
        phone2: phone2,
        instructions: instructions,
        longitude: longitude,
        latitude: latitude,
        mission: mission,
        colis: colis != null ? List<Colis>.unmodifiable(colis) : null,
        type: type,
        nb: nb,
        unsubscribed: unsubscribed,
    );
  }

  Subscriber copyWith({String? owner, String? name, String? address, String? numabo, String? secteur, String? phone1, String? phone2, String? instructions, double? longitude, double? latitude, Mission? mission, List<Colis>? colis, String? type, int? nb, bool? unsubscribed}) {
    return Subscriber._internal(
        id: id,
        owner: owner ?? _owner,
        name: name ?? _name,
        address: address ?? _address,
        numabo: numabo ?? _numabo,
        secteur: secteur ?? _secteur,
        phone1: phone1 ?? _phone1,
        phone2: phone2 ?? _phone2,
        instructions: instructions ?? _instructions,
        longitude: longitude ?? _longitude,
        latitude: latitude ?? _latitude,
        mission: mission ?? _mission,
        colis: colis ?? _colis,
        type: type ?? _type,
        nb: nb ?? _nb,
        unsubscribed: unsubscribed ?? _unsubscribed,
        missionSubscribersId: mission != null ? mission.id : _missionSubscribersId,
        createdAt: _createdAt,
        updatedAt: _updatedAt);
  }

  Subscriber.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        _owner = json['owner'] as String?,
        _name = json['name'] as String?,
        _address = json['address'] as String?,
        _numabo = json['numabo'] as String?,
        _secteur = json['secteur'] as String?,
        _phone1 = json['phone1'] as String?,
        _phone2 = json['phone2'] as String?,
        _instructions = json['instructions'] as String?,
        _longitude = (json['longitude'] as num?)?.toDouble(),
        _latitude = (json['latitude'] as num?)?.toDouble(),
        _mission = objectOf(json['mission']) != null ? Mission.fromJson(objectOf(json['mission'])!) : null,
        _colis = listOf(json['colis'])?.map((e) => Colis.fromJson(e)).toList(),
        _type = json['type'] as String?,
        _nb = (json['nb'] as num?)?.toInt(),
        _unsubscribed = asBool(json['unsubscribed']),
        _missionSubscribersId = json['missionSubscribersId'] as String?,
        _createdAt = json['createdAt'] != null ? TemporalDateTime.fromString(json['createdAt']) : null,
        _updatedAt = json['updatedAt'] != null ? TemporalDateTime.fromString(json['updatedAt']) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': _owner,
        'name': _name,
        'address': _address,
        'numabo': _numabo,
        'secteur': _secteur,
        'phone1': _phone1,
        'phone2': _phone2,
        'instructions': _instructions,
        'longitude': _longitude,
        'latitude': _latitude,
        'mission': _mission?.toJson(),
        'colis': _colis?.map((e) => e.toJson()).toList(),
        'type': _type,
        'nb': _nb,
        'unsubscribed': _unsubscribed,
        'missionSubscribersId': missionSubscribersId,
        'createdAt': _createdAt?.format(),
        'updatedAt': _updatedAt?.format(),
      };

  /// Champs envoyés aux mutations createX / updateX (relations remplacées par leurs clés étrangères).
  Map<String, dynamic> toInput() => withoutNulls({
        'id': id,
        'owner': _owner,
        'name': _name,
        'address': _address,
        'numabo': _numabo,
        'secteur': _secteur,
        'phone1': _phone1,
        'phone2': _phone2,
        'instructions': _instructions,
        'longitude': _longitude,
        'latitude': _latitude,
        'type': _type,
        'nb': _nb,
        'unsubscribed': _unsubscribed,
        'missionSubscribersId': missionSubscribersId,
      });

  @override
  bool operator ==(Object other) => identical(other, this) || other is Subscriber && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() => 'Subscriber {id=$id, ' 'owner=$_owner, name=$_name, address=$_address, numabo=$_numabo, secteur=$_secteur, phone1=$_phone1, phone2=$_phone2, instructions=$_instructions, longitude=$_longitude, latitude=$_latitude, mission=${_mission?.id}, type=$_type, nb=$_nb, unsubscribed=$_unsubscribed}';
}

class SubscriberModelIdentifier {
  final String id;
  const SubscriberModelIdentifier({required this.id});
  Map<String, dynamic> serializeAsMap() => {'id': id};
}
