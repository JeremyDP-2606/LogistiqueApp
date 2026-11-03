// Appels GraphQL (AppSync) des courses à la demande.
// Toutes les écritures passent par la Lambda courseApi (voir amplify/backend/function/courseApi).
import 'dart:async';
import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';

import 'course_models.dart';

const _stop = 'address latitude longitude contactName phone instructions';

const courseFields = '''
  id ref status clientId courierId courierName courierPhone courierVehicle courierRating area
  pickup { $_stop } dropoff { $_stop }
  packageSize packageDescription urgency vehicle distanceKm etaMinutes priceTtc courierEarning
  paymentMode paymentStatus reason ratingStars distanceToPickupKm createdAt updatedAt
''';

class CourseApiException implements Exception {
  final String message;
  CourseApiException(this.message);
  @override
  String toString() => message;
}

class CreatedCourse {
  final Course course;
  final String? paymentClientSecret;
  final String deliveryCode;
  CreatedCourse(this.course, this.paymentClientSecret, this.deliveryCode);
}

class CourseApi {
  static Future<Map<String, dynamic>> _run(String document, Map<String, dynamic> variables, {bool mutation = false}) async {
    final request = GraphQLRequest<String>(document: document, variables: variables);
    final GraphQLResponse<String> response;
    try {
      response = mutation
          ? await Amplify.API.mutate(request: request).response
          : await Amplify.API.query(request: request).response;
    } on ApiException catch (e) {
      throw CourseApiException('Connexion impossible : ${e.message}');
    }
    if (response.hasErrors) {
      // Les messages d'erreur métier de la Lambda sont rédigés pour l'utilisateur
      throw CourseApiException(response.errors.first.message);
    }
    if (response.data == null) throw CourseApiException('Réponse vide du serveur');
    return jsonDecode(response.data!) as Map<String, dynamic>;
  }

  static Course _course(dynamic j) => Course.fromJson(Map<String, dynamic>.from(j as Map));

  // ---------------- Client ----------------

  static Future<CourseQuote> quote({
    required CourseStop pickup,
    required CourseStop dropoff,
    required String packageSize,
    required String urgency,
  }) async {
    final d = await _run('''
      query Quote(\$pickup: CourseStopInput!, \$dropoff: CourseStopInput!, \$packageSize: PackageSize!, \$urgency: Urgency!) {
        quoteCourse(pickup: \$pickup, dropoff: \$dropoff, packageSize: \$packageSize, urgency: \$urgency) {
          distanceKm options { vehicle etaMinutes priceHt priceTva priceTtc courierEarning }
        }
      }''', {
      'pickup': pickup.toInput(),
      'dropoff': dropoff.toInput(),
      'packageSize': packageSize,
      'urgency': urgency,
    });
    return CourseQuote.fromJson(Map<String, dynamic>.from(d['quoteCourse'] as Map));
  }

  static Future<CreatedCourse> create({
    required CourseStop pickup,
    required CourseStop dropoff,
    required String packageSize,
    required String urgency,
    required String vehicle,
    String? packageDescription,
  }) async {
    final d = await _run('''
      mutation Create(\$input: CreateCourseInput!) {
        createCourse(input: \$input) { paymentClientSecret deliveryCode course { $courseFields } }
      }''', {
      'input': {
        'pickup': pickup.toInput(),
        'dropoff': dropoff.toInput(),
        'packageSize': packageSize,
        'urgency': urgency,
        'vehicle': vehicle,
        if (packageDescription != null && packageDescription.isNotEmpty) 'packageDescription': packageDescription,
      }
    }, mutation: true);
    final r = Map<String, dynamic>.from(d['createCourse'] as Map);
    return CreatedCourse(_course(r['course']), r['paymentClientSecret'] as String?, r['deliveryCode'] as String);
  }

  static Future<Course> confirmPayment(String courseId) async {
    final d = await _run('''
      mutation Confirm(\$courseId: ID!) { confirmCoursePayment(courseId: \$courseId) { $courseFields } }''',
        {'courseId': courseId}, mutation: true);
    return _course(d['confirmCoursePayment']);
  }

  static Future<List<Course>> myCourses(String clientId) async {
    final d = await _run('''
      query Mine(\$clientId: ID!) {
        coursesByClient(clientId: \$clientId, sortDirection: DESC, limit: 50) { items { $courseFields } }
      }''', {'clientId': clientId});
    final items = ((d['coursesByClient'] as Map?)?['items'] as List?) ?? const [];
    return items.whereType<Map>().map(_course).toList();
  }

  static Future<Course> get(String id) async {
    final d = await _run('''
      query Get(\$id: ID!) {
        getCourse(id: \$id) { $courseFields events(limit: 50) { items { status createdAt message } } }
      }''', {'id': id});
    if (d['getCourse'] == null) throw CourseApiException('Course introuvable');
    return _course(d['getCourse']);
  }

  /// Code de remise : lisible uniquement par le client qui a commandé.
  static Future<String?> deliveryCode(String courseId) async {
    final d = await _run('query Secret(\$id: ID!) { getCourseSecret(id: \$id) { deliveryCode } }', {'id': courseId});
    return (d['getCourseSecret'] as Map?)?['deliveryCode'] as String?;
  }

  static Future<Course> cancel(String courseId, {String? reason}) async {
    final d = await _run('''
      mutation Cancel(\$courseId: ID!, \$reason: String) { cancelCourse(courseId: \$courseId, reason: \$reason) { $courseFields } }''',
        {'courseId': courseId, 'reason': reason}, mutation: true);
    return _course(d['cancelCourse']);
  }

  static Future<Course> rate(String courseId, int stars, String? comment) async {
    final d = await _run('''
      mutation Rate(\$courseId: ID!, \$stars: Int!, \$comment: String) {
        rateCourse(courseId: \$courseId, stars: \$stars, comment: \$comment) { $courseFields }
      }''', {'courseId': courseId, 'stars': stars, 'comment': comment}, mutation: true);
    return _course(d['rateCourse']);
  }

  // ---------------- Livreur ----------------

  static Future<CourierProfile?> myProfile(String courierId) async {
    final d = await _run('query Profile(\$id: ID!) { getCourierProfile(id: \$id) { id vehicle online rating activeCourseId } }',
        {'id': courierId});
    final p = d['getCourierProfile'];
    return p == null ? null : CourierProfile.fromJson(Map<String, dynamic>.from(p as Map));
  }

  static Future<CourierProfile> setAvailability(bool online, {String? vehicle}) async {
    final d = await _run('''
      mutation Availability(\$online: Boolean!, \$vehicle: Vehicle) {
        setCourierAvailability(online: \$online, vehicle: \$vehicle) { id vehicle online rating activeCourseId }
      }''', {'online': online, 'vehicle': vehicle}, mutation: true);
    return CourierProfile.fromJson(Map<String, dynamic>.from(d['setCourierAvailability'] as Map));
  }

  static Future<void> updatePosition(double latitude, double longitude) async {
    await _run('''
      mutation Position(\$latitude: Float!, \$longitude: Float!) {
        updateCourierPosition(latitude: \$latitude, longitude: \$longitude) { courseId courierId latitude longitude at }
      }''', {'latitude': latitude, 'longitude': longitude}, mutation: true);
  }

  static Future<List<Course>> available() async {
    final d = await _run('query Available { availableCourses { $courseFields } }', {});
    return ((d['availableCourses'] as List?) ?? const []).whereType<Map>().map(_course).toList();
  }

  static Future<Course?> current(String courierId) async {
    final profile = await myProfile(courierId);
    if (profile?.activeCourseId == null) return null;
    return get(profile!.activeCourseId!);
  }

  static Future<Course> accept(String courseId) async {
    final d = await _run('mutation Accept(\$courseId: ID!) { acceptCourse(courseId: \$courseId) { $courseFields } }',
        {'courseId': courseId}, mutation: true);
    return _course(d['acceptCourse']);
  }

  static Future<Course> step(String courseId, String status, {String? code, String? reason}) async {
    final d = await _run('''
      mutation Step(\$courseId: ID!, \$status: CourseStatus!, \$code: String, \$reason: String) {
        updateCourseStep(courseId: \$courseId, status: \$status, code: \$code, reason: \$reason) { $courseFields }
      }''', {'courseId': courseId, 'status': status, 'code': code, 'reason': reason}, mutation: true);
    return _course(d['updateCourseStep']);
  }

  static Future<CourierEarnings> earnings() async {
    final d = await _run('''
      query Earnings {
        courierEarnings {
          today { count amount } week { count amount } total { count amount distanceKm } rating
          recent { courseId ref amount distanceKm at dropoffAddress }
        }
      }''', {});
    return CourierEarnings.fromJson(Map<String, dynamic>.from(d['courierEarnings'] as Map));
  }

  // ---------------- Temps réel ----------------

  static StreamSubscription<GraphQLResponse<String>> _subscribe(
    String document,
    Map<String, dynamic> variables,
    String field,
    void Function(Map<String, dynamic>) onData,
  ) {
    final stream = Amplify.API.subscribe(GraphQLRequest<String>(document: document, variables: variables));
    return stream.listen((event) {
      if (event.data == null) return;
      final data = (jsonDecode(event.data!) as Map<String, dynamic>)[field];
      if (data is Map) onData(Map<String, dynamic>.from(data));
    }, onError: (Object e) => safePrint('Abonnement $field interrompu : $e'));
  }

  static StreamSubscription onCourseChanged(String id, void Function(Course) onData) => _subscribe(
      'subscription Changed(\$id: ID!) { onCourseChanged(id: \$id) { $courseFields } }',
      {'id': id}, 'onCourseChanged', (j) => onData(Course.fromJson(j)));

  static StreamSubscription onCourierPosition(String courseId, void Function(double lat, double lng) onData) => _subscribe(
      'subscription Position(\$courseId: ID!) { onCourierPosition(courseId: \$courseId) { courseId courierId latitude longitude at } }',
      {'courseId': courseId}, 'onCourierPosition',
      (j) => onData((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble()));

  static StreamSubscription onCourseAvailable(String area, void Function(Course) onData) => _subscribe(
      'subscription Available(\$area: String!) { onCourseAvailable(area: \$area) { $courseFields } }',
      {'area': area}, 'onCourseAvailable', (j) => onData(Course.fromJson(j)));

  static StreamSubscription onCourseTaken(String area, void Function(Course) onData) => _subscribe(
      'subscription Taken(\$area: String!) { onCourseTaken(area: \$area) { $courseFields } }',
      {'area': area}, 'onCourseTaken', (j) => onData(Course.fromJson(j)));
}
