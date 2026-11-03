// Libellés, formats et petits widgets partagés des écrans courses (Wabap V2).
import 'package:flutter/material.dart';

import '../colors.dart';

// Statuts d'une demande (spec §13), vus par le client
const orderStatusLabels = {
  'AWAITING_PAYMENT': 'Paiement en attente',
  'CREATED': 'Payée, en attente de planification',
  'TO_FIX': 'En cours de vérification',
  'PLANNED': 'Planifiée',
  'IN_PROGRESS': 'En cours',
  'DONE': 'Livrée',
  'PARTIALLY_FAILED': 'Échec de livraison',
  'CANCELLED': 'Annulée',
};

const tourStatusLabels = {
  'DRAFT': 'Brouillon',
  'PLANNED': 'Planifiée',
  'ASSIGNED': 'À accepter',
  'ACCEPTED': 'Acceptée',
  'IN_PROGRESS': 'En cours',
  'DONE': 'Terminée',
  'VALIDATED': 'Validée',
};

const stopStatusLabels = {'TODO': 'À faire', 'DONE': 'Fait', 'PARTIAL': 'Partiel', 'FAILED': 'Échec'};

Color statusColor(String s) {
  switch (s) {
    case 'AWAITING_PAYMENT':
    case 'TO_FIX':
    case 'ASSIGNED':
      return C.secondary;
    case 'DONE':
    case 'VALIDATED':
      return C.ok;
    case 'PARTIALLY_FAILED':
    case 'FAILED':
      return C.error;
    case 'CANCELLED':
    case 'DRAFT':
      return C.textColor;
    default:
      return C.blue;
  }
}

const sizeLabels = {
  'S': 'Petit · enveloppe, sac (2 kg max)',
  'M': 'Moyen · carton à chaussures (10 kg max)',
  'L': 'Grand · carton de déménagement (25 kg max)',
  'XL': 'Très grand · meuble, palette (50 kg max)',
};

String eur(num? n) => '${(n ?? 0).toStringAsFixed(2).replaceAll('.', ',')} €';
String two(int n) => n.toString().padLeft(2, '0');
String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String dayTime(DateTime d) => '${two(d.day)}/${two(d.month)} ${hm(d)}';
String km(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} km';

class StatusChip extends StatelessWidget {
  final String status;
  final Map<String, String> labels;
  const StatusChip(this.status, {super.key, this.labels = orderStatusLabels});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(labels[status] ?? status, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
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
