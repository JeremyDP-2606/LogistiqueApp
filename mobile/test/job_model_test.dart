import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:logistique_app/models/job.dart';

Map<String, dynamic> sample({String status = 'assigned', String? code = '1234'}) => {
      'id': 'j1',
      'ref': 'LG-000001',
      'status': status,
      'pickup': {'address': 'A', 'lat': 48.85, 'lng': 2.35},
      'dropoff': {'address': 'B', 'lat': 48.86, 'lng': 2.33},
      'packageSize': 'S',
      'urgency': 'standard',
      'vehicle': 'bike',
      'distanceKm': 2.4,
      'etaMinutes': 20,
      'price': {'ht': 7.14, 'tva': 1.43, 'ttc': 8.57},
      'courierEarning': 5.71,
      if (code != null) 'deliveryCode': code,
      'courier': {'id': 'c1', 'name': 'Léa', 'phone': '06', 'vehicle': 'bike', 'rating': 5, 'location': null},
      'history': [
        {'status': 'pending', 'at': '2026-01-01T10:00:00.000Z'},
        {'status': status, 'at': '2026-01-01T10:02:00.000Z'},
      ],
      'rating': null,
      'createdAt': '2026-01-01T10:00:00.000Z',
    };

void main() {
  test('parse une course', () {
    final j = Job.fromJson(sample());
    expect(j.ref, 'LG-000001');
    expect(j.priceTtc, 8.57);
    expect(j.isActive, isTrue);
    expect(j.history, hasLength(2));
    expect(j.courier?.location, isNull);
  });

  test('merge conserve le code de remise absent des diffusions', () {
    final j = Job.fromJson(sample());
    final merged = j.merge(Job.fromJson(sample(status: 'picked_up', code: null)));
    expect(merged.status, 'picked_up');
    expect(merged.deliveryCode, '1234');
  });

  test('position du coursier mise à jour', () {
    final j = Job.fromJson(sample()).withCourierLocation(const LatLng(48.9, 2.4));
    expect(j.courier!.location, const LatLng(48.9, 2.4));
    expect(j.deliveryCode, '1234');
  });
}
