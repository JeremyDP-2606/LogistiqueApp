// Date et heure ISO 8601 de l'API (remplace TemporalDateTime d'Amplify, même interface).
class TemporalDateTime implements Comparable<TemporalDateTime> {
  final DateTime _utc;

  TemporalDateTime(DateTime dateTime) : _utc = dateTime.toUtc();
  TemporalDateTime.now() : _utc = DateTime.now().toUtc();
  factory TemporalDateTime.fromString(String value) => TemporalDateTime(DateTime.parse(value));

  DateTime getDateTimeInUtc() => _utc;

  /// Format échangé avec l'API : 2026-11-04T10:00:00.000Z
  String format() => _utc.toIso8601String();

  @override
  String toString() => format();

  @override
  bool operator ==(Object other) => other is TemporalDateTime && other._utc == _utc;

  @override
  int get hashCode => _utc.hashCode;

  @override
  int compareTo(TemporalDateTime other) => _utc.compareTo(other._utc);
}
