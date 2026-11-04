// Outils partagés par les modèles : lecture du JSON de l'API (objets imbriqués, connexions { items }),
// énumérations, champs obligatoires, identifiants.
// ignore_for_file: file_names
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Nouvel identifiant (UUID v4), comme les identifiants créés par l'API.
String newId() => _uuid.v4();

/// Type d'un modèle (remplace l'ancien « classType » d'Amplify) : nom du modèle dans l'API.
class ModelType<T> {
  final String modelName;
  const ModelType(this.modelName);
}

/// Champ obligatoire du modèle : erreur explicite s'il n'a pas été demandé à l'API.
T requireField<T>(T? value, String name) {
  if (value == null) throw StateError('Champ obligatoire absent : $name (non sélectionné dans la requête ?)');
  return value;
}

/// Objet imbriqué : forme de l'API ({...}) ou ancienne forme locale ({ serializedData: {...} }).
Map<String, dynamic>? objectOf(dynamic v) {
  if (v is! Map) return null;
  final m = Map<String, dynamic>.from(v);
  final inner = m['serializedData'];
  return inner is Map ? Map<String, dynamic>.from(inner) : m;
}

/// Liste d'objets : connexion de l'API ({ items: [...] }) ou liste simple.
List<Map<String, dynamic>>? listOf(dynamic v) {
  if (v is Map && v['items'] is List) v = v['items'];
  if (v is! List) return null;
  return v.map(objectOf).whereType<Map<String, dynamic>>().toList();
}

T? enumFromString<T extends Enum>(dynamic value, List<T> values) {
  if (value == null) return null;
  for (final v in values) {
    if (v.name == value) return v;
  }
  return null;
}

bool? asBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is String) return v == 'true';
  return null;
}

/// Entrée de mutation : les valeurs nulles ne sont pas envoyées (elles effaceraient le champ).
Map<String, dynamic> withoutNulls(Map<String, dynamic> m) => Map.fromEntries(m.entries.where((e) => e.value != null));
