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


/** This is an auto generated class representing the ColisStatus type in your schema. */
class ColisStatus extends amplify_core.Model {
  static const classType = const _ColisStatusModelType();
  final String id;
  final String? _owner;
  final Colis? _colis;
  final Status? _status;
  final String? _message;
  final amplify_core.TemporalDateTime? _createdAt;
  final double? _longitude;
  final double? _latitude;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  ColisStatusModelIdentifier get modelIdentifier {
      return ColisStatusModelIdentifier(
        id: id
      );
  }
  
  String? get owner {
    return _owner;
  }
  
  Colis? get colis {
    return _colis;
  }
  
  Status get status {
    try {
      return _status!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String? get message {
    return _message;
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
  
  double? get longitude {
    return _longitude;
  }
  
  double? get latitude {
    return _latitude;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const ColisStatus._internal({required this.id, owner, colis, required status, message, required createdAt, longitude, latitude, updatedAt}): _owner = owner, _colis = colis, _status = status, _message = message, _createdAt = createdAt, _longitude = longitude, _latitude = latitude, _updatedAt = updatedAt;
  
  factory ColisStatus({String? id, String? owner, Colis? colis, required Status status, String? message, required amplify_core.TemporalDateTime createdAt, double? longitude, double? latitude}) {
    return ColisStatus._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      owner: owner,
      colis: colis,
      status: status,
      message: message,
      createdAt: createdAt,
      longitude: longitude,
      latitude: latitude);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ColisStatus &&
      id == other.id &&
      _owner == other._owner &&
      _colis == other._colis &&
      _status == other._status &&
      _message == other._message &&
      _createdAt == other._createdAt &&
      _longitude == other._longitude &&
      _latitude == other._latitude;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("ColisStatus {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("owner=" + "$_owner" + ", ");
    buffer.write("colis=" + (_colis != null ? _colis!.toString() : "null") + ", ");
    buffer.write("status=" + (_status != null ? amplify_core.enumToString(_status)! : "null") + ", ");
    buffer.write("message=" + "$_message" + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("longitude=" + (_longitude != null ? _longitude!.toString() : "null") + ", ");
    buffer.write("latitude=" + (_latitude != null ? _latitude!.toString() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  ColisStatus copyWith({String? owner, Colis? colis, Status? status, String? message, amplify_core.TemporalDateTime? createdAt, double? longitude, double? latitude}) {
    return ColisStatus._internal(
      id: id,
      owner: owner ?? this.owner,
      colis: colis ?? this.colis,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude);
  }
  
  ColisStatus copyWithModelFieldValues({
    ModelFieldValue<String?>? owner,
    ModelFieldValue<Colis?>? colis,
    ModelFieldValue<Status>? status,
    ModelFieldValue<String?>? message,
    ModelFieldValue<amplify_core.TemporalDateTime>? createdAt,
    ModelFieldValue<double?>? longitude,
    ModelFieldValue<double?>? latitude
  }) {
    return ColisStatus._internal(
      id: id,
      owner: owner == null ? this.owner : owner.value,
      colis: colis == null ? this.colis : colis.value,
      status: status == null ? this.status : status.value,
      message: message == null ? this.message : message.value,
      createdAt: createdAt == null ? this.createdAt : createdAt.value,
      longitude: longitude == null ? this.longitude : longitude.value,
      latitude: latitude == null ? this.latitude : latitude.value
    );
  }
  
  ColisStatus.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _owner = json['owner'],
      _colis = json['colis']?['serializedData'] != null
        ? Colis.fromJson(new Map<String, dynamic>.from(json['colis']['serializedData']))
        : null,
      _status = amplify_core.enumFromString<Status>(json['status'], Status.values),
      _message = json['message'],
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _longitude = (json['longitude'] as num?)?.toDouble(),
      _latitude = (json['latitude'] as num?)?.toDouble(),
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'owner': _owner, 'colis': _colis?.toJson(), 'status': amplify_core.enumToString(_status), 'message': _message, 'createdAt': _createdAt?.format(), 'longitude': _longitude, 'latitude': _latitude, 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'owner': _owner,
    'colis': _colis,
    'status': _status,
    'message': _message,
    'createdAt': _createdAt,
    'longitude': _longitude,
    'latitude': _latitude,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<ColisStatusModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<ColisStatusModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final OWNER = amplify_core.QueryField(fieldName: "owner");
  static final COLIS = amplify_core.QueryField(
    fieldName: "colis",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Colis'));
  static final STATUS = amplify_core.QueryField(fieldName: "status");
  static final MESSAGE = amplify_core.QueryField(fieldName: "message");
  static final CREATEDAT = amplify_core.QueryField(fieldName: "createdAt");
  static final LONGITUDE = amplify_core.QueryField(fieldName: "longitude");
  static final LATITUDE = amplify_core.QueryField(fieldName: "latitude");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "ColisStatus";
    modelSchemaDefinition.pluralName = "ColisStatuses";
    
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
      amplify_core.ModelIndex(fields: const ["colisLogsId", "createdAt"], name: "byColisOrderDate")
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: ColisStatus.OWNER,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.belongsTo(
      key: ColisStatus.COLIS,
      isRequired: false,
      targetNames: ['colisLogsId'],
      ofModelName: 'Colis'
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: ColisStatus.STATUS,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.enumeration)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: ColisStatus.MESSAGE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: ColisStatus.CREATEDAT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: ColisStatus.LONGITUDE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: ColisStatus.LATITUDE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'updatedAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
  });
}

class _ColisStatusModelType extends amplify_core.ModelType<ColisStatus> {
  const _ColisStatusModelType();
  
  @override
  ColisStatus fromJson(Map<String, dynamic> jsonData) {
    return ColisStatus.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'ColisStatus';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [ColisStatus] in your schema.
 */
class ColisStatusModelIdentifier implements amplify_core.ModelIdentifier<ColisStatus> {
  final String id;

  /** Create an instance of ColisStatusModelIdentifier using [id] the primary key. */
  const ColisStatusModelIdentifier({
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
  String toString() => 'ColisStatusModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is ColisStatusModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}