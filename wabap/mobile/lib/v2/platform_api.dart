// Appels GraphQL (AppSync) de la plateforme : courses, suivi, tournées, preuves, gains.
// Toutes les écritures passent par la fonction deliveryApi (voir amplify/backend/function/deliveryApi).
import 'dart:async';
import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';

import 'platform_models.dart';

class PlatformException implements Exception {
  final String message;
  PlatformException(this.message);
  @override
  String toString() => message;
}

const _point = 'address { formatted latitude longitude } contact { name phone } instructions';
const _order = 'id ref status pickup { $_point } delivery { $_point } size maxDays priceTotal createdAt deadlineAt';
const _tour = 'id ref name date startTime slot status estimatedKm notices { at message }';

class PlatformApi {
  static Future<Map<String, dynamic>> _run(String document, Map<String, dynamic> variables, {bool mutation = false}) async {
    final request = GraphQLRequest<String>(document: document, variables: variables);
    final GraphQLResponse<String> response;
    try {
      response = mutation ? await Amplify.API.mutate(request: request).response : await Amplify.API.query(request: request).response;
    } on ApiException catch (e) {
      throw PlatformException('Connexion impossible : ${e.message}');
    }
    if (response.hasErrors) throw PlatformException(response.errors.first.message);
    if (response.data == null) throw PlatformException('Réponse vide du serveur');
    return jsonDecode(response.data!) as Map<String, dynamic>;
  }

  // Les opérations de la fonction renvoient un AWSJSON (chaîne JSON)
  static Map<String, dynamic> _json(dynamic v) => Map<String, dynamic>.from((v is String ? jsonDecode(v) : v) as Map);

  // ---------------- Client ----------------

  static Future<Quote> quote(Map<String, dynamic> input) async {
    final d = await _run(r'query Q($input: AWSJSON!) { quoteCourse(input: $input) }', {'input': jsonEncode(input)});
    return Quote.fromJson(_json(d['quoteCourse']));
  }

  /// Crée la course ; renvoie l'id, le secret de paiement Stripe (null pour un client en compte) et le code de confirmation
  static Future<({String orderId, String? clientSecret, String? otpCode})> createCourse(Map<String, dynamic> input) async {
    final d = await _run(r'mutation C($input: AWSJSON!) { createCourse(input: $input) }', {'input': jsonEncode(input)}, mutation: true);
    final r = _json(d['createCourse']);
    return (orderId: _json(r['order'])['id'] as String, clientSecret: r['paymentClientSecret'] as String?, otpCode: r['otpCode'] as String?);
  }

  static Future<void> confirmPayment(String orderId) async {
    await _run(r'mutation P($orderId: ID!) { confirmCoursePayment(orderId: $orderId) { id status } }', {'orderId': orderId}, mutation: true);
  }

  static Future<void> cancel(String orderId, {String? reason}) async {
    await _run(r'mutation X($orderId: ID!, $reason: String) { cancelOrder(orderId: $orderId, reason: $reason) { id status } }',
        {'orderId': orderId, 'reason': reason}, mutation: true);
  }

  static Future<List<OrderSummary>> myOrders(String customerId) async {
    final d = await _run('query M(\$customerId: String!) { ordersByCustomer(customerId: \$customerId, sortDirection: DESC, limit: 100) { items { $_order } } }',
        {'customerId': customerId});
    return ((d['ordersByCustomer'] as Map)['items'] as List).whereType<Map>().map((o) => OrderSummary.fromJson(Map<String, dynamic>.from(o))).toList();
  }

  static Future<Tracking> tracking(String orderId) async {
    final d = await _run(r'query T($orderId: ID!) { orderTracking(orderId: $orderId) }', {'orderId': orderId});
    return Tracking.fromJson(_json(d['orderTracking']));
  }

  /// Étiquette PDF de la demande (lien temporaire)
  static Future<String> labelUrl(String orderId) async {
    final d = await _run(r'mutation L($orderId: ID) { generateLabels(orderId: $orderId) }', {'orderId': orderId}, mutation: true);
    return _json(d['generateLabels'])['url'] as String;
  }

  // ---------------- Livreur ----------------

  static Future<List<TourSummary>> myTours(String courierId) async {
    final d = await _run('query T(\$courierId: ID!) { toursByCourierIdAndStartTime(courierId: \$courierId, sortDirection: DESC, limit: 60) { items { $_tour } } }',
        {'courierId': courierId});
    return ((d['toursByCourierIdAndStartTime'] as Map)['items'] as List).whereType<Map>().map((t) => TourSummary.fromJson(Map<String, dynamic>.from(t))).toList();
  }

  static Future<CourierTour> tourView(String tourId) async {
    final d = await _run(r'query V($tourId: ID!) { courierTourView(tourId: $tourId) }', {'tourId': tourId});
    return CourierTour.fromJson(_json(d['courierTourView']));
  }

  static Future<void> accept(String tourId) =>
      _run(r'mutation A($tourId: ID!) { acceptTour(tourId: $tourId) { id status } }', {'tourId': tourId}, mutation: true);

  static Future<void> start(String tourId) =>
      _run(r'mutation S($tourId: ID!) { startTour(tourId: $tourId) { id status } }', {'tourId': tourId}, mutation: true);

  static Future<void> close(String tourId) =>
      _run(r'mutation C($tourId: ID!) { closeTour(tourId: $tourId) { id status } }', {'tourId': tourId}, mutation: true);

  /// Vérifie un code scanné (signature, client du point) ; renvoie l'identifiant du colis
  static Future<({String parcelId, bool reserved})> scan(String tourId, String stopId, String code) async {
    final d = await _run(r'mutation S($tourId: ID!, $stopId: ID!, $code: String!) { scanParcel(tourId: $tourId, stopId: $stopId, code: $code) }',
        {'tourId': tourId, 'stopId': stopId, 'code': code}, mutation: true);
    final r = _json(d['scanParcel']);
    return (parcelId: _json(r['parcel'])['id'] as String, reserved: r['reserved'] == true);
  }

  static Future<void> submitStop(Map<String, dynamic> input) =>
      _run(r'mutation S($input: AWSJSON!) { submitStop(input: $input) { id status } }', {'input': jsonEncode(input)}, mutation: true);

  static Future<void> failStop(Map<String, dynamic> input) =>
      _run(r'mutation F($input: AWSJSON!) { failStop(input: $input) { id status } }', {'input': jsonEncode(input)}, mutation: true);

  static Future<void> position(double latitude, double longitude) => _run(
      r'mutation P($latitude: Float!, $longitude: Float!) { updateCourierPosition(latitude: $latitude, longitude: $longitude) { at } }',
      {'latitude': latitude, 'longitude': longitude},
      mutation: true);

  static Future<MyEarnings> earnings(String month) async {
    final d = await _run(r'query E($month: String!) { myEarnings(month: $month) }', {'month': month});
    return MyEarnings.fromJson(_json(d['myEarnings']));
  }

  /// Ajouts, retraits ou réordonnancement de la tournée par le dispatcher (spec §7)
  static StreamSubscription onTourChanged(String tourId, void Function(TourSummary) onData) {
    final stream = Amplify.API.subscribe(GraphQLRequest<String>(
      document: 'subscription O(\$id: ID!) { onTourChanged(id: \$id) { $_tour } }',
      variables: {'id': tourId},
    ));
    return stream.listen((e) {
      if (e.data == null) return;
      final t = (jsonDecode(e.data!) as Map<String, dynamic>)['onTourChanged'];
      if (t is Map) onData(TourSummary.fromJson(Map<String, dynamic>.from(t)));
    }, onError: (Object e) => safePrint('Abonnement tournée interrompu : $e'));
  }
}
