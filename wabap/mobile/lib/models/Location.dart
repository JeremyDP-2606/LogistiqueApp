// Modèle Location (API Wabap). Classe Dart sans dépendance : même interface que l'ancien modèle généré par Amplify.
// Champs : voir backend/schema/schema.graphql (type du même nom).
// ignore_for_file: file_names

import 'json_helpers.dart';
import 'ModelProvider.dart';


class Location {
  static const classType = ModelType<Location>('Location');
  final String id;
  final String? _owner;
  final String? _userId;
  final String? _userName;
  final String? _tourneeId;
  final double? _latitude;
  final double? _longitude;
  final TemporalDateTime? _lastUpdate;
  final TemporalDateTime? _createdAt;
  final TemporalDateTime? _updatedAt;

  LocationModelIdentifier get modelIdentifier => LocationModelIdentifier(id: id);
  String getId() => id;
  String? get owner => _owner;
  String get userId => requireField(_userId, 'Location.userId');
  String? get userName => _userName;
  String get tourneeId => requireField(_tourneeId, 'Location.tourneeId');
  double get latitude => requireField(_latitude, 'Location.latitude');
  double get longitude => requireField(_longitude, 'Location.longitude');
  TemporalDateTime get lastUpdate => requireField(_lastUpdate, 'Location.lastUpdate');
  TemporalDateTime? get createdAt => _createdAt;
  TemporalDateTime? get updatedAt => _updatedAt;

  const Location._internal({required this.id, String? owner, String? userId, String? userName, String? tourneeId, double? latitude, double? longitude, TemporalDateTime? lastUpdate, TemporalDateTime? createdAt, TemporalDateTime? updatedAt}) : _owner = owner, _userId = userId, _userName = userName, _tourneeId = tourneeId, _latitude = latitude, _longitude = longitude, _lastUpdate = lastUpdate, _createdAt = createdAt, _updatedAt = updatedAt;

  factory Location({String? id, String? owner, required String userId, String? userName, required String tourneeId, required double latitude, required double longitude, required TemporalDateTime lastUpdate}) {
    return Location._internal(
        id: id ?? newId(),
        owner: owner,
        userId: userId,
        userName: userName,
        tourneeId: tourneeId,
        latitude: latitude,
        longitude: longitude,
        lastUpdate: lastUpdate,
    );
  }

  Location copyWith({String? owner, String? userId, String? userName, String? tourneeId, double? latitude, double? longitude, TemporalDateTime? lastUpdate}) {
    return Location._internal(
        id: id,
        owner: owner ?? _owner,
        userId: userId ?? _userId,
        userName: userName ?? _userName,
        tourneeId: tourneeId ?? _tourneeId,
        latitude: latitude ?? _latitude,
        longitude: longitude ?? _longitude,
        lastUpdate: lastUpdate ?? _lastUpdate,
        createdAt: _createdAt,
        updatedAt: _updatedAt);
  }

  Location.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        _owner = json['owner'] as String?,
        _userId = json['userId'] as String?,
        _userName = json['userName'] as String?,
        _tourneeId = json['tourneeId'] as String?,
        _latitude = (json['latitude'] as num?)?.toDouble(),
        _longitude = (json['longitude'] as num?)?.toDouble(),
        _lastUpdate = json['lastUpdate'] != null ? TemporalDateTime.fromString(json['lastUpdate']) : null,
        _createdAt = json['createdAt'] != null ? TemporalDateTime.fromString(json['createdAt']) : null,
        _updatedAt = json['updatedAt'] != null ? TemporalDateTime.fromString(json['updatedAt']) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': _owner,
        'userId': _userId,
        'userName': _userName,
        'tourneeId': _tourneeId,
        'latitude': _latitude,
        'longitude': _longitude,
        'lastUpdate': _lastUpdate?.format(),
        'createdAt': _createdAt?.format(),
        'updatedAt': _updatedAt?.format(),
      };

  /// Champs envoyés aux mutations createX / updateX (relations remplacées par leurs clés étrangères).
  Map<String, dynamic> toInput() => withoutNulls({
        'id': id,
        'owner': _owner,
        'userId': _userId,
        'userName': _userName,
        'tourneeId': _tourneeId,
        'latitude': _latitude,
        'longitude': _longitude,
        'lastUpdate': _lastUpdate?.format(),
      });

  @override
  bool operator ==(Object other) => identical(other, this) || other is Location && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() => 'Location {id=$id, ' 'owner=$_owner, userId=$_userId, userName=$_userName, tourneeId=$_tourneeId, latitude=$_latitude, longitude=$_longitude, lastUpdate=$_lastUpdate}';
}

class LocationModelIdentifier {
  final String id;
  const LocationModelIdentifier({required this.id});
  Map<String, dynamic> serializeAsMap() => {'id': id};
}
