import 'package:flutter_test/flutter_test.dart';
import 'package:wabap/v2/common.dart';
import 'package:wabap/v2/course_models.dart';

Map<String, dynamic> course({String status = 'ASSIGNED', List<Map<String, dynamic>>? events}) => {
      'id': 'c1',
      'ref': 'WB-261103-AB12',
      'status': status,
      'clientId': 'client-1',
      'courierId': 'livreur-a',
      'courierName': 'Léa',
      'courierVehicle': 'BIKE',
      'courierRating': 4.8,
      'area': 'ddgw',
      'pickup': {'address': 'Rue Victor Hugo', 'latitude': 14.6037, 'longitude': -61.0731},
      'dropoff': {'address': 'Didier', 'latitude': 14.628, 'longitude': -61.08, 'contactName': 'Alice'},
      'packageSize': 'S',
      'urgency': 'EXPRESS',
      'vehicle': 'BIKE',
      'distanceKm': 3.2,
      'etaMinutes': 19,
      'priceTtc': 12.05,
      'courierEarning': 8.03,
      'paymentMode': 'CARD',
      'paymentStatus': 'authorized',
      'createdAt': '2026-11-03T10:00:00.000Z',
      'updatedAt': '2026-11-03T10:05:00.000Z',
      if (events != null) 'events': {'items': events},
    };

void main() {
  test('geohash identique à celui de la Lambda (abonnement par zone)', () {
    expect(geohashEncode(48.8584, 2.2945, precision: 7), 'u09tunq'); // même valeur que le test Node
    expect(geohashEncode(14.6037, -61.0731), geohashEncode(14.6037, -61.0731, precision: 5).substring(0, 4));
  });

  test('lecture d’une course et de son historique', () {
    final c = Course.fromJson(course(events: [
      {'status': 'ASSIGNED', 'createdAt': '2026-11-03T10:02:00.000Z'},
      {'status': 'PENDING', 'createdAt': '2026-11-03T10:01:00.000Z'},
    ]));
    expect(c.priceTtc, 12.05);
    expect(c.isActive, isTrue);
    expect(c.clientCanCancel, isTrue);
    expect(c.dropoff.contactName, 'Alice');
    expect(c.events.map((e) => e.status), ['PENDING', 'ASSIGNED'], reason: 'historique trié par date');
  });

  test('mise à jour temps réel : statut appliqué et ajouté à l’historique', () {
    final c = Course.fromJson(course(events: [
      {'status': 'ASSIGNED', 'createdAt': '2026-11-03T10:02:00.000Z'},
    ]));
    final u = c.mergeUpdate(Course.fromJson(course(status: 'PICKED_UP')));
    expect(u.status, 'PICKED_UP');
    expect(u.events.last.status, 'PICKED_UP');
    expect(u.clientCanCancel, isFalse);
  });

  test('formats', () {
    expect(eur(12.5), '12,50 €');
    expect(km(3.25), '3,3 km');
    expect(const CourseStop(address: 'x', latitude: 1, longitude: 2, phone: '').toInput().containsKey('phone'), isFalse);
  });
}
