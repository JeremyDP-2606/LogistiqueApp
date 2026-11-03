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


/** This is an auto generated class representing the Subscriber type in your schema. */
class Subscriber extends amplify_core.Model {
  static const classType = const _SubscriberModelType();
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
  final amplify_core.TemporalDateTime? _createdAt;
  final amplify_core.TemporalDateTime? _updatedAt;

  @override
  getInstanceType() => classType;
  
  @Deprecated('[getId] is being deprecated in favor of custom primary key feature. Use getter [modelIdentifier] to get model identifier.')
  @override
  String getId() => id;
  
  SubscriberModelIdentifier get modelIdentifier {
      return SubscriberModelIdentifier(
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
  
  String? get address {
    return _address;
  }
  
  String? get numabo {
    return _numabo;
  }
  
  String? get secteur {
    return _secteur;
  }
  
  String? get phone1 {
    return _phone1;
  }
  
  String? get phone2 {
    return _phone2;
  }
  
  String? get instructions {
    return _instructions;
  }
  
  double? get longitude {
    return _longitude;
  }
  
  double? get latitude {
    return _latitude;
  }
  
  Mission? get mission {
    return _mission;
  }
  
  List<Colis>? get colis {
    return _colis;
  }
  
  String get type {
    try {
      return _type!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  int get nb {
    try {
      return _nb!;
    } catch(e) {
      throw amplify_core.AmplifyCodeGenModelException(
          amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastExceptionMessage,
          recoverySuggestion:
            amplify_core.AmplifyExceptionMessages.codeGenRequiredFieldForceCastRecoverySuggestion,
          underlyingException: e.toString()
          );
    }
  }
  
  bool? get unsubscribed {
    return _unsubscribed;
  }
  
  amplify_core.TemporalDateTime? get createdAt {
    return _createdAt;
  }
  
  amplify_core.TemporalDateTime? get updatedAt {
    return _updatedAt;
  }
  
  const Subscriber._internal({required this.id, required owner, required name, address, numabo, secteur, phone1, phone2, instructions, longitude, latitude, mission, colis, required type, required nb, unsubscribed, createdAt, updatedAt}): _owner = owner, _name = name, _address = address, _numabo = numabo, _secteur = secteur, _phone1 = phone1, _phone2 = phone2, _instructions = instructions, _longitude = longitude, _latitude = latitude, _mission = mission, _colis = colis, _type = type, _nb = nb, _unsubscribed = unsubscribed, _createdAt = createdAt, _updatedAt = updatedAt;
  
  factory Subscriber({String? id, required String owner, required String name, String? address, String? numabo, String? secteur, String? phone1, String? phone2, String? instructions, double? longitude, double? latitude, Mission? mission, List<Colis>? colis, required String type, required int nb, bool? unsubscribed}) {
    return Subscriber._internal(
      id: id == null ? amplify_core.UUID.getUUID() : id,
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
      colis: colis != null ? List<Colis>.unmodifiable(colis) : colis,
      type: type,
      nb: nb,
      unsubscribed: unsubscribed);
  }
  
  bool equals(Object other) {
    return this == other;
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Subscriber &&
      id == other.id &&
      _owner == other._owner &&
      _name == other._name &&
      _address == other._address &&
      _numabo == other._numabo &&
      _secteur == other._secteur &&
      _phone1 == other._phone1 &&
      _phone2 == other._phone2 &&
      _instructions == other._instructions &&
      _longitude == other._longitude &&
      _latitude == other._latitude &&
      _mission == other._mission &&
      DeepCollectionEquality().equals(_colis, other._colis) &&
      _type == other._type &&
      _nb == other._nb &&
      _unsubscribed == other._unsubscribed;
  }
  
  @override
  int get hashCode => toString().hashCode;
  
  @override
  String toString() {
    var buffer = new StringBuffer();
    
    buffer.write("Subscriber {");
    buffer.write("id=" + "$id" + ", ");
    buffer.write("owner=" + "$_owner" + ", ");
    buffer.write("name=" + "$_name" + ", ");
    buffer.write("address=" + "$_address" + ", ");
    buffer.write("numabo=" + "$_numabo" + ", ");
    buffer.write("secteur=" + "$_secteur" + ", ");
    buffer.write("phone1=" + "$_phone1" + ", ");
    buffer.write("phone2=" + "$_phone2" + ", ");
    buffer.write("instructions=" + "$_instructions" + ", ");
    buffer.write("longitude=" + (_longitude != null ? _longitude!.toString() : "null") + ", ");
    buffer.write("latitude=" + (_latitude != null ? _latitude!.toString() : "null") + ", ");
    buffer.write("mission=" + (_mission != null ? _mission!.toString() : "null") + ", ");
    buffer.write("type=" + "$_type" + ", ");
    buffer.write("nb=" + (_nb != null ? _nb!.toString() : "null") + ", ");
    buffer.write("unsubscribed=" + (_unsubscribed != null ? _unsubscribed!.toString() : "null") + ", ");
    buffer.write("createdAt=" + (_createdAt != null ? _createdAt!.format() : "null") + ", ");
    buffer.write("updatedAt=" + (_updatedAt != null ? _updatedAt!.format() : "null"));
    buffer.write("}");
    
    return buffer.toString();
  }
  
  Subscriber copyWith({String? owner, String? name, String? address, String? numabo, String? secteur, String? phone1, String? phone2, String? instructions, double? longitude, double? latitude, Mission? mission, List<Colis>? colis, String? type, int? nb, bool? unsubscribed}) {
    return Subscriber._internal(
      id: id,
      owner: owner ?? this.owner,
      name: name ?? this.name,
      address: address ?? this.address,
      numabo: numabo ?? this.numabo,
      secteur: secteur ?? this.secteur,
      phone1: phone1 ?? this.phone1,
      phone2: phone2 ?? this.phone2,
      instructions: instructions ?? this.instructions,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
      mission: mission ?? this.mission,
      colis: colis ?? this.colis,
      type: type ?? this.type,
      nb: nb ?? this.nb,
      unsubscribed: unsubscribed ?? this.unsubscribed);
  }
  
  Subscriber copyWithModelFieldValues({
    ModelFieldValue<String>? owner,
    ModelFieldValue<String>? name,
    ModelFieldValue<String?>? address,
    ModelFieldValue<String?>? numabo,
    ModelFieldValue<String?>? secteur,
    ModelFieldValue<String?>? phone1,
    ModelFieldValue<String?>? phone2,
    ModelFieldValue<String?>? instructions,
    ModelFieldValue<double?>? longitude,
    ModelFieldValue<double?>? latitude,
    ModelFieldValue<Mission?>? mission,
    ModelFieldValue<List<Colis>?>? colis,
    ModelFieldValue<String>? type,
    ModelFieldValue<int>? nb,
    ModelFieldValue<bool?>? unsubscribed
  }) {
    return Subscriber._internal(
      id: id,
      owner: owner == null ? this.owner : owner.value,
      name: name == null ? this.name : name.value,
      address: address == null ? this.address : address.value,
      numabo: numabo == null ? this.numabo : numabo.value,
      secteur: secteur == null ? this.secteur : secteur.value,
      phone1: phone1 == null ? this.phone1 : phone1.value,
      phone2: phone2 == null ? this.phone2 : phone2.value,
      instructions: instructions == null ? this.instructions : instructions.value,
      longitude: longitude == null ? this.longitude : longitude.value,
      latitude: latitude == null ? this.latitude : latitude.value,
      mission: mission == null ? this.mission : mission.value,
      colis: colis == null ? this.colis : colis.value,
      type: type == null ? this.type : type.value,
      nb: nb == null ? this.nb : nb.value,
      unsubscribed: unsubscribed == null ? this.unsubscribed : unsubscribed.value
    );
  }
  
  Subscriber.fromJson(Map<String, dynamic> json)  
    : id = json['id'],
      _owner = json['owner'],
      _name = json['name'],
      _address = json['address'],
      _numabo = json['numabo'],
      _secteur = json['secteur'],
      _phone1 = json['phone1'],
      _phone2 = json['phone2'],
      _instructions = json['instructions'],
      _longitude = (json['longitude'] as num?)?.toDouble(),
      _latitude = (json['latitude'] as num?)?.toDouble(),
      _mission = json['mission']?['serializedData'] != null
        ? Mission.fromJson(new Map<String, dynamic>.from(json['mission']['serializedData']))
        : null,
      _colis = json['colis'] is List
        ? (json['colis'] as List)
          .where((e) => e?['serializedData'] != null)
          .map((e) => Colis.fromJson(new Map<String, dynamic>.from(e['serializedData'])))
          .toList()
        : null,
      _type = json['type'],
      _nb = (json['nb'] as num?)?.toInt(),
      _unsubscribed = json['unsubscribed'],
      _createdAt = json['createdAt'] != null ? amplify_core.TemporalDateTime.fromString(json['createdAt']) : null,
      _updatedAt = json['updatedAt'] != null ? amplify_core.TemporalDateTime.fromString(json['updatedAt']) : null;
  
  Map<String, dynamic> toJson() => {
    'id': id, 'owner': _owner, 'name': _name, 'address': _address, 'numabo': _numabo, 'secteur': _secteur, 'phone1': _phone1, 'phone2': _phone2, 'instructions': _instructions, 'longitude': _longitude, 'latitude': _latitude, 'mission': _mission?.toJson(), 'colis': _colis?.map((Colis? e) => e?.toJson()).toList(), 'type': _type, 'nb': _nb, 'unsubscribed': _unsubscribed, 'createdAt': _createdAt?.format(), 'updatedAt': _updatedAt?.format()
  };
  
  Map<String, Object?> toMap() => {
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
    'mission': _mission,
    'colis': _colis,
    'type': _type,
    'nb': _nb,
    'unsubscribed': _unsubscribed,
    'createdAt': _createdAt,
    'updatedAt': _updatedAt
  };

  static final amplify_core.QueryModelIdentifier<SubscriberModelIdentifier> MODEL_IDENTIFIER = amplify_core.QueryModelIdentifier<SubscriberModelIdentifier>();
  static final ID = amplify_core.QueryField(fieldName: "id");
  static final OWNER = amplify_core.QueryField(fieldName: "owner");
  static final NAME = amplify_core.QueryField(fieldName: "name");
  static final ADDRESS = amplify_core.QueryField(fieldName: "address");
  static final NUMABO = amplify_core.QueryField(fieldName: "numabo");
  static final SECTEUR = amplify_core.QueryField(fieldName: "secteur");
  static final PHONE1 = amplify_core.QueryField(fieldName: "phone1");
  static final PHONE2 = amplify_core.QueryField(fieldName: "phone2");
  static final INSTRUCTIONS = amplify_core.QueryField(fieldName: "instructions");
  static final LONGITUDE = amplify_core.QueryField(fieldName: "longitude");
  static final LATITUDE = amplify_core.QueryField(fieldName: "latitude");
  static final MISSION = amplify_core.QueryField(
    fieldName: "mission",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Mission'));
  static final COLIS = amplify_core.QueryField(
    fieldName: "colis",
    fieldType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.model, ofModelName: 'Colis'));
  static final TYPE = amplify_core.QueryField(fieldName: "type");
  static final NB = amplify_core.QueryField(fieldName: "nb");
  static final UNSUBSCRIBED = amplify_core.QueryField(fieldName: "unsubscribed");
  static var schema = amplify_core.Model.defineSchema(define: (amplify_core.ModelSchemaDefinition modelSchemaDefinition) {
    modelSchemaDefinition.name = "Subscriber";
    modelSchemaDefinition.pluralName = "Subscribers";
    
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
      amplify_core.ModelIndex(fields: const ["type", "name"], name: "subscriberOrderName")
    ];
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.id());
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.OWNER,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.NAME,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.ADDRESS,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.NUMABO,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.SECTEUR,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.PHONE1,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.PHONE2,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.INSTRUCTIONS,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.LONGITUDE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.LATITUDE,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.double)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.belongsTo(
      key: Subscriber.MISSION,
      isRequired: false,
      targetNames: ['missionSubscribersId'],
      ofModelName: 'Mission'
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.hasMany(
      key: Subscriber.COLIS,
      isRequired: false,
      ofModelName: 'Colis',
      associatedKey: Colis.SUBSCRIBER
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.TYPE,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.string)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.NB,
      isRequired: true,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.int)
    ));
    
    modelSchemaDefinition.addField(amplify_core.ModelFieldDefinition.field(
      key: Subscriber.UNSUBSCRIBED,
      isRequired: false,
      ofType: amplify_core.ModelFieldType(amplify_core.ModelFieldTypeEnum.bool)
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

class _SubscriberModelType extends amplify_core.ModelType<Subscriber> {
  const _SubscriberModelType();
  
  @override
  Subscriber fromJson(Map<String, dynamic> jsonData) {
    return Subscriber.fromJson(jsonData);
  }
  
  @override
  String modelName() {
    return 'Subscriber';
  }
}

/**
 * This is an auto generated class representing the model identifier
 * of [Subscriber] in your schema.
 */
class SubscriberModelIdentifier implements amplify_core.ModelIdentifier<Subscriber> {
  final String id;

  /** Create an instance of SubscriberModelIdentifier using [id] the primary key. */
  const SubscriberModelIdentifier({
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
  String toString() => 'SubscriberModelIdentifier(id: $id)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    
    return other is SubscriberModelIdentifier &&
      id == other.id;
  }
  
  @override
  int get hashCode =>
    id.hashCode;
}