// Libellés, formats et petits widgets partagés des écrans courses (Wabap V2).
import 'package:flutter/material.dart';

import '../colors.dart';

const statusLabels = {
  'AWAITING_PAYMENT': 'Paiement en attente',
  'PENDING': 'Recherche d’un livreur',
  'ASSIGNED': 'Livreur en route',
  'PICKING_UP': 'Livreur en route vers le retrait',
  'PICKED_UP': 'Colis récupéré',
  'DELIVERING': 'En cours de livraison',
  'COMPLETED': 'Livrée',
  'ISSUE': 'Problème de livraison',
  'CANCELLED': 'Annulée',
};

Color statusColor(String s) {
  switch (s) {
    case 'AWAITING_PAYMENT':
    case 'PENDING':
      return C.secondary;
    case 'COMPLETED':
      return C.ok;
    case 'ISSUE':
      return C.error;
    case 'CANCELLED':
      return C.textColor;
    default:
      return C.blue;
  }
}

const vehicleLabels = {'BIKE': 'Vélo', 'MOTORBIKE': 'Scooter', 'CAR': 'Voiture', 'VAN': 'Utilitaire'};
const vehicleIcons = {
  'BIKE': Icons.pedal_bike,
  'MOTORBIKE': Icons.moped,
  'CAR': Icons.directions_car,
  'VAN': Icons.local_shipping,
};
const sizeLabels = {
  'S': 'Petit · enveloppe, sac',
  'M': 'Moyen · carton à chaussures',
  'L': 'Grand · carton de déménagement',
  'XL': 'Très grand · meuble, palette',
};

String eur(num? n) => '${(n ?? 0).toStringAsFixed(2).replaceAll('.', ',')} €';
String two(int n) => n.toString().padLeft(2, '0');
String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String dayTime(DateTime d) => '${two(d.day)}/${two(d.month)} ${hm(d)}';
String km(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} km';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(statusLabels[status] ?? status, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class StopLine extends StatelessWidget {
  final String letter;
  final Color color;
  final String address;
  final String? details;
  const StopLine({super.key, required this.letter, required this.color, required this.address, this.details});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 11, backgroundColor: color, child: Text(letter, style: const TextStyle(color: C.white, fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(address, style: const TextStyle(color: C.text)),
              if (details != null && details!.isNotEmpty)
                Text(details!, style: const TextStyle(color: C.textColor, fontSize: 13)),
            ]),
          ),
        ]),
      );
}

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: C.error));
}

void showInfo(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Geohash (même algorithme que la Lambda) : zone d'abonnement temps réel des livreurs.
String geohashEncode(double lat, double lng, {int precision = 4}) {
  const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  var latMin = -90.0, latMax = 90.0, lngMin = -180.0, lngMax = 180.0;
  final out = StringBuffer();
  var bit = 0, ch = 0;
  var even = true;
  while (out.length < precision) {
    if (even) {
      final mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch = (ch << 1) | 1;
        lngMin = mid;
      } else {
        ch <<= 1;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch = (ch << 1) | 1;
        latMin = mid;
      } else {
        ch <<= 1;
        latMax = mid;
      }
    }
    even = !even;
    if (++bit == 5) {
      out.write(base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return out.toString();
}
