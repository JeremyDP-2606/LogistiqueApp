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


/** This is an auto generated class representing the Inscription type in your schema. */
class Inscription extends amplify_core.Model {
  static const classType = const _InscriptionModelType();
  final String id;
  final String? _owner;
  final Mission? _mission;
  final String? _livreurID;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  InscriptionModelIdentifier get modelIdentifier {
      return InscriptionModelIdentifier(
        id: id
      );
  }
  
  String? get owner {
    return _owner;
  }
  
  Mission? get mission {
    return _mission;
  }
  
  String get livreurID {
    try {
      return _livreurID!;
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
  
  const Inscription._internal({required this.id, owner, mission, required livreurID, createdAt, updatedAt}): _owner = owner, _mission = mission, _livreurID = livreurID, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory Inscription({String? id, String? owner, Mission? mission, required String livreurID}) {
    return Inscription._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      owner: owner,
      mission: mission,
      livreurID: livreurID);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Inscription &&
      id == other.id &&
      _owner == other._owner &&
      _mission == other._mission &&
      _livreurID == other._livreurID;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("Inscription {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("owner=" + "$_owner" + ", ");
    buffer.write("mission=" + (_mission != null ? _mission!.toString() : "null") + ", ");
    buffer.write("livreurID=" + "$_livreurID" + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  Inscription copyWith({String? owner, Mission? mission, String? livreurID}) {
    return Inscription._internal(
      id: id,
      owner: owner ?? this.owner,
      mission: mission ?? this.mission,
      livreurID: livreurID ?? this.livreurID);
  }
  
  Inscription copyWithModelFieldValues({
    ModelFieldValue<String?>? owner,
    ModelFieldValue<Mission?>? mission,
    ModelFieldValue<String>? livreurID
  }) {
    return Inscription._internal(
      id: id,
      owner: owner == null ? this.owner : owner.value,
      mission: mission == null ? this.mission : mission.value,
      livreurID: livreurID == null ? this.livreurID : livreurID.value
    );
  }
  
  Inscription.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _owner = json['owner'],
      _mission = json['mission']?['serializedData'] != null
        ? Mission.fromJson(new Map<String, dynamic>.from(json['mission']['serializedData']))
        : null,
      _livreurID = json['livreurID'],
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'owner': _owner, 'mission': _mission?.toJson(), 'livreurID': _livreurID, 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'owner': _owner,
    'mission': _mission,
    'livreurID': _livreurID,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<InscriptionModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<InscriptionModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final OWNER = amplify_core.QueryField(fieldName: "owner");
  static final MISSION = amplify_core.QueryField(
    fieldName: "mission",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Mission'));
  static final LIVREURID = amplify_core.QueryField(fieldName: "livreurID");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Inscription";
    modelSchemaDefinition.pluralName = "Inscriptions";
    
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
        ]),
      amplify_core.AuthRule(
        authStrategy: amplify_core.AuthStrategy.OWNER,
        ownerField: "livreurID",
        identityClaim: "sub",
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
      key: Inscription.OWNER,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.belongsTo(
      key: Inscription.MISSION,
      isRequired: false,
      targetNames: ['missionInscriptionsId'],
      ofModelName: 'Mission'
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Inscription.LIVREURID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
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

class _InscriptionModelType extends amplify_core.ModelType<Inscription> {
  const _InscriptionModelType();
  
  @override
  Inscription fromJson(Map<String, dynamic> jsonData) {
    return Inscription.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'Inscription';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [Inscription] in your schema.
 */
class InscriptionModelIdentifier implements amplify_core.ModelIdentifier<Inscription> {
  final String id;

  /** Create an instance of InscriptionModelIdentifier using [id] the primary key. */
  const InscriptionModelIdentifier({
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
  String toString() => 'InscriptionModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is InscriptionModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}