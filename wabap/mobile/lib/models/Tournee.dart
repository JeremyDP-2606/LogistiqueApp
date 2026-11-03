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


/** This is an auto generated class representing the Tournee type in your schema. */
class Tournee extends amplify_core.Model {
  static const classType = const _TourneeModelType();
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
  final amplify_core.TemporalDateTime? _createdAt;
  final int? _distance;
  final int? _duree;
  final int? _nbColis;
  final amplify_core.TemporalDateTime? _updatedAt;
  final bool? _deliveryChecking;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  TourneeModelIdentifier get modelIdentifier {
      return TourneeModelIdentifier(
        id: id
      );
  }
  
  String get owner {
    try {
      return _owner!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  String get name {
    try {
      return _name!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
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
  
  List<Colis>? get colis {
    return _colis;
  }
  
  String? get startName {
    return _startName;
  }
  
  double get startLongitude {
    try {
      return _startLongitude!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  double get startLatitude {
    try {
      return _startLatitude!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
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
  
  Mission get mission {
    try {
      return _mission!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
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
  
  int? get distance {
    return _distance;
  }
  
  int? get duree {
    return _duree;
  }
  
  int? get nbColis {
    return _nbColis;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }

  bool? get deliveryChecking {
    return _deliveryChecking;
  }
  
  const Tournee._internal({required this.id, required owner, required name, required status, colis, startName, required startLongitude, required startLatitude, required livreurID, required mission, required createdAt, distance, duree, nbColis, updatedAt,deliveryChecking }): _owner = owner, _name = name, _status = status, _colis = colis, _startName = startName, _startLongitude = startLongitude, _startLatitude = startLatitude, _livreurID = livreurID, _mission = mission, _createdAt = createdAt, _distance = distance, _duree = duree, _nbColis = nbColis, _updatedAt = updatedAt, _deliveryChecking=deliveryChecking;
  
  factory Tournee({String? id, required String owner, required String name, required Status status, List<Colis>? colis, String? startName, required double startLongitude, required double startLatitude, required String livreurID, required Mission mission, required amplify_core.TemporalDateTime createdAt, int? distance, int? duree, int? nbColis, bool? deliveryChecking}) {
    return Tournee._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      owner: owner,
      name: name,
      status: status,
      colis: colis != null ? List<Colis>.unmodifiable(colis) : colis,
      startName: startName,
      startLongitude: startLongitude,
      startLatitude: startLatitude,
      livreurID: livreurID,
      mission: mission,
      createdAt: createdAt,
      distance: distance,
      duree: duree,
      nbColis: nbColis,
      deliveryChecking: deliveryChecking);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Tournee &&
      id == other.id &&
      _owner == other._owner &&
      _name == other._name &&
      _status == other._status &&
      DeepCollectionEquality().equals(_colis, other._colis) &&
      _startName == other._startName &&
      _startLongitude == other._startLongitude &&
      _startLatitude == other._startLatitude &&
      _livreurID == other._livreurID &&
      _mission == other._mission &&
      _createdAt == other._createdAt &&
      _distance == other._distance &&
      _duree == other._duree &&
      _nbColis == other._nbColis &&
      _deliveryChecking == other._deliveryChecking;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("Tournee {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("owner=" + "$_owner" + ", ");
    buffer.write("name=" + "$_name" + ", ");
    buffer.write("status=" + (_status != null ? amplify_core.enumToString(_status)! : "null") + ", ");
    buffer.write("startName=" + "$_startName" + ", ");
    buffer.write("startLongitude=" + (_startLongitude != null ? _startLongitude!.toString() : "null") + ", ");
    buffer.write("startLatitude=" + (_startLatitude != null ? _startLatitude!.toString() : "null") + ", ");
    buffer.write("livreurID=" + "$_livreurID" + ", ");
    buffer.write("mission=" + (_mission != null ? _mission!.toString() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("distance=" + (_distance != null ? _distance!.toString() : "null") + ", ");
    buffer.write("duree=" + (_duree != null ? _duree!.toString() : "null") + ", ");
    buffer.write("nbColis=" + (_nbColis != null ? _nbColis!.toString() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("deliveryChecking=" + (_deliveryChecking != null ? _deliveryChecking!.toString() : "null") + ", ");
    buffer.write("}");
    
    return buffer.toString();
  }
  
  Tournee copyWith({String? owner, String? name, Status? status, List<Colis>? colis, String? startName, double? startLongitude, double? startLatitude, String? livreurID, Mission? mission, amplify_core.TemporalDateTime? createdAt, int? distance, int? duree, int? nbColis, bool? deliveryChecking}) {
    return Tournee._internal(
      id: id,
      owner: owner ?? this.owner,
      name: name ?? this.name,
      status: status ?? this.status,
      colis: colis ?? this.colis,
      startName: startName ?? this.startName,
      startLongitude: startLongitude ?? this.startLongitude,
      startLatitude: startLatitude ?? this.startLatitude,
      livreurID: livreurID ?? this.livreurID,
      mission: mission ?? this.mission,
      createdAt: createdAt ?? this.createdAt,
      distance: distance ?? this.distance,
      duree: duree ?? this.duree,
      nbColis: nbColis ?? this.nbColis,
      deliveryChecking: deliveryChecking ?? this.deliveryChecking);
  }
  
  Tournee copyWithModelFieldValues({
    ModelFieldValue<String>? owner,
    ModelFieldValue<String>? name,
    ModelFieldValue<Status>? status,
    ModelFieldValue<List<Colis>>? colis,
    ModelFieldValue<String?>? startName,
    ModelFieldValue<double>? startLongitude,
    ModelFieldValue<double>? startLatitude,
    ModelFieldValue<String>? livreurID,
    ModelFieldValue<Mission>? mission,
    ModelFieldValue<amplify_core.TemporalDateTime>? createdAt,
    ModelFieldValue<int?>? distance,
    ModelFieldValue<int?>? duree,
    ModelFieldValue<int?>? nbColis,
    ModelFieldValue<bool?>? deliveryChecking
  }) {
    return Tournee._internal(
      id: id,
      owner: owner == null ? this.owner : owner.value,
      name: name == null ? this.name : name.value,
      status: status == null ? this.status : status.value,
      colis: colis == null ? this.colis : colis.value,
      startName: startName == null ? this.startName : startName.value,
      startLongitude: startLongitude == null ? this.startLongitude : startLongitude.value,
      startLatitude: startLatitude == null ? this.startLatitude : startLatitude.value,
      livreurID: livreurID == null ? this.livreurID : livreurID.value,
      mission: mission == null ? this.mission : mission.value,
      createdAt: createdAt == null ? this.createdAt : createdAt.value,
      distance: distance == null ? this.distance : distance.value,
      duree: duree == null ? this.duree : duree.value,
      nbColis: nbColis == null ? this.nbColis : nbColis.value,
      deliveryChecking: deliveryChecking == null ? this.deliveryChecking : deliveryChecking.value
    );
  }
  
  Tournee.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _owner = json['owner'],
      _name = json['name'],
      _status = amplify_core.enumFromString<Status>(json['status'], Status.values),
      _colis = json['colis'] is List
        ? (json['colis'] as List)
          .where((e) => e?['serializedData'] != null)
          .map((e) => Colis.fromJson(new Map<String, dynamic>.from(e['serializedData'])))
          .toList()
        : null,
      _startName = json['startName'],
      _startLongitude = (json['startLongitude'] as num?)?.toDouble(),
      _startLatitude = (json['startLatitude'] as num?)?.toDouble(),
      _livreurID = json['livreurID'],
      _mission = json['mission']?['serializedData'] != null
        ? Mission.fromJson(new Map<String, dynamic>.from(json['mission']['serializedData']))
        : null,
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _distance = (json['distance'] as num?)?.toInt(),
      _duree = (json['duree'] as num?)?.toInt(),
      _nbColis = (json['nbColis'] as num?)?.toInt(),
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null,
      _deliveryChecking = json['deliveryChecking'];
  
  Map<String, dynamic> toJson() => {
    'id': id, 'owner': _owner, 'name': _name, 'status': amplify_core.enumToString(_status), 'colis': _colis?.map((Colis? e) => e?.toJson()).toList(), 'startName': _startName, 'startLongitude': _startLongitude, 'startLatitude': _startLatitude, 'livreurID': _livreurID, 'mission': _mission?.toJson(), 'createdAt': _createdAt?.format(), 'distance': _distance, 'duree': _duree, 'nbColis': _nbColis, 'updatedAt': _updatedAt?.format(), 'deliveryChecking': _deliveryChecking
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'owner': _owner,
    'name': _name,
    'status': _status,
    'colis': _colis,
    'startName': _startName,
    'startLongitude': _startLongitude,
    'startLatitude': _startLatitude,
    'livreurID': _livreurID,
    'mission': _mission,
    'createdAt': _createdAt,
    'distance': _distance,
    'duree': _duree,
    'nbColis': _nbColis,
    'updatedAt': _updatedAt,
    'deliveryChecking': _deliveryChecking
  };

  static final amplify_core.QueryModelIdentifier<TourneeModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<TourneeModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final OWNER = amplify_core.QueryField(fieldName: "owner");
  static final NAME = amplify_core.QueryField(fieldName: "name");
  static final STATUS = amplify_core.QueryField(fieldName: "status");
  static final COLIS = amplify_core.QueryField(
    fieldName: "colis",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Colis'));
  static final STARTNAME = amplify_core.QueryField(fieldName: "startName");
  static final STARTLONGITUDE = amplify_core.QueryField(fieldName: "startLongitude");
  static final STARTLATITUDE = amplify_core.QueryField(fieldName: "startLatitude");
  static final LIVREURID = amplify_core.QueryField(fieldName: "livreurID");
  static final MISSION = amplify_core.QueryField(
    fieldName: "mission",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Mission'));
  static final CREATEDAT = amplify_core.QueryField(fieldName: "createdAt");
  static final DISTANCE = amplify_core.QueryField(fieldName: "distance");
  static final DUREE = amplify_core.QueryField(fieldName: "duree");
  static final NBCOLIS = amplify_core.QueryField(fieldName: "deliveryChecking");
  static final DELIVERYCHECKING = amplify_core.QueryField(fieldName: "");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Tournee";
    modelSchemaDefinition.pluralName = "Tournees";
    
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
          amplify_core.ModelOperation.READ,
          amplify_core.ModelOperation.UPDATE
        ])
    ];
    
    modelSchemaDefinition.indexes = [
      amplify_core.ModelIndex(fields: const ["livreurID", "createdAt"], name: "byLivreurOrderDate"),
      amplify_core.ModelIndex(fields: const ["missionTourneeId", "createdAt"], name: "byMissionOrderDate")
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Tournee.OWNER,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Tournee.NAME,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Tournee.STATUS,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.enumeration)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.hasMany(
      key: Tournee.COLIS,
      isRequired: true,
      ofModelName: 'Colis',
      associatedKey: Colis.TOURNEE
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Tournee.STARTNAME,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Tournee.STARTLONGITUDE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Tournee.STARTLATITUDE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Tournee.LIVREURID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.belongsTo(
      key: Tournee.MISSION,
      isRequired: true,
      targetNames: ['missionTourneeId'],
      ofModelName: 'Mission'
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Tournee.CREATEDAT,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Tournee.DISTANCE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Tournee.DUREE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Tournee.NBCOLIS,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));

    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
        key: Tournee.DELIVERYCHECKING,
        isRequired: false,
        ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.nonQueryField(
      fieldName: 'updatedAt',
      isRequired: false,
      isReadOnly: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.dateTime)
    ));
  });
}

class _TourneeModelType extends amplify_core.ModelType<Tournee> {
  const _TourneeModelType();
  
  @override
  Tournee fromJson(Map<String, dynamic> jsonData) {
    return Tournee.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'Tournee';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [Tournee] in your schema.
 */
class TourneeModelIdentifier implements amplify_core.ModelIdentifier<Tournee> {
  final String id;

  /** Create an instance of TourneeModelIdentifier using [id] the primary key. */
  const TourneeModelIdentifier({
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
  String toString() => 'TourneeModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is TourneeModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}