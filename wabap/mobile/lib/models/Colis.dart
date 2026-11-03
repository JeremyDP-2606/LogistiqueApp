/*
* Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.
*
* Licensed under the Apache License, Version 2.0 (the "License").
* You may not use this file except in compliance with the License.
* A copy of the License is located at
*
*  http://aws.amazon.com/apache2.0
*
* or in the "license" file accompanying this file. This file is distributed
* on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
* express or implied. See the License for the specific language governing
* permissions and limitations under the License.
*/

// NOTE: This file is generated and may not follow lint rules defined in your app
// Generated files can be excluded from analysis in analysis_options.yaml
// For more info, see: https://dart.dev/guides/language/analysis-options#excluding-code-from-analysis

// ignore_for_file: public_member_api_docs, annotate_overrides, dead_code, dead_codepublic_member_api_docs, depend_on_referenced_packages, file_names, library_private_types_in_public_api, no_leading_underscores_for_library_prefixes, no_leading_underscores_for_local_identifiers, non_constant_identifier_names, null_check_on_nullable_type_parameter, prefer_adjacent_string_concatenation, prefer_const_constructors, prefer_if_null_operators, prefer_interpolation_to_compose_strings, slash_for_doc_comments, sort_child_properties_last, unnecessary_const, unnecessary_constructor_name, unnecessary_late, unnecessary_new, unnecessary_null_aware_assignments, unnecessary_nullable_for_final_variable_declarations, unnecessary_string_interpolations, use_build_context_synchronously

import 'ModelProvider.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:collection/collection.dart';


/** This is an auto generated class representing the Colis type in your schema. */
class Colis extends amplify_core.Model {
  static const classType = const _ColisModelType();
  final String id;
  final String? _owner;
  final Tournee? _tournee;
  final Subscriber? _subscriber;
  final amplify_core.TemporalDateTime? _createdAt;
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
  final amplify_core.TemporalDateTime? _updatedAt;
  final String? _colisLastStatusId;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  ColisModelIdentifier get modelIdentifier {
      return ColisModelIdentifier(
        id: id
      );
  }
  
  String? get owner {
    return _owner;
  }
  
  Tournee get tournee {
    try {
      return _tournee!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  Subscriber? get subscriber {
    return _subscriber;
  }
  
  amplify_core.TemporalDateTime get createdAt {
    try {
      return _createdAt!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get position {
    try {
      return _position!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String? get polyline {
    return _polyline;
  }
  
  int? get distance {
    return _distance;
  }
  
  int? get duration {
    return _duration;
  }
  
  String get address {
    try {
      return _address!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  double get longitude {
    try {
      return _longitude!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  double get latitude {
    try {
      return _latitude!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get subscriberName {
    try {
      return _subscriberName!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  ColisStatus get lastStatus {
    try {
      return _lastStatus!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  List<ColisStatus>? get logs {
    return _logs;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  String get colisLastStatusId {
    try {
      return _colisLastStatusId!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  const Colis._internal({required this.id, owner, required tournee, subscriber, required createdAt, required position, polyline, distance, duration, required address, required longitude, required latitude, required subscriberName, required lastStatus, logs, updatedAt, required colisLastStatusId}): _owner = owner, _tournee = tournee, _subscriber = subscriber, _createdAt = createdAt, _position = position, _polyline = polyline, _distance = distance, _duration = duration, _address = address, _longitude = longitude, _latitude = latitude, _subscriberName = subscriberName, _lastStatus = lastStatus, _logs = logs, _updatedAt = updatedAt, _colisLastStatusId = colisLastStatusId;
  
  factory Colis({String? id, String? owner, required Tournee tournee, Subscriber? subscriber, required amplify_core.TemporalDateTime createdAt, required int position, String? polyline, int? distance, int? duration, required String address, required double longitude, required double latitude, required String subscriberName, required ColisStatus lastStatus, List<ColisStatus>? logs, required String colisLastStatusId}) {
    return Colis._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
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
      logs: logs != null ? List<ColisStatus>.unmodifiable(logs) : logs,
      colisLastStatusId: colisLastStatusId);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Colis &&
      id == other.id &&
      _owner == other._owner &&
      _tournee == other._tournee &&
      _subscriber == other._subscriber &&
      _createdAt == other._createdAt &&
      _position == other._position &&
      _polyline == other._polyline &&
      _distance == other._distance &&
      _duration == other._duration &&
      _address == other._address &&
      _longitude == other._longitude &&
      _latitude == other._latitude &&
      _subscriberName == other._subscriberName &&
      _lastStatus == other._lastStatus &&
      DeepCollectionEquality().equals(_logs, other._logs) &&
      _colisLastStatusId == other._colisLastStatusId;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("Colis {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("owner=" + "$_owner" + ", ");
    buffer.write("tournee=" + (_tournee != null ? _tournee!.toString() : "null") + ", ");
    buffer.write("subscriber=" + (_subscriber != null ? _subscriber!.toString() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("position=" + (_position != null ? _position!.toString() : "null") + ", ");
    buffer.write("polyline=" + "$_polyline" + ", ");
    buffer.write("distance=" + (_distance != null ? _distance!.toString() : "null") + ", ");
    buffer.write("duration=" + (_duration != null ? _duration!.toString() : "null") + ", ");
    buffer.write("address=" + "$_address" + ", ");
    buffer.write("longitude=" + (_longitude != null ? _longitude!.toString() : "null") + ", ");
    buffer.write("latitude=" + (_latitude != null ? _latitude!.toString() : "null") + ", ");
    buffer.write("subscriberName=" + "$_subscriberName" + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null") + ", ");
    buffer.write("colisLastStatusId=" + "$_colisLastStatusId");
    buffer.write("}");
    
    return buffer.toString();
  }
  
  Colis copyWith({String? owner, Tournee? tournee, Subscriber? subscriber, amplify_core.TemporalDateTime? createdAt, int? position, String? polyline, int? distance, int? duration, String? address, double? longitude, double? latitude, String? subscriberName, ColisStatus? lastStatus, List<ColisStatus>? logs, String? colisLastStatusId}) {
    return Colis._internal(
      id: id,
      owner: owner ?? this.owner,
      tournee: tournee ?? this.tournee,
      subscriber: subscriber ?? this.subscriber,
      createdAt: createdAt ?? this.createdAt,
      position: position ?? this.position,
      polyline: polyline ?? this.polyline,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      address: address ?? this.address,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      subscriberName: subscriberName ?? this.subscriberName,
      lastStatus: lastStatus ?? this.lastStatus,
      logs: logs ?? this.logs,
      colisLastStatusId: colisLastStatusId ?? this.colisLastStatusId);
  }
  
  Colis copyWithModelFieldValues({
    ModelFieldValue<String?>? owner,
    ModelFieldValue<Tournee>? tournee,
    ModelFieldValue<Subscriber?>? subscriber,
    ModelFieldValue<amplify_core.TemporalDateTime>? createdAt,
    ModelFieldValue<int>? position,
    ModelFieldValue<String?>? polyline,
    ModelFieldValue<int?>? distance,
    ModelFieldValue<int?>? duration,
    ModelFieldValue<String>? address,
    ModelFieldValue<double>? longitude,
    ModelFieldValue<double>? latitude,
    ModelFieldValue<String>? subscriberName,
    ModelFieldValue<ColisStatus>? lastStatus,
    ModelFieldValue<List<ColisStatus>>? logs,
    ModelFieldValue<String>? colisLastStatusId
  }) {
    return Colis._internal(
      id: id,
      owner: owner == null ? this.owner : owner.value,
      tournee: tournee == null ? this.tournee : tournee.value,
      subscriber: subscriber == null ? this.subscriber : subscriber.value,
      createdAt: createdAt == null ? this.createdAt : createdAt.value,
      position: position == null ? this.position : position.value,
      polyline: polyline == null ? this.polyline : polyline.value,
      distance: distance == null ? this.distance : distance.value,
      duration: duration == null ? this.duration : duration.value,
      address: address == null ? this.address : address.value,
      longitude: longitude == null ? this.longitude : longitude.value,
      latitude: latitude == null ? this.latitude : latitude.value,
      subscriberName: subscriberName == null ? this.subscriberName : subscriberName.value,
      lastStatus: lastStatus == null ? this.lastStatus : lastStatus.value,
      logs: logs == null ? this.logs : logs.value,
      colisLastStatusId: colisLastStatusId == null ? this.colisLastStatusId : colisLastStatusId.value
    );
  }
  
  Colis.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _owner = json['owner'],
      _tournee = json['tournee']?['serializedData'] != null
        ? Tournee.fromJson(new Map<String, dynamic>.from(json['tournee']['serializedData']))
        : null,
      _subscriber = json['subscriber']?['serializedData'] != null
        ? Subscriber.fromJson(new Map<String, dynamic>.from(json['subscriber']['serializedData']))
        : null,
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _position = (json['position'] as num?)?.toInt(),
      _polyline = json['polyline'],
      _distance = (json['distance'] as num?)?.toInt(),
      _duration = (json['duration'] as num?)?.toInt(),
      _address = json['address'],
      _longitude = (json['longitude'] as num?)?.toDouble(),
      _latitude = (json['latitude'] as num?)?.toDouble(),
      _subscriberName = json['subscriberName'],
      _lastStatus = json['lastStatus']?['serializedData'] != null
        ? ColisStatus.fromJson(new Map<String, dynamic>.from(json['lastStatus']['serializedData']))
        : null,
      _logs = json['logs'] is List
        ? (json['logs'] as List)
          .where((e) => e?['serializedData'] != null)
          .map((e) => ColisStatus.fromJson(new Map<String, dynamic>.from(e['serializedData'])))
          .toList()
        : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null,
      _colisLastStatusId = json['colisLastStatusId'];
  
  Map<String, dynamic> toJson() => {
    'id': id, 'owner': _owner, 'tournee': _tournee?.toJson(), 'subscriber': _subscriber?.toJson(), 'createdAt': _createdAt?.format(), 'position': _position, 'polyline': _polyline, 'distance': _distance, 'duration': _duration, 'address': _address, 'longitude': _longitude, 'latitude': _latitude, 'subscriberName': _subscriberName, 'lastStatus': _lastStatus?.toJson(), 'logs': _logs?.map((ColisStatus? e) => e?.toJson()).toList(), 'updatedAt': _updatedAt?.format(), 'colisLastStatusId': _colisLastStatusId
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'owner': _owner,
    'tournee': _tournee,
    'subscriber': _subscriber,
    'createdAt': _createdAt,
    'position': _position,
    'polyline': _polyline,
    'distance': _distance,
    'duration': _duration,
    'address': _address,
    'longitude': _longitude,
    'latitude': _latitude,
    'subscriberName': _subscriberName,
    'lastStatus': _lastStatus,
    'logs': _logs,
    'updatedAt': _updatedAt,
    'colisLastStatusId': _colisLastStatusId
  };

  static final amplify_core.QueryModelIdentifier<ColisModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<ColisModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final OWNER = amplify_core.QueryField(fieldName: "owner");
  static final TOURNEE = amplify_core.QueryField(
    fieldName: "tournee",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Tournee'));
  static final SUBSCRIBER = amplify_core.QueryField(
    fieldName: "subscriber",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Subscriber'));
  static final CREATEDAT = amplify_core.QueryField(fieldName: "createdAt");
  static final POSITION = amplify_core.QueryField(fieldName: "position");
  static final POLYLINE = amplify_core.QueryField(fieldName: "polyline");
  static final DISTANCE = amplify_core.QueryField(fieldName: "distance");
  static final DURATION = amplify_core.QueryField(fieldName: "duration");
  static final ADDRESS = amplify_core.QueryField(fieldName: "address");
  static final LONGITUDE = amplify_core.QueryField(fieldName: "longitude");
  static final LATITUDE = amplify_core.QueryField(fieldName: "latitude");
  static final SUBSCRIBERNAME = amplify_core.QueryField(fieldName: "subscriberName");
  static final LASTSTATUS = amplify_core.QueryField(
    fieldName: "lastStatus",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'ColisStatus'));
  static final LOGS = amplify_core.QueryField(
    fieldName: "logs",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'ColisStatus'));
  static final COLISLASTSTATUSID = amplify_core.QueryField(fieldName: "colisLastStatusId");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Colis";
    modelSchemaDefinition.pluralName = "Colis";
    
    modelSchemaDefinition.authRules = [
      amplify_core.AuthRule(
        authStrategy: amplify_core.AuthStrategy.GROUPS,
        groupClaim: "cognito:groups",
        groups: [ "wabap" ],
        provider: amplify_core.AuthRuleProvider.USERPOOLS,
        operations: const [
          amplify_core.ModelOperation.CREATE,
          amplify_core.ModelOperation.UPDATE,
          amplify_core.ModelOperation.DELETE,
          amplify_core.ModelOperation.READ
        ]),
      amplify_core.AuthRule(
        authStrategy: amplify_core.AuthStrategy.OWNER,
        ownerField: "owner",
        identityClaim: "custom:clientName",
        provider: amplify_core.AuthRuleProvider.USERPOOLS,
        operations: const [
          amplify_core.ModelOperation.CREATE,
          amplify_core.ModelOperation.UPDATE,
          amplify_core.ModelOperation.DELETE,
          amplify_core.ModelOperation.READ
        ])
    ];
    
    modelSchemaDefinition.indexes = [
      amplify_core.ModelIndex(fields: const ["tourneeColisId", "position"], name: "byTourneeOrderPosition"),
      amplify_core.ModelIndex(fields: const ["subscriberColisId", "createdAt"], name: "bySubscriberOrderDate")
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Colis.OWNER,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.belongsTo(
      key: Colis.TOURNEE,
      isRequired: true,
      targetNames: ['tourneeColisId'],
      ofModelName: 'Tournee'
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.belongsTo(
      key: Colis.SUBSCRIBER,
      isRequired: false,
      targetNames: ['subscriberColisId'],
      ofModelName: 'Subscriber'
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Colis.CREATEDAT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Colis.POSITION,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Colis.POLYLINE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Colis.DISTANCE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Colis.DURATION,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Colis.ADDRESS,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Colis.LONGITUDE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Colis.LATITUDE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Colis.SUBSCRIBERNAME,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.hasOne(
      key: Colis.LASTSTATUS,
      isRequired: true,
      ofModelName: 'ColisStatus',
      associatedKey: ColisStatus.COLIS
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.hasMany(
      key: Colis.LOGS,
      isRequired: true,
      ofModelName: 'ColisStatus',
      associatedKey: ColisStatus.COLIS
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'updatedAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Colis.COLISLASTSTATUSID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
  });
}

class _ColisModelType extends amplify_core.ModelType<Colis> {
  const _ColisModelType();
  
  @override
  Colis fromJson(Map<String, dynamic> jsonData) {
    return Colis.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'Colis';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [Colis] in your schema.
 */
class ColisModelIdentifier implements amplify_core.ModelIdentifier<Colis> {
  final String id;

  /** Create an instance of ColisModelIdentifier using [id] the primary key. */
  const ColisModelIdentifier({
    required this.id});
  
  @override
  Map<String, dynamic> serializeAsMap() => (<String, dynamic>{
    'id': id
  });
  
  @override
  List<Map<String, dynamic>> serializeAsList() => serializeAsMap()
    .entries
    .map((entry) => (<String, dynamic>{ entry.key: entry.value }))
    .toList();
  
  @override
  String serializeAsString() => serializeAsMap().values.join('#');
  
  @override
  String toString() => 'ColisModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is ColisModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}