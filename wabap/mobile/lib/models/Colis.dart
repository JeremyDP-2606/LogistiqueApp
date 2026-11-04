// Modèle Colis (API Wabap). Classe Dart sans dépendance : même interface que l'ancien modèle généré par Amplify.
// Champs : voir backend/schema/schema.graphql (type du même nom).
// ignore_for_file: file_names

import 'json_helpers.dart';
import 'ModelProvider.dart';


class Colis {
  static const classType = ModelType<Colis>('Colis');
  final String id;
  final String? _owner;
  final Tournee? _tournee;
  final Subscriber? _subscriber;
  final TemporalDateTime? _createdAt;
  final int? _position;
  final String? _polyline;
  final int? _distance;
  final int? _duration;
  final String? _address;
  final double? _longitude;
  final double? _latitude;
  final String? _subscriberName;
  final ColisStatus? _lastStatus;
  final List<ColisStatus>? _logs;
  final String? _colisLastStatusId;
  final String? _tourneeColisId;
  final String? _subscriberColisId;
  final TemporalDateTime? _updatedAt;

  ColisModelIdentifier get modelIdentifier => ColisModelIdentifier(id: id);
  String getId() => id;
  String? get owner => _owner;
  Tournee get tournee => requireField(_tournee, 'Colis.tournee');
  Subscriber? get subscriber => _subscriber;
  TemporalDateTime get createdAt => requireField(_createdAt, 'Colis.createdAt');
  int get position => requireField(_position, 'Colis.position');
  String? get polyline => _polyline;
  int? get distance => _distance;
  int? get duration => _duration;
  String get address => requireField(_address, 'Colis.address');
  double get longitude => requireField(_longitude, 'Colis.longitude');
  double get latitude => requireField(_latitude, 'Colis.latitude');
  String get subscriberName => requireField(_subscriberName, 'Colis.subscriberName');
  ColisStatus get lastStatus => requireField(_lastStatus, 'Colis.lastStatus');
  List<ColisStatus>? get logs => _logs;
  String get colisLastStatusId => requireField(_colisLastStatusId, 'Colis.colisLastStatusId');
  TemporalDateTime? get updatedAt => _updatedAt;
  /// Clé étrangère de la relation tournee
  String? get tourneeColisId => _tourneeColisId ?? _tournee?.id;
  /// Clé étrangère de la relation subscriber
  String? get subscriberColisId => _subscriberColisId ?? _subscriber?.id;

  const Colis._internal({required this.id, String? owner, Tournee? tournee, Subscriber? subscriber, TemporalDateTime? createdAt, int? position, String? polyline, int? distance, int? duration, String? address, double? longitude, double? latitude, String? subscriberName, ColisStatus? lastStatus, List<ColisStatus>? logs, String? colisLastStatusId, String? tourneeColisId, String? subscriberColisId, TemporalDateTime? updatedAt}) : _owner = owner, _tournee = tournee, _subscriber = subscriber, _createdAt = createdAt, _position = position, _polyline = polyline, _distance = distance, _duration = duration, _address = address, _longitude = longitude, _latitude = latitude, _subscriberName = subscriberName, _lastStatus = lastStatus, _logs = logs, _colisLastStatusId = colisLastStatusId, _tourneeColisId = tourneeColisId, _subscriberColisId = subscriberColisId, _updatedAt = updatedAt;

  factory Colis({String? id, String? owner, required Tournee tournee, Subscriber? subscriber, required TemporalDateTime createdAt, required int position, String? polyline, int? distance, int? duration, required String address, required double longitude, required double latitude, required String subscriberName, required ColisStatus lastStatus, List<ColisStatus>? logs, required String colisLastStatusId}) {
    return Colis._internal(
        id: id ?? newId(),
        owner: owner,
        tournee: tournee,
        subscriber: subscriber,
        createdAt: createdAt,
        position: position,
        polyline: polyline,
        distance: distance,
        duration: duration,
        address: address,
        longitude: longitude,
        latitude: latitude,
        subscriberName: subscriberName,
        lastStatus: lastStatus,
        logs: logs != null ? List<ColisStatus>.unmodifiable(logs) : null,
        colisLastStatusId: colisLastStatusId,
    );
  }

  Colis copyWith({String? owner, Tournee? tournee, Subscriber? subscriber, TemporalDateTime? createdAt, int? position, String? polyline, int? distance, int? duration, String? address, double? longitude, double? latitude, String? subscriberName, ColisStatus? lastStatus, List<ColisStatus>? logs, String? colisLastStatusId}) {
    return Colis._internal(
        id: id,
        owner: owner ?? _owner,
        tournee: tournee ?? _tournee,
        subscriber: subscriber ?? _subscriber,
        createdAt: createdAt ?? _createdAt,
        position: position ?? _position,
        polyline: polyline ?? _polyline,
        distance: distance ?? _distance,
        duration: duration ?? _duration,
        address: address ?? _address,
        longitude: longitude ?? _longitude,
        latitude: latitude ?? _latitude,
        subscriberName: subscriberName ?? _subscriberName,
        lastStatus: lastStatus ?? _lastStatus,
        logs: logs ?? _logs,
        colisLastStatusId: colisLastStatusId ?? _colisLastStatusId,
        tourneeColisId: tournee != null ? tournee.id : _tourneeColisId,
        subscriberColisId: subscriber != null ? subscriber.id : _subscriberColisId,
        updatedAt: _updatedAt);
  }

  Colis.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        _owner = json['owner'] as String?,
        _tournee = objectOf(json['tournee']) != null ? Tournee.fromJson(objectOf(json['tournee'])!) : null,
        _subscriber = objectOf(json['subscriber']) != null ? Subscriber.fromJson(objectOf(json['subscriber'])!) : null,
        _createdAt = json['createdAt'] != null ? TemporalDateTime.fromString(json['createdAt']) : null,
        _position = (json['position'] as num?)?.toInt(),
        _polyline = json['polyline'] as String?,
        _distance = (json['distance'] as num?)?.toInt(),
        _duration = (json['duration'] as num?)?.toInt(),
        _address = json['address'] as String?,
        _longitude = (json['longitude'] as num?)?.toDouble(),
        _latitude = (json['latitude'] as num?)?.toDouble(),
        _subscriberName = json['subscriberName'] as String?,
        _lastStatus = objectOf(json['lastStatus']) != null ? ColisStatus.fromJson(objectOf(json['lastStatus'])!) : null,
        _logs = listOf(json['logs'])?.map((e) => ColisStatus.fromJson(e)).toList(),
        _colisLastStatusId = json['colisLastStatusId'] as String?,
        _tourneeColisId = json['tourneeColisId'] as String?,
        _subscriberColisId = json['subscriberColisId'] as String?,
        _updatedAt = json['updatedAt'] != null ? TemporalDateTime.fromString(json['updatedAt']) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': _owner,
        'tournee': _tournee?.toJson(),
        'subscriber': _subscriber?.toJson(),
        'createdAt': _createdAt?.format(),
        'position': _position,
        'polyline': _polyline,
        'distance': _distance,
        'duration': _duration,
        'address': _address,
        'longitude': _longitude,
        'latitude': _latitude,
        'subscriberName': _subscriberName,
        'lastStatus': _lastStatus?.toJson(),
        'logs': _logs?.map((e) => e.toJson()).toList(),
        'colisLastStatusId': _colisLastStatusId,
        'tourneeColisId': tourneeColisId,
        'subscriberColisId': subscriberColisId,
        'updatedAt': _updatedAt?.format(),
      };

  /// Champs envoyés aux mutations createX / updateX (relations remplacées par leurs clés étrangères).
  Map<String, dynamic> toInput() => withoutNulls({
        'id': id,
        'owner': _owner,
        'createdAt': _createdAt?.format(),
        'position': _position,
        'polyline': _polyline,
        'distance': _distance,
        'duration': _duration,
        'address': _address,
        'longitude': _longitude,
        'latitude': _latitude,
        'subscriberName': _subscriberName,
        'colisLastStatusId': _colisLastStatusId,
        'tourneeColisId': tourneeColisId,
        'subscriberColisId': subscriberColisId,
      });

  @override
  bool operator ==(Object other) => identical(other, this) || other is Colis && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() => 'Colis {id=$id, ' 'owner=$_owner, tournee=${_tournee?.id}, subscriber=${_subscriber?.id}, createdAt=$_createdAt, position=$_position, polyline=$_polyline, distance=$_distance, duration=$_duration, address=$_address, longitude=$_longitude, latitude=$_latitude, subscriberName=$_subscriberName, lastStatus=${_lastStatus?.id}, colisLastStatusId=$_colisLastStatusId}';
}

class ColisModelIdentifier {
  final String id;
  const ColisModelIdentifier({required this.id});
  Map<String, dynamic> serializeAsMap() => {'id': id};
}
