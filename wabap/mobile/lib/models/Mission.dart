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


/** This is an auto generated class representing the Mission type in your schema. */
class Mission extends amplify_core.Model {
  static const classType = const _MissionModelType();
  final String id;
  final String? _owner;
  final String? _name;
  final List<Subscriber>? _subscribers;
  final String? _livreurID;
  final List<Inscription>? _inscriptions;
  final String? _startName;
  final double? _startLongitude;
  final double? _startLatitude;
  final List<bool>? _daysOfWeek;
  final bool? _generateDayBefore;
  final double? _startTime;
  final String? _startTimeZone;
  final List<Tournee>? _tournee;
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  MissionModelIdentifier get modelIdentifier {
      return MissionModelIdentifier(
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
  
  List<Subscriber>? get subscribers {
    return _subscribers;
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
  
  List<Inscription>? get inscriptions {
    return _inscriptions;
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
  
  List<bool>? get daysOfWeek {
    return _daysOfWeek;
  }
  
  bool? get generateDayBefore {
    return _generateDayBefore;
  }
  
  double? get startTime {
    return _startTime;
  }
  
  String? get startTimeZone {
    return _startTimeZone;
  }
  
  List<Tournee>? get tournee {
    return _tournee;
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const Mission._internal({required this.id, required owner, required name, subscribers, required livreurID, inscriptions, startName, required startLongitude, required startLatitude, daysOfWeek, generateDayBefore, startTime, startTimeZone, tournee, createdAt, updatedAt}): _owner = owner, _name = name, _subscribers = subscribers, _livreurID = livreurID, _inscriptions = inscriptions, _startName = startName, _startLongitude = startLongitude, _startLatitude = startLatitude, _daysOfWeek = daysOfWeek, _generateDayBefore = generateDayBefore, _startTime = startTime, _startTimeZone = startTimeZone, _tournee = tournee, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory Mission({String? id, required String owner, required String name, List<Subscriber>? subscribers, required String livreurID, List<Inscription>? inscriptions, String? startName, required double startLongitude, required double startLatitude, List<bool>? daysOfWeek, bool? generateDayBefore, double? startTime, String? startTimeZone, List<Tournee>? tournee}) {
    return Mission._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
      owner: owner,
      name: name,
      subscribers: subscribers != null ? List<Subscriber>.unmodifiable(subscribers) : subscribers,
      livreurID: livreurID,
      inscriptions: inscriptions != null ? List<Inscription>.unmodifiable(inscriptions) : inscriptions,
      startName: startName,
      startLongitude: startLongitude,
      startLatitude: startLatitude,
      daysOfWeek: daysOfWeek != null ? List<bool>.unmodifiable(daysOfWeek) : daysOfWeek,
      generateDayBefore: generateDayBefore,
      startTime: startTime,
      startTimeZone: startTimeZone,
      tournee: tournee != null ? List<Tournee>.unmodifiable(tournee) : tournee);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Mission &&
      id == other.id &&
      _owner == other._owner &&
      _name == other._name &&
      DeepCollectionEquality().equals(_subscribers, other._subscribers) &&
      _livreurID == other._livreurID &&
      DeepCollectionEquality().equals(_inscriptions, other._inscriptions) &&
      _startName == other._startName &&
      _startLongitude == other._startLongitude &&
      _startLatitude == other._startLatitude &&
      DeepCollectionEquality().equals(_daysOfWeek, other._daysOfWeek) &&
      _generateDayBefore == other._generateDayBefore &&
      _startTime == other._startTime &&
      _startTimeZone == other._startTimeZone &&
      DeepCollectionEquality().equals(_tournee, other._tournee);
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("Mission {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("owner=" + "$_owner" + ", ");
    buffer.write("name=" + "$_name" + ", ");
    buffer.write("livreurID=" + "$_livreurID" + ", ");
    buffer.write("startName=" + "$_startName" + ", ");
    buffer.write("startLongitude=" + (_startLongitude != null ? _startLongitude!.toString() : "null") + ", ");
    buffer.write("startLatitude=" + (_startLatitude != null ? _startLatitude!.toString() : "null") + ", ");
    buffer.write("daysOfWeek=" + (_daysOfWeek != null ? _daysOfWeek!.toString() : "null") + ", ");
    buffer.write("generateDayBefore=" + (_generateDayBefore != null ? _generateDayBefore!.toString() : "null") + ", ");
    buffer.write("startTime=" + (_startTime != null ? _startTime!.toString() : "null") + ", ");
    buffer.write("startTimeZone=" + "$_startTimeZone" + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  Mission copyWith({String? owner, String? name, List<Subscriber>? subscribers, String? livreurID, List<Inscription>? inscriptions, String? startName, double? startLongitude, double? startLatitude, List<bool>? daysOfWeek, bool? generateDayBefore, double? startTime, String? startTimeZone, List<Tournee>? tournee}) {
    return Mission._internal(
      id: id,
      owner: owner ?? this.owner,
      name: name ?? this.name,
      subscribers: subscribers ?? this.subscribers,
      livreurID: livreurID ?? this.livreurID,
      inscriptions: inscriptions ?? this.inscriptions,
      startName: startName ?? this.startName,
      startLongitude: startLongitude ?? this.startLongitude,
      startLatitude: startLatitude ?? this.startLatitude,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      generateDayBefore: generateDayBefore ?? this.generateDayBefore,
      startTime: startTime ?? this.startTime,
      startTimeZone: startTimeZone ?? this.startTimeZone,
      tournee: tournee ?? this.tournee);
  }
  
  Mission copyWithModelFieldValues({
    ModelFieldValue<String>? owner,
    ModelFieldValue<String>? name,
    ModelFieldValue<List<Subscriber>?>? subscribers,
    ModelFieldValue<String>? livreurID,
    ModelFieldValue<List<Inscription>?>? inscriptions,
    ModelFieldValue<String?>? startName,
    ModelFieldValue<double>? startLongitude,
    ModelFieldValue<double>? startLatitude,
    ModelFieldValue<List<bool>>? daysOfWeek,
    ModelFieldValue<bool?>? generateDayBefore,
    ModelFieldValue<double?>? startTime,
    ModelFieldValue<String?>? startTimeZone,
    ModelFieldValue<List<Tournee>?>? tournee
  }) {
    return Mission._internal(
      id: id,
      owner: owner == null ? this.owner : owner.value,
      name: name == null ? this.name : name.value,
      subscribers: subscribers == null ? this.subscribers : subscribers.value,
      livreurID: livreurID == null ? this.livreurID : livreurID.value,
      inscriptions: inscriptions == null ? this.inscriptions : inscriptions.value,
      startName: startName == null ? this.startName : startName.value,
      startLongitude: startLongitude == null ? this.startLongitude : startLongitude.value,
      startLatitude: startLatitude == null ? this.startLatitude : startLatitude.value,
      daysOfWeek: daysOfWeek == null ? this.daysOfWeek : daysOfWeek.value,
      generateDayBefore: generateDayBefore == null ? this.generateDayBefore : generateDayBefore.value,
      startTime: startTime == null ? this.startTime : startTime.value,
      startTimeZone: startTimeZone == null ? this.startTimeZone : startTimeZone.value,
      tournee: tournee == null ? this.tournee : tournee.value
    );
  }
  
  Mission.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _owner = json['owner'],
      _name = json['name'],
      _subscribers = json['subscribers'] is List
        ? (json['subscribers'] as List)
          .where((e) => e?['serializedData'] != null)
          .map((e) => Subscriber.fromJson(new Map<String, dynamic>.from(e['serializedData'])))
          .toList()
        : null,
      _livreurID = json['livreurID'],
      _inscriptions = json['inscriptions'] is List
        ? (json['inscriptions'] as List)
          .where((e) => e?['serializedData'] != null)
          .map((e) => Inscription.fromJson(new Map<String, dynamic>.from(e['serializedData'])))
          .toList()
        : null,
      _startName = json['startName'],
      _startLongitude = (json['startLongitude'] as num?)?.toDouble(),
      _startLatitude = (json['startLatitude'] as num?)?.toDouble(),
      _daysOfWeek = json['daysOfWeek']?.cast<bool>(),
      _generateDayBefore = json['generateDayBefore'],
      _startTime = (json['startTime'] as num?)?.toDouble(),
      _startTimeZone = json['startTimeZone'],
      _tournee = json['tournee'] is List
        ? (json['tournee'] as List)
          .where((e) => e?['serializedData'] != null)
          .map((e) => Tournee.fromJson(new Map<String, dynamic>.from(e['serializedData'])))
          .toList()
        : null,
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'owner': _owner, 'name': _name, 'subscribers': _subscribers?.map((Subscriber? e) => e?.toJson()).toList(), 'livreurID': _livreurID, 'inscriptions': _inscriptions?.map((Inscription? e) => e?.toJson()).toList(), 'startName': _startName, 'startLongitude': _startLongitude, 'startLatitude': _startLatitude, 'daysOfWeek': _daysOfWeek, 'generateDayBefore': _generateDayBefore, 'startTime': _startTime, 'startTimeZone': _startTimeZone, 'tournee': _tournee?.map((Tournee? e) => e?.toJson()).toList(), 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
    'id': id,
    'owner': _owner,
    'name': _name,
    'subscribers': _subscribers,
    'livreurID': _livreurID,
    'inscriptions': _inscriptions,
    'startName': _startName,
    'startLongitude': _startLongitude,
    'startLatitude': _startLatitude,
    'daysOfWeek': _daysOfWeek,
    'generateDayBefore': _generateDayBefore,
    'startTime': _startTime,
    'startTimeZone': _startTimeZone,
    'tournee': _tournee,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<MissionModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<MissionModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final OWNER = amplify_core.QueryField(fieldName: "owner");
  static final NAME = amplify_core.QueryField(fieldName: "name");
  static final SUBSCRIBERS = amplify_core.QueryField(
    fieldName: "subscribers",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Subscriber'));
  static final LIVREURID = amplify_core.QueryField(fieldName: "livreurID");
  static final INSCRIPTIONS = amplify_core.QueryField(
    fieldName: "inscriptions",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Inscription'));
  static final STARTNAME = amplify_core.QueryField(fieldName: "startName");
  static final STARTLONGITUDE = amplify_core.QueryField(fieldName: "startLongitude");
  static final STARTLATITUDE = amplify_core.QueryField(fieldName: "startLatitude");
  static final DAYSOFWEEK = amplify_core.QueryField(fieldName: "daysOfWeek");
  static final GENERATEDAYBEFORE = amplify_core.QueryField(fieldName: "generateDayBefore");
  static final STARTTIME = amplify_core.QueryField(fieldName: "startTime");
  static final STARTTIMEZONE = amplify_core.QueryField(fieldName: "startTimeZone");
  static final TOURNEE = amplify_core.QueryField(
    fieldName: "tournee",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Tournee'));
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Mission";
    modelSchemaDefinition.pluralName = "Missions";
    
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
      key: Mission.OWNER,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Mission.NAME,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.hasMany(
      key: Mission.SUBSCRIBERS,
      isRequired: false,
      ofModelName: 'Subscriber',
      associatedKey: Subscriber.MISSION
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Mission.LIVREURID,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.hasMany(
      key: Mission.INSCRIPTIONS,
      isRequired: false,
      ofModelName: 'Inscription',
      associatedKey: Inscription.MISSION
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Mission.STARTNAME,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Mission.STARTLONGITUDE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Mission.STARTLATITUDE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Mission.DAYSOFWEEK,
      isRequired: false,
      isArray: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.collection, ofModelName: amplify_core.ModelFieldTypeEnum.bool.name)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Mission.GENERATEDAYBEFORE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.bool)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Mission.STARTTIME,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Mission.STARTTIMEZONE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.hasMany(
      key: Mission.TOURNEE,
      isRequired: false,
      ofModelName: 'Tournee',
      associatedKey: Tournee.MISSION
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

class _MissionModelType extends amplify_core.ModelType<Mission> {
  const _MissionModelType();
  
  @override
  Mission fromJson(Map<String, dynamic> jsonData) {
    return Mission.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'Mission';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [Mission] in your schema.
 */
class MissionModelIdentifier implements amplify_core.ModelIdentifier<Mission> {
  final String id;

  /** Create an instance of MissionModelIdentifier using [id] the primary key. */
  const MissionModelIdentifier({
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
  String toString() => 'MissionModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is MissionModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}