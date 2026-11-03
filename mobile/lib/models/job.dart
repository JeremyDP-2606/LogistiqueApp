import 'package:latlong2/latlong.dart';

class Stop {
  final String address;
  final double lat;
  final double lng;
  final String contactName;
  final String phone;
  final String instructions;

  Stop({required this.address, required this.lat, required this.lng, this.contactName = '', this.phone = '', this.instructions = ''});

  LatLng get latLng => LatLng(lat, lng);

  factory Stop.fromJson(Map<String, dynamic> j) => Stop(
        address: j['address'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        contactName: j['contactName'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        instructions: j['instructions'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'address': address, 'lat': lat, 'lng': lng,
        'contactName': contactName, 'phone': phone, 'instructions': instructions,
      };

  Stop copyWith({String? contactName, String? phone, String? instructions}) => Stop(
        address: address, lat: lat, lng: lng,
        contactName: contactName ?? this.contactName,
        phone: phone ?? this.phone,
        instructions: instructions ?? this.instructions,
      );
}

class CourierInfo {
  final String id;
  final String name;
  final String phone;
  final String vehicle;
  final double rating;
  final LatLng? location;

  CourierInfo({required this.id, required this.name, required this.phone, required this.vehicle, required this.rating, this.location});

  factory CourierInfo.fromJson(Map<String, dynamic> j) => CourierInfo(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        vehicle: j['vehicle'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 5,
        location: parseLatLng(j['location']),
      );

  CourierInfo withLocation(LatLng loc) =>
      CourierInfo(id: id, name: name, phone: phone, vehicle: vehicle, rating: rating, location: loc);
}

LatLng? parseLatLng(dynamic v) {
  if (v is Map && v['lat'] is num && v['lng'] is num) {
    return LatLng((v['lat'] as num).toDouble(), (v['lng'] as num).toDouble());
  }
  return null;
}

class HistoryEntry {
  final String status;
  final DateTime at;
  final String? reason;
  HistoryEntry(this.status, this.at, this.reason);
}

class Job {
  final String id;
  final String ref;
  final String status;
  final Stop pickup;
  final Stop dropoff;
  final String packageSize;
  final String packageDescription;
  final String urgency;
  final String vehicle;
  final double distanceKm;
  final int etaMinutes;
  final double? priceTtc;
  final double courierEarning;
  final String? deliveryCode;
  final CourierInfo? courier;
  final List<HistoryEntry> history;
  final int? ratingStars;
  final double? distanceToPickupKm;
  final DateTime createdAt;

  Job({
    required this.id, required this.ref, required this.status, required this.pickup, required this.dropoff,
    required this.packageSize, required this.packageDescription, required this.urgency, required this.vehicle,
    required this.distanceKm, required this.etaMinutes, required this.priceTtc, required this.courierEarning,
    required this.deliveryCode, required this.courier, required this.history, required this.ratingStars,
    required this.distanceToPickupKm, required this.createdAt, required this.raw,
  });

  /// JSON d'origine, utile pour les fusions.
  final Map<String, dynamic> raw;

  static const activeStatuses = ['pending', 'assigned', 'picking_up', 'picked_up', 'delivering'];
  bool get isActive => activeStatuses.contains(status);

  factory Job.fromJson(Map<String, dynamic> j) => Job(
        id: j['id'] as String,
        ref: j['ref'] as String? ?? '',
        status: j['status'] as String,
        pickup: Stop.fromJson(j['pickup'] as Map<String, dynamic>),
        dropoff: Stop.fromJson(j['dropoff'] as Map<String, dynamic>),
        packageSize: j['packageSize'] as String? ?? 'S',
        packageDescription: j['packageDescription'] as String? ?? '',
        urgency: j['urgency'] as String? ?? 'standard',
        vehicle: j['vehicle'] as String? ?? '',
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        etaMinutes: (j['etaMinutes'] as num?)?.toInt() ?? 0,
        priceTtc: ((j['price'] as Map?)?['ttc'] as num?)?.toDouble(),
        courierEarning: (j['courierEarning'] as num?)?.toDouble() ?? 0,
        deliveryCode: j['deliveryCode'] as String?,
        courier: j['courier'] is Map ? CourierInfo.fromJson(Map<String, dynamic>.from(j['courier'] as Map)) : null,
        history: ((j['history'] as List?) ?? [])
            .map((h) => HistoryEntry(h['status'] as String, DateTime.parse(h['at'] as String).toLocal(), h['reason'] as String?))
            .toList(),
        ratingStars: ((j['rating'] as Map?)?['stars'] as num?)?.toInt(),
        distanceToPickupKm: (j['distanceToPickupKm'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        raw: j,
      );

  /// Fusionne une mise à jour temps réel en conservant le code de remise déjà connu
  /// (le serveur ne le renvoie pas dans les diffusions).
  Job merge(Job update) => Job.fromJson({...update.raw, 'deliveryCode': update.deliveryCode ?? deliveryCode});

  Job withCourierLocation(LatLng loc) {
    if (courier == null) return this;
    final c = Map<String, dynamic>.from(raw['courier'] as Map);
    c['location'] = {'lat': loc.latitude, 'lng': loc.longitude};
    return Job.fromJson({...raw, 'courier': c, 'deliveryCode': deliveryCode});
  }
}
