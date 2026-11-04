// Tests de contrat : l'app décode les réponses réellement produites par la fonction deliveryApi
// (fichiers générés par backend/scripts/export-fixtures.js).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wabap/v2/common.dart';
import 'package:wabap/v2/platform_models.dart';

Map<String, dynamic> fixture(String name) => jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('vue livreur d’une tournée : points ordonnés, colis, preuves exigées, commentaires', () {
    final v = CourierTour.fromJson(fixture('courier_tour_view'));
    expect(v.tour.status, 'IN_PROGRESS');
    expect(v.stops.map((s) => s.sequence).toList(), List.generate(v.stops.length, (i) => i + 1));
    expect(v.stops.first.isPickup, isTrue, reason: 'une tournée commence par une collecte');
    expect(v.stops.every((s) => s.parcels.isNotEmpty), isTrue);
    final next = v.next!;
    expect(next.todo, isTrue);
    expect(v.doneCount, greaterThan(0));
    // Profil « Standard » : photo et position à la livraison
    final delivery = v.stops.firstWhere((s) => !s.isPickup && s.todo && s.place.name != 'Carrosserie Cluny');
    expect(delivery.requirements.photo, isTrue);
    expect(delivery.requirements.geoloc, isTrue);
    expect(delivery.requirements.signature, isFalse);
    // Profil « Sécurisé » (garage) : signature et scan
    final secure = v.stops.firstWhere((s) => s.place.name == 'Carrosserie Cluny');
    expect(secure.requirements.signature, isTrue);
    expect(secure.requirements.scanParcelIds, isNotEmpty);
    expect(v.presets.where((p) => p.kind == 'FAILURE'), isNotEmpty);
  });

  test('suivi par étapes d’une course payée', () {
    final t = Tracking.fromJson(fixture('order_tracking'));
    expect(t.steps.map((s) => s.key).toList(), ['PAID', 'PLANNED', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED']);
    expect(t.currentStep, 'PAID');
    expect(t.order.status, 'CREATED');
    expect(t.order.cancellable, isTrue);
    expect(t.otpCode, matches(RegExp(r'^\d{4}$')), reason: 'profil de preuve des courses : code de confirmation');
    expect(t.priceLines.first.label, startsWith('Prise en charge'));
    expect(t.order.delivery.name, isNotNull);
  });

  test('devis détaillé', () {
    final q = Quote.fromJson(fixture('quote'));
    expect(q.total, greaterThanOrEqualTo(10));
    expect(q.lines.map((l) => l.amount).reduce((a, b) => a + b), closeTo(q.total, 0.011));
    expect(q.lines.any((l) => l.label.contains('km × ')), isTrue);
    expect(q.deadlineAt, isNotNull);
  });

  test('gains du livreur', () {
    final e = MyEarnings.fromJson(fixture('my_earnings'));
    expect(e.tours, hasLength(1));
    expect(e.status, 'TO_VALIDATE');
    expect(e.total, e.tours.first.amount);
  });

  test('libellés propres au contexte (demande ou tournée)', () {
    expect(orderStatusLabels['DONE'], 'Livrée');
    expect(tourStatusLabels['DONE'], 'Terminée');
    expect(eur(12.5), '12,50 €');
  });
}
