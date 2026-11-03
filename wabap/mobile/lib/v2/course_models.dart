// Modèles des courses à la demande (Wabap V2), lus depuis les réponses GraphQL.

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

class CourseStop {
  final String address;
  final double latitude;
  final double longitude;
  final String? contactName;
  final String? phone;
  final String? instructions;

  const CourseStop({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.contactName,
    this.phone,
    this.instructions,
  });

  factory CourseStop.fromJson(Map<String, dynamic> j) => CourseStop(
        address: j['address'] as String? ?? '',
        latitude: _d(j['latitude']),
        longitude: _d(j['longitude']),
        contactName: j['contactName'] as String?,
        phone: j['phone'] as String?,
        instructions: j['instructions'] as String?,
      );

  Map<String, dynamic> toInput() => {
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        if (contactName != null && contactName!.isNotEmpty) 'contactName': contactName,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (instructions != null && instructions!.isNotEmpty) 'instructions': instructions,
      };

  CourseStop copyWith({String? contactName, String? phone, String? instructions}) => CourseStop(
        address: address,
        latitude: latitude,
        longitude: longitude,
        contactName: contactName ?? this.contactName,
        phone: phone ?? this.phone,
        instructions: instructions ?? this.instructions,
      );
}

class CourseEventItem {
  final String status;
  final DateTime at;
  final String? message;
  CourseEventItem(this.status, this.at, this.message);
}

class Course {
  final String id;
  final String ref;
  final String status;
  final String clientId;
  final String? courierId;
  final String? courierName;
  final String? courierPhone;
  final String? courierVehicle;
  final double? courierRating;
  final String area;
  final CourseStop pickup;
  final CourseStop dropoff;
  final String packageSize;
  final String? packageDescription;
  final String urgency;
  final String vehicle;
  final double distanceKm;
  final int? etaMinutes;
  final double priceTtc;
  final double courierEarning;
  final String paymentMode;
  final String? paymentStatus;
  final String? reason;
  final int? ratingStars;
  final double? distanceToPickupKm;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CourseEventItem> events;

  Course({
    required this.id,
    required this.ref,
    required this.status,
    required this.clientId,
    required this.courierId,
    required this.courierName,
    required this.courierPhone,
    required this.courierVehicle,
    required this.courierRating,
    required this.area,
    required this.pickup,
    required this.dropoff,
    required this.packageSize,
    required this.packageDescription,
    required this.urgency,
    required this.vehicle,
    required this.distanceKm,
    required this.etaMinutes,
    required this.priceTtc,
    required this.courierEarning,
    required this.paymentMode,
    required this.paymentStatus,
    required this.reason,
    required this.ratingStars,
    required this.distanceToPickupKm,
    required this.createdAt,
    required this.updatedAt,
    required this.events,
  });

  static const activeStatuses = ['AWAITING_PAYMENT', 'PENDING', 'ASSIGNED', 'PICKING_UP', 'PICKED_UP', 'DELIVERING'];
  bool get isActive => activeStatuses.contains(status);
  bool get clientCanCancel => ['AWAITING_PAYMENT', 'PENDING', 'ASSIGNED', 'PICKING_UP'].contains(status);

  factory Course.fromJson(Map<String, dynamic> j) {
    final items = ((j['events'] as Map?)?['items'] as List?) ?? const [];
    final events = items
        .whereType<Map>()
        .map((e) => CourseEventItem(
              e['status'] as String,
              DateTime.parse(e['createdAt'] as String).toLocal(),
              e['message'] as String?,
            ))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return Course(
      id: j['id'] as String,
      ref: j['ref'] as String? ?? '',
      status: j['status'] as String,
      clientId: j['clientId'] as String? ?? '',
      courierId: j['courierId'] as String?,
      courierName: j['courierName'] as String?,
      courierPhone: j['courierPhone'] as String?,
      courierVehicle: j['courierVehicle'] as String?,
      courierRating: (j['courierRating'] as num?)?.toDouble(),
      area: j['area'] as String? ?? '',
      pickup: CourseStop.fromJson(Map<String, dynamic>.from(j['pickup'] as Map)),
      dropoff: CourseStop.fromJson(Map<String, dynamic>.from(j['dropoff'] as Map)),
      packageSize: j['packageSize'] as String? ?? 'S',
      packageDescription: j['packageDescription'] as String?,
      urgency: j['urgency'] as String? ?? 'STANDARD',
      vehicle: j['vehicle'] as String? ?? 'BIKE',
      distanceKm: _d(j['distanceKm']),
      etaMinutes: (j['etaMinutes'] as num?)?.toInt(),
      priceTtc: _d(j['priceTtc']),
      courierEarning: _d(j['courierEarning']),
      paymentMode: j['paymentMode'] as String? ?? 'CARD',
      paymentStatus: j['paymentStatus'] as String?,
      reason: j['reason'] as String?,
      ratingStars: (j['ratingStars'] as num?)?.toInt(),
      distanceToPickupKm: (j['distanceToPickupKm'] as num?)?.toDouble(),
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse((j['updatedAt'] ?? j['createdAt']) as String).toLocal(),
      events: events,
    );
  }

  /// Applique une mise à jour temps réel (qui ne contient pas l'historique).
  Course mergeUpdate(Course u) => Course(
        id: id, ref: ref, status: u.status, clientId: clientId, courierId: u.courierId,
        courierName: u.courierName, courierPhone: u.courierPhone, courierVehicle: u.courierVehicle,
        courierRating: u.courierRating, area: area, pickup: pickup, dropoff: dropoff,
        packageSize: packageSize, packageDescription: packageDescription, urgency: urgency,
        vehicle: vehicle, distanceKm: distanceKm, etaMinutes: etaMinutes, priceTtc: priceTtc,
        courierEarning: courierEarning, paymentMode: paymentMode, paymentStatus: u.paymentStatus,
        reason: u.reason, ratingStars: u.ratingStars, distanceToPickupKm: distanceToPickupKm,
        createdAt: createdAt, updatedAt: u.updatedAt,
        events: u.status == status ? events : [...events, CourseEventItem(u.status, u.updatedAt, u.reason)],
      );
}

class QuoteOption {
  final String vehicle;
  final int etaMinutes;
  final double priceHt;
  final double priceTva;
  final double priceTtc;

  QuoteOption.fromJson(Map<String, dynamic> j)
      : vehicle = j['vehicle'] as String,
        etaMinutes = (j['etaMinutes'] as num).toInt(),
        priceHt = _d(j['priceHt']),
        priceTva = _d(j['priceTva']),
        priceTtc = _d(j['priceTtc']);
}

class CourseQuote {
  final double distanceKm;
  final List<QuoteOption> options;
  CourseQuote.fromJson(Map<String, dynamic> j)
      : distanceKm = _d(j['distanceKm']),
        options = (j['options'] as List).map((o) => QuoteOption.fromJson(Map<String, dynamic>.from(o as Map))).toList();
}

class CourierProfile {
  final String id;
  final String vehicle;
  final bool online;
  final double rating;
  final String? activeCourseId;

  CourierProfile.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        vehicle = j['vehicle'] as String? ?? 'BIKE',
        online = j['online'] as bool? ?? false,
        rating = _d(j['rating']),
        activeCourseId = j['activeCourseId'] as String?;
}

class EarningsTotal {
  final int count;
  final double amount;
  final double? distanceKm;
  EarningsTotal.fromJson(Map<String, dynamic> j)
      : count = (j['count'] as num).toInt(),
        amount = _d(j['amount']),
        distanceKm = (j['distanceKm'] as num?)?.toDouble();
}

class EarningsLine {
  final String ref;
  final double amount;
  final double distanceKm;
  final DateTime at;
  final String? dropoffAddress;
  EarningsLine.fromJson(Map<String, dynamic> j)
      : ref = j['ref'] as String,
        amount = _d(j['amount']),
        distanceKm = _d(j['distanceKm']),
        at = DateTime.parse(j['at'] as String).toLocal(),
        dropoffAddress = j['dropoffAddress'] as String?;
}

class CourierEarnings {
  final EarningsTotal today;
  final EarningsTotal week;
  final EarningsTotal total;
  final double rating;
  final List<EarningsLine> recent;
  CourierEarnings.fromJson(Map<String, dynamic> j)
      : today = EarningsTotal.fromJson(Map<String, dynamic>.from(j['today'] as Map)),
        week = EarningsTotal.fromJson(Map<String, dynamic>.from(j['week'] as Map)),
        total = EarningsTotal.fromJson(Map<String, dynamic>.from(j['total'] as Map)),
        rating = _d(j['rating']),
        recent = (j['recent'] as List).map((r) => EarningsLine.fromJson(Map<String, dynamic>.from(r as Map))).toList();
}
