import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const statusLabels = {
  'pending': 'Recherche d’un coursier',
  'assigned': 'Coursier assigné',
  'picking_up': 'En route vers le retrait',
  'picked_up': 'Colis récupéré',
  'delivering': 'En cours de livraison',
  'delivered': 'Livrée',
  'failed': 'Échec de livraison',
  'cancelled': 'Annulée',
};

Color statusColor(String s) {
  switch (s) {
    case 'pending':
      return const Color(0xFFB45309);
    case 'delivered':
      return const Color(0xFF15803D);
    case 'failed':
      return const Color(0xFFB91C1C);
    case 'cancelled':
      return const Color(0xFF64748B);
    default:
      return const Color(0xFF1D4ED8);
  }
}

const vehicleLabels = {'bike': 'Vélo', 'motorbike': 'Scooter', 'car': 'Voiture', 'van': 'Utilitaire'};
const vehicleIcons = {
  'bike': Icons.pedal_bike,
  'motorbike': Icons.moped,
  'car': Icons.directions_car,
  'van': Icons.local_shipping,
};
const sizeLabels = {
  'S': 'Petit · enveloppe, sac',
  'M': 'Moyen · carton à chaussures',
  'L': 'Grand · carton de déménagement',
  'XL': 'Très grand · meuble, palette',
};

final _eur = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
String eur(num? n) => _eur.format(n ?? 0);
String hm(DateTime d) => DateFormat('HH:mm').format(d);
String dayTime(DateTime d) => DateFormat('dd/MM HH:mm').format(d);
