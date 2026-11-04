// Modèle Mission (API Wabap). Classe Dart sans dépendance : même interface que l'ancien modèle généré par Amplify.
// Champs : voir backend/schema/schema.graphql (type du même nom).
// ignore_for_file: file_names

import 'json_helpers.dart';
import 'ModelProvider.dart';


class Mission {
  static const classType = ModelType<Mission>('Mission');
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
  final String? _deliveryChecking;
  final TemporalDateTime? _createdAt;
  final TemporalDateTime? _updatedAt;

  MissionModelIdentifier get modelIdentifier => MissionModelIdentifier(id: id);
  String getId() => id;
  String get owner => requireField(_owner, 'Mission.owner');
  String get name => requireField(_name, 'Mission.name');
  List<Subscriber>? get subscribers => _subscribers;
  String get livreurID => requireField(_livreurID, 'Mission.livreurID');
  List<Inscription>? get inscriptions => _inscriptions;
  String? get startName => _startName;
  double get startLongitude => requireField(_startLongitude, 'Mission.startLongitude');
  double get startLatitude => requireField(_startLatitude, 'Mission.startLatitude');
  List<bool>? get daysOfWeek => _daysOfWeek;
  bool? get generateDayBefore => _generateDayBefore;
  double? get startTime => _startTime;
  String? get startTimeZone => _startTimeZone;
  List<Tournee>? get tournee => _tournee;
  String? get deliveryChecking => _deliveryChecking;
  TemporalDateTime? get createdAt => _createdAt;
  TemporalDateTime? get updatedAt => _updatedAt;

  const Mission._internal({required this.id, String? owner, String? name, List<Subscriber>? subscribers, String? livreurID, List<Inscription>? inscriptions, String? startName, double? startLongitude, double? startLatitude, List<bool>? daysOfWeek, bool? generateDayBefore, double? startTime, String? startTimeZone, List<Tournee>? tournee, String? deliveryChecking, TemporalDateTime? createdAt, TemporalDateTime? updatedAt}) : _owner = owner, _name = name, _subscribers = subscribers, _livreurID = livreurID, _inscriptions = inscriptions, _startName = startName, _startLongitude = startLongitude, _startLatitude = startLatitude, _daysOfWeek = daysOfWeek, _generateDayBefore = generateDayBefore, _startTime = startTime, _startTimeZone = startTimeZone, _tournee = tournee, _deliveryChecking = deliveryChecking, _createdAt = createdAt, _updatedAt = updatedAt;

  factory Mission({String? id, required String owner, required String name, List<Subscriber>? subscribers, required String livreurID, List<Inscription>? inscriptions, String? startName, required double startLongitude, required double startLatitude, List<bool>? daysOfWeek, bool? generateDayBefore, double? startTime, String? startTimeZone, List<Tournee>? tournee, String? deliveryChecking}) {
    return Mission._internal(
        id: id ?? newId(),
        owner: owner,
        name: name,
        subscribers: subscribers != null ? List<Subscriber>.unmodifiable(subscribers) : null,
        livreurID: livreurID,
        inscriptions: inscriptions != null ? List<Inscription>.unmodifiable(inscriptions) : null,
        startName: startName,
        startLongitude: startLongitude,
        startLatitude: startLatitude,
        daysOfWeek: daysOfWeek != null ? List<bool>.unmodifiable(daysOfWeek) : null,
        generateDayBefore: generateDayBefore,
        startTime: startTime,
        startTimeZone: startTimeZone,
        tournee: tournee != null ? List<Tournee>.unmodifiable(tournee) : null,
        deliveryChecking: deliveryChecking,
    );
  }

  Mission copyWith({String? owner, String? name, List<Subscriber>? subscribers, String? livreurID, List<Inscription>? inscriptions, String? startName, double? startLongitude, double? startLatitude, List<bool>? daysOfWeek, bool? generateDayBefore, double? startTime, String? startTimeZone, List<Tournee>? tournee, String? deliveryChecking}) {
    return Mission._internal(
        id: id,
        owner: owner ?? _owner,
        name: name ?? _name,
        subscribers: subscribers ?? _subscribers,
        livreurID: livreurID ?? _livreurID,
        inscriptions: inscriptions ?? _inscriptions,
        startName: startName ?? _startName,
        startLongitude: startLongitude ?? _startLongitude,
        startLatitude: startLatitude ?? _startLatitude,
        daysOfWeek: daysOfWeek ?? _daysOfWeek,
        generateDayBefore: generateDayBefore ?? _generateDayBefore,
        startTime: startTime ?? _startTime,
        startTimeZone: startTimeZone ?? _startTimeZone,
        tournee: tournee ?? _tournee,
        deliveryChecking: deliveryChecking ?? _deliveryChecking,
        createdAt: _createdAt,
        updatedAt: _updatedAt);
  }

  Mission.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        _owner = json['owner'] as String?,
        _name = json['name'] as String?,
        _subscribers = listOf(json['subscribers'])?.map((e) => Subscriber.fromJson(e)).toList(),
        _livreurID = json['livreurID'] as String?,
        _inscriptions = listOf(json['inscriptions'])?.map((e) => Inscription.fromJson(e)).toList(),
        _startName = json['startName'] as String?,
        _startLongitude = (json['startLongitude'] as num?)?.toDouble(),
        _startLatitude = (json['startLatitude'] as num?)?.toDouble(),
        _daysOfWeek = (json['daysOfWeek'] as List?)?.map((e) => e as bool).toList(),
        _generateDayBefore = asBool(json['generateDayBefore']),
        _startTime = (json['startTime'] as num?)?.toDouble(),
        _startTimeZone = json['startTimeZone'] as String?,
        _tournee = listOf(json['tournee'])?.map((e) => Tournee.fromJson(e)).toList(),
        _deliveryChecking = json['deliveryChecking'] as String?,
        _createdAt = json['createdAt'] != null ? TemporalDateTime.fromString(json['createdAt']) : null,
        _updatedAt = json['updatedAt'] != null ? TemporalDateTime.fromString(json['updatedAt']) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner': _owner,
        'name': _name,
        'subscribers': _subscribers?.map((e) => e.toJson()).toList(),
        'livreurID': _livreurID,
        'inscriptions': _inscriptions?.map((e) => e.toJson()).toList(),
        'startName': _startName,
        'startLongitude': _startLongitude,
        'startLatitude': _startLatitude,
        'daysOfWeek': _daysOfWeek,
        'generateDayBefore': _generateDayBefore,
        'startTime': _startTime,
        'startTimeZone': _startTimeZone,
        'tournee': _tournee?.map((e) => e.toJson()).toList(),
        'deliveryChecking': _deliveryChecking,
        'createdAt': _createdAt?.format(),
        'updatedAt': _updatedAt?.format(),
      };

  /// Champs envoyés aux mutations createX / updateX (relations remplacées par leurs clés étrangères).
  Map<String, dynamic> toInput() => withoutNulls({
        'id': id,
        'owner': _owner,
        'name': _name,
        'livreurID': _livreurID,
        'startName': _startName,
        'startLongitude': _startLongitude,
        'startLatitude': _startLatitude,
        'daysOfWeek': _daysOfWeek,
        'generateDayBefore': _generateDayBefore,
        'startTime': _startTime,
        'startTimeZone': _startTimeZone,
        'deliveryChecking': _deliveryChecking,
      });

  @override
  bool operator ==(Object other) => identical(other, this) || other is Mission && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() => 'Mission {id=$id, ' 'owner=$_owner, name=$_name, livreurID=$_livreurID, startName=$_startName, startLongitude=$_startLongitude, startLatitude=$_startLatitude, daysOfWeek=$_daysOfWeek, generateDayBefore=$_generateDayBefore, startTime=$_startTime, startTimeZone=$_startTimeZone, deliveryChecking=$_deliveryChecking}';
}

class MissionModelIdentifier {
  final String id;
  const MissionModelIdentifier({required this.id});
  Map<String, dynamic> serializeAsMap() => {'id': id};
}
