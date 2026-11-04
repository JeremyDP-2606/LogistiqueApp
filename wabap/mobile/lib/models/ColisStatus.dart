// Modèle ColisStatus (API Wabap). Classe Dart sans dépendance : même interface que l'ancien modèle généré par Amplify.
// Champs : voir backend/schema/schema.graphql (type du même nom).
// ignore_for_file: file_names

import 'json_helpers.dart';
import 'ModelProvider.dart';


class ColisStatus {
  static const classType = ModelType<ColisStatus>('ColisStatus');
  final String id;
  final String? _owner;
  final Colis? _colis;
  final Status? _status;
  final String? _message;
  final TemporalDateTime? _createdAt;
  final double? _longitude;
  final double? _latitude;
  final String? _colisLogsId;
  final TemporalDateTime? _updatedAt;

  ColisStatusModelIdentifier get modelIdentifier => ColisStatusModelIdentifier(id: id);
  String getId() => id;
  String? get owner => _owner;
  Colis? get colis => _colis;
  Status get status => requireField(_status, 'ColisStatus.status');
  String? get message => _message;
  TemporalDateTime get createdAt => requireField(_createdAt, 'ColisStatus.createdAt');
  double? get longitude => _longitude;
  double? get latitude => _latitude;
  TemporalDateTime? get updatedAt => _updatedAt;
  /// Clé étrangère de la relation colis
  String? get colisLogsId => _colisLogsId ?? _colis?.id;

  const ColisStatus._internal({required this.id, String? owner, Colis? colis, Status? status, String? message, TemporalDateTime? createdAt, double? longitude, double? latitude, String? colisLogsId, TemporalDateTime? updatedAt}) : _owner = owner, _colis = colis, _status = status, _message = message, _createdAt = createdAt, _longitude = longitude, _latitude = latitude, _colisLogsId = colisLogsId, _updatedAt = updatedAt;

  factory ColisStatus({String? id, String? owner, Colis? colis, required Status status, String? message, required TemporalDateTime createdAt, double? longitude, double? latitude}) {
    return ColisStatus._internal(
        id: id ?? newId(),
        owner: owner,
        colis: colis,
        status: status,
        message: message,
        createdAt: createdAt,
        longitude: longitude,
        latitude: latitude,
    );
  }

  ColisStatus copyWith({String? owner, Colis? colis, Status? status, String? message, TemporalDateTime? createdAt, double? longitude, double? latitude}) {
    return ColisStatus._internal(
        id: id,
        owner: owner ?? _owner,
        colis: colis ?? _colis,
        status: status ?? _status,
        message: message ?? _message,
        createdAt: createdAt ?? _createdAt,
        longitude: longitude ?? _longitude,
        latitude: latitude ?? _latitude,
        colisLogsId: colis != null ? colis.id : _colisLogsId,
        updatedAt: _updatedAt);
  }

  ColisStatus.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        _owner = json['owner'] as String?,
        _colis = objectOf(json['colis']) != null ? Colis.fromJson(objectOf(json['colis'])!) : null,
        _status = enumFromString<Status>(json['status'], Status.values),
        _message = json['message'] as String?,
        _createdAt = json['createdAt'] != null ? TemporalDateTime.fromString(json['createdAt']) : null,
        _longitude = (json['longitude'] as num?)?.toDouble(),
        _latitude = (json['latitude'] as num?)?.toDouble(),
        _colisLogsId = json['colisLogsId'] as String?,
        _updatedAt = json['updatedAt'] != null ? TemporalDateTime.fromString(json['updatedAt']) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': _owner,
        'colis': _colis?.toJson(),
        'status': _status?.name,
        'message': _message,
        'createdAt': _createdAt?.format(),
        'longitude': _longitude,
        'latitude': _latitude,
        'colisLogsId': colisLogsId,
        'updatedAt': _updatedAt?.format(),
      };

  /// Champs envoyés aux mutations createX / updateX (relations remplacées par leurs clés étrangères).
  Map<String, dynamic> toInput() => withoutNulls({
        'id': id,
        'owner': _owner,
        'status': _status?.name,
        'message': _message,
        'createdAt': _createdAt?.format(),
        'longitude': _longitude,
        'latitude': _latitude,
        'colisLogsId': colisLogsId,
      });

  @override
  bool operator ==(Object other) => identical(other, this) || other is ColisStatus && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() => 'ColisStatus {id=$id, ' 'owner=$_owner, colis=${_colis?.id}, status=$_status, message=$_message, createdAt=$_createdAt, longitude=$_longitude, latitude=$_latitude}';
}

class ColisStatusModelIdentifier {
  final String id;
  const ColisStatusModelIdentifier({required this.id});
  Map<String, dynamic> serializeAsMap() => {'id': id};
}
