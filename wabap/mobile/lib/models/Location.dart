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


/** This is an auto generated class representing the Location type in your schema. */
class Location extends amplify_core.Model {
  static const classType = const _LocationModelType();
  final String id;
  final String? _owner;
  final String? _userId;
  final String? _userName;
  final String? _tourneeId;
  final double? _latitude;
  final double? _longitude;
  final amplify_core.TemporalDateTime? _lastUpdate;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  LocationModelIdentifier get modelIdentifier {
      return LocationModelIdentifier(
        id: id
      );
  }
  
  String? get owner {
    return _owner;
  }
  
  String get userId {
    try {
      return _userId!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String? get userName {
    return _userName;
  }
  
  String get tourneeId {
    try {
      return _tourneeId!;
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
  
  amplify_core.TemporalDateTime get lastUpdate {
    try {
      return _lastUpdate!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const Location._internal({required this.id, owner, required userId, userName, required tourneeId, required latitude, required longitude, required lastUpdate, createdAt, updatedAt}): _owner = owner, _userId = userId, _userName = userName, _tourneeId = tourneeId, _latitude = latitude, _longitude = longitude, _lastUpdate = lastUpdate, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory Location({String? id, String? owner, required String userId, String? userName, required String tourneeId, required double latitude, required double longitude, required amplify_core.TemporalDateTime lastUpdate}) {
    return Location._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      owner: owner,
      userId: userId,
      userName: userName,
      tourneeId: tourneeId,
      latitude: latitude,
      longitude: longitude,
      lastUpdate: lastUpdate);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Location &&
      id == other.id &&
      _owner == other._owner &&
      _userId == other._userId &&
      _userName == other._userName &&
      _tourneeId == other._tourneeId &&
      _latitude == other._latitude &&
      _longitude == other._longitude &&
      _lastUpdate == other._lastUpdate;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("Location {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("owner=" + "$_owner" + ", ");
    buffer.write("userId=" + "$_userId" + ", ");
    buffer.write("userName=" + "$_userName" + ", ");
    buffer.write("tourneeId=" + "$_tourneeId" + ", ");
    buffer.write("latitude=" + (_latitude != null ? _latitude!.toString() : "null") + ", ");
    buffer.write("longitude=" + (_longitude != null ? _longitude!.toString() : "null") + ", ");
    buffer.write("lastUpdate=" + (_lastUpdate != null ? _lastUpdate!.format() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  Location copyWith({String? owner, String? userId, String? userName, String? tourneeId, double? latitude, double? longitude, amplify_core.TemporalDateTime? lastUpdate}) {
    return Location._internal(
      id: id,
      owner: owner ?? this.owner,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      tourneeId: tourneeId ?? this.tourneeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastUpdate: lastUpdate ?? this.lastUpdate);
  }
  
  Location copyWithModelFieldValues({
    ModelFieldValue<String?>? owner,
    ModelFieldValue<String>? userId,
    ModelFieldValue<String?>? userName,
    ModelFieldValue<String>? tourneeId,
    ModelFieldValue<double>? latitude,
    ModelFieldValue<double>? longitude,
    ModelFieldValue<amplify_core.TemporalDateTime>? lastUpdate
  }) {
    return Location._internal(
      id: id,
      owner: owner == null ? this.owner : owner.value,
      userId: userId == null ? this.userId : userId.value,
      userName: userName == null ? this.userName : userName.value,
      tourneeId: tourneeId == null ? this.tourneeId : tourneeId.value,
      latitude: latitude == null ? this.latitude : latitude.value,
      longitude: longitude == null ? this.longitude : longitude.value,
      lastUpdate: lastUpdate == null ? this.lastUpdate : lastUpdate.value
    );
  }
  
  Location.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _owner = json['owner'],
      _userId = json['userId'],
      _userName = json['userName'],
      _tourneeId = json['tourneeId'],
      _latitude = (json['latitude'] as num?)?.toDouble(),
      _longitude = (json['longitude'] as num?)?.toDouble(),
      _lastUpdate = json['lastUpdate'] != null ? amplify_core.TemporalDateTime.fromString(json['lastUpdate']) : null,
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'owner': _owner, 'userId': _userId, 'userName': _userName, 'tourneeId': _tourneeId, 'latitude': _latitude, 'longitude': _longitude, 'lastUpdate': _lastUpdate?.format(), 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'owner': _owner,
    'userId': _userId,
    'userName': _userName,
    'tourneeId': _tourneeId,
    'latitude': _latitude,
    'longitude': _longitude,
    'lastUpdate': _lastUpdate,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<LocationModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<LocationModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final OWNER = amplify_core.QueryField(fieldName: "owner");
  static final USERID = amplify_core.QueryField(fieldName: "userId");
  static final USERNAME = amplify_core.QueryField(fieldName: "userName");
  static final TOURNEEID = amplify_core.QueryField(fieldName: "tourneeId");
  static final LATITUDE = amplify_core.QueryField(fieldName: "latitude");
  static final LONGITUDE = amplify_core.QueryField(fieldName: "longitude");
  static final LASTUPDATE = amplify_core.QueryField(fieldName: "lastUpdate");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Location";
    modelSchemaDefinition.pluralName = "Locations";
    
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
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Location.OWNER,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Location.USERID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Location.USERNAME,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Location.TOURNEEID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Location.LATITUDE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Location.LONGITUDE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Location.LASTUPDATE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'createdAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'updatedAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
  });
}

class _LocationModelType extends amplify_core.ModelType<Location> {
  const _LocationModelType();
  
  @override
  Location fromJson(Map<String, dynamic> jsonData) {
    return Location.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'Location';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [Location] in your schema.
 */
class LocationModelIdentifier implements amplify_core.ModelIdentifier<Location> {
  final String id;

  /** Create an instance of LocationModelIdentifier using [id] the primary key. */
  const LocationModelIdentifier({
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
  String toString() => 'LocationModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is LocationModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}