// Modèles de la plateforme (demandes, suivi, tournées, preuves), lus depuis les réponses GraphQL.
import 'dart:convert';

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
DateTime? _t(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
Map<String, dynamic> _m(dynamic v) => v == null ? {} : Map<String, dynamic>.from((v is String ? jsonDecode(v) : v) as Map);
List<Map<String, dynamic>> _l(dynamic v) => ((v as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

class Place {
  final String formatted;
  final double? latitude;
  final double? longitude;
  final String? name;
  final String? phone;
  final String? instructions;
  const Place({required this.formatted, this.latitude, this.longitude, this.name, this.phone, this.instructions});

  factory Place.fromPoint(Map<String, dynamic> p) {
    final a = _m(p['address']);
    final c = _m(p['contact']);
    return Place(
      formatted: a['formatted'] as String? ?? '',
      latitude: (a['latitude'] as num?)?.toDouble(),
      longitude: (a['longitude'] as num?)?.toDouble(),
      name: c['name'] as String?,
      phone: c['phone'] as String?,
      instructions: p['instructions'] as String?,
    );
  }
}

class OrderSummary {
  final String id;
  final String ref;
  final String status;
  final Place pickup;
  final Place delivery;
  final String size;
  final int? maxDays;
  final double? priceTotal;
  final DateTime createdAt;
  final DateTime? deadlineAt;

  OrderSummary.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        ref = j['ref'] as String? ?? '',
        status = j['status'] as String,
        pickup = Place.fromPoint(_m(j['pickup'])),
        delivery = Place.fromPoint(_m(j['delivery'])),
        size = j['size'] as String? ?? 'S',
        maxDays = (j['maxDays'] as num?)?.toInt(),
        priceTotal = (j['priceTotal'] as num?)?.toDouble(),
        createdAt = _t(j['createdAt'])!,
        deadlineAt = _t(j['deadlineAt']);

  bool get isActive => !['DONE', 'PARTIALLY_FAILED', 'CANCELLED'].contains(status);
  bool get cancellable => ['AWAITING_PAYMENT', 'CREATED', 'TO_FIX', 'PLANNED'].contains(status);
}

class PriceLine {
  final String label;
  final double amount;
  PriceLine(this.label, this.amount);
}

class Quote {
  final double total;
  final double vat;
  final double km;
  final List<PriceLine> lines;
  final DateTime? deadlineAt;
  Quote.fromJson(Map<String, dynamic> j)
      : total = _d(j['total']),
        vat = _d(j['vat']),
        km = _d(j['km']),
        lines = _l(j['lines']).map((l) => PriceLine(l['label'] as String, _d(l['amount']))).toList(),
        deadlineAt = _t(j['deadlineAt']);
}

class TrackingStep {
  final String key;
  final String label;
  final DateTime? at;
  final String? detail;
  TrackingStep(this.key, this.label, this.at, this.detail);
}

class ProofView {
  final String type;
  final DateTime at;
  final String? comment;
  final List<String> photoKeys;
  final String? signerName;
  ProofView(this.type, this.at, this.comment, this.photoKeys, this.signerName);
}

/// Suivi par étapes d'une demande (spec §11)
class Tracking {
  final OrderSummary order;
  final List<TrackingStep> steps;
  final String? currentStep;
  final List<ProofView> proofs;
  final List<PriceLine> priceLines;
  final String? otpCode;

  Tracking.fromJson(Map<String, dynamic> j)
      : order = OrderSummary.fromJson(_m(j['order'])),
        steps = _l(j['steps']).map((s) => TrackingStep(s['key'] as String, s['label'] as String, _t(s['at']), s['detail'] as String?)).toList(),
        currentStep = j['currentStep'] as String?,
        proofs = _l(j['proofs'])
            .map((p) => ProofView(p['type'] as String, _t(p['at'])!, p['comment'] as String?,
                ((p['photoKeys'] as List?) ?? const []).cast<String>(), p['signerName'] as String?))
            .toList(),
        priceLines = _l(_m(j['price'])['lines']).map((l) => PriceLine(l['label'] as String, _d(l['amount']))).toList(),
        otpCode = j['otpCode'] as String?;
}

class TourSummary {
  final String id;
  final String ref;
  final String? name;
  final String date;
  final DateTime startTime;
  final String slot;
  final String status;
  final double estimatedKm;
  final List<String> notices;

  TourSummary.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        ref = j['ref'] as String? ?? '',
        name = j['name'] as String?,
        date = j['date'] as String? ?? '',
        startTime = _t(j['startTime'])!,
        slot = j['slot'] as String? ?? 'DAY',
        status = j['status'] as String,
        estimatedKm = _d(j['estimatedKm']),
        notices = _l(j['notices']).map((n) => n['message'] as String).toList();

  bool get isOpen => ['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS'].contains(status);
}

/// Preuves exigées à un point : une fois pour le point, et le scan colis par colis (spec §5.2)
class Requirements {
  final bool photo;
  final bool signature;
  final bool geoloc;
  final bool otp;
  final Set<String> scanParcelIds;
  Requirements.fromJson(Map<String, dynamic> j)
      : photo = _m(j['perStop'])['photo'] == true,
        signature = _m(j['perStop'])['signature'] == true,
        geoloc = _m(j['perStop'])['geoloc'] == true,
        otp = _m(j['perStop'])['otp'] == true,
        scanParcelIds = ((j['scanParcelIds'] as List?) ?? const []).cast<String>().toSet();

  bool get any => photo || signature || geoloc || otp || scanParcelIds.isNotEmpty;
}

class StopParcel {
  final String id;
  final String code;
  final int? index;
  final int? total;
  final String status;
  StopParcel.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        code = j['code'] as String? ?? '',
        index = (j['index'] as num?)?.toInt(),
        total = (j['total'] as num?)?.toInt(),
        status = j['status'] as String? ?? 'AWAITING_PICKUP';
}

class TourStop {
  final String id;
  final int sequence;
  final String type; // PICKUP | DELIVERY
  final Place place;
  final String status;
  final DateTime? eta;
  final DateTime? deadlineAt;
  final bool hard;
  final List<StopParcel> parcels;
  final Requirements requirements;
  final String? failureReason;

  TourStop.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        sequence = (j['sequence'] as num).toInt(),
        type = j['type'] as String,
        place = Place.fromPoint(j),
        status = j['status'] as String,
        eta = _t(j['eta']),
        deadlineAt = _t(j['deadlineAt']),
        hard = j['hard'] == true,
        parcels = _l(j['parcels']).map(StopParcel.fromJson).toList(),
        requirements = Requirements.fromJson(_m(j['requirements'])),
        failureReason = j['failureReason'] as String?;

  bool get isPickup => type == 'PICKUP';
  bool get todo => status == 'TODO';
}

class CommentPresetItem {
  final String id;
  final String label;
  final String kind;
  final bool clientVisible;
  CommentPresetItem.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        label = j['label'] as String,
        kind = j['kind'] as String,
        clientVisible = j['clientVisible'] == true;
}

/// Vue livreur d'une tournée (points ordonnés, colis, preuves, commentaires)
class CourierTour {
  final TourSummary tour;
  final List<TourStop> stops;
  final List<CommentPresetItem> presets;
  CourierTour.fromJson(Map<String, dynamic> j)
      : tour = TourSummary.fromJson(_m(j['tour'])),
        stops = _l(j['stops']).map(TourStop.fromJson).toList()..sort((a, b) => a.sequence.compareTo(b.sequence)),
        presets = _l(j['presets']).map(CommentPresetItem.fromJson).toList();

  TourStop? get next => stops.where((s) => s.todo).firstOrNull;
  int get doneCount => stops.where((s) => !s.todo).length;
}

class EarningTour {
  final String ref;
  final String date;
  final double km;
  final double amount;
  final String status;
  EarningTour.fromJson(Map<String, dynamic> j)
      : ref = j['ref'] as String? ?? '',
        date = j['date'] as String? ?? '',
        km = _d(j['km']),
        amount = _d(j['amount']),
        status = j['status'] as String? ?? 'TO_VALIDATE';
}

class MyEarnings {
  final double total;
  final double km;
  final String status;
  final List<EarningTour> tours;
  MyEarnings.fromJson(Map<String, dynamic> j)
      : total = _d(j['total']),
        km = _d(j['km']),
        status = j['status'] as String? ?? 'TO_VALIDATE',
        tours = _l(j['tours']).map(EarningTour.fromJson).toList();
}
