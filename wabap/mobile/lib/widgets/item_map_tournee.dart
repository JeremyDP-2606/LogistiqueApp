import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/models/ModelProvider.dart';
import 'package:wabap/util.dart';

class TourneeMapItem extends ConsumerWidget {
  final Tournee tournee;

  const TourneeMapItem({super.key, required this.tournee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = tournee.startName ?? Util.formatCoordonate(tournee.startLatitude, tournee.startLongitude);
    final info =
        tournee.startName != null ? Util.formatCoordonate(tournee.startLatitude, tournee.startLongitude) : null;
    final lat = tournee.startLatitude;
    final lng = tournee.startLongitude;

    return Container(
      width: double.infinity,
      color: C.white,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(width: 15, "assets/images/adresse.png"),
                const SizedBox(width: 3),
                const Text("Point de récupération :"),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (info != null) Text(info, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: C.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              onPressed: () async {
                String googleUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                if (await canLaunchUrlString(googleUrl)) {
                  await launchUrlString(googleUrl, mode: LaunchMode.externalApplication);
                } else {
                  throw 'Unable open the map.';
                }
              },
              child: const Text(
                "Itinéraire",
                style: TextStyle(color: C.white, fontSize: 18),
              ),
            )
          ],
        ),
      ),
    );
  }
}
