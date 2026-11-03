import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_static_maps_controller/google_static_maps_controller.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/const.dart';
import 'package:wabap/models/Mission.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/screen/mission_screen.dart';
import 'package:wabap/util.dart';
import 'package:wabap/widgets/widget_week.dart';

class MissionItem extends ConsumerWidget {
  final Mission? mission;

  const MissionItem({
    super.key,
    required this.mission,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider).myId;

    if (mission == null) {
      return const Center(child: CircularProgressIndicator());
    } else {
      final List<Location> pins = [];
      if (mission!.subscribers != null) {
        for (var i = 0; i < min(mission!.subscribers!.length, 99); i++) {
          final sub = mission!.subscribers![i];
          if (sub.longitude != null && sub.latitude != null) {
            pins.add(Location(sub.latitude!, sub.longitude!));
          }
        }
      }

      const hImage = 130.0;
      const wImage = 110.0;
      const padding = 10.0;
      const scaleImage = 3;

      final List<Marker> markers =
          pins.isNotEmpty ? [Marker(locations: pins, size: MarkerSize.mid, color: C.app[300])] : [];

      markers.add(Marker(locations: [Location(mission!.startLatitude, mission!.startLongitude)]));

      var inscripton = InscriptionState.NO;
      if (mission?.inscriptions?.any((i) => i.livreurID == userId) ?? false) inscripton = InscriptionState.PENDING;
      if (mission?.livreurID == userId) inscripton = InscriptionState.ACCEPTED;

      final controllerImageMap = StaticMapController(
        googleApiKey: GOOGLE_API_KEY,
        width: wImage.toInt() * scaleImage,
        height: (hImage * 1.2).toInt() * scaleImage, //*1.2 remove logo
        zoom: 10,
        center: GeocodedLocation.latLng(MARTINIQUE.latitude, MARTINIQUE.longitude),
        styles: Util.retroMapStyle,
        markers: markers,
      );
      return InkWell(
        onTap: () {
          if (mission?.id != null) {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => MissionScreen(missionId: mission!.id)));
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(left: padding, top: padding / 2, right: padding, bottom: padding / 2),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: SizedBox(
                  width: wImage,
                  height: hImage,
                  child: Stack(
                    children: [
                      Container(color: Colors.grey[200]),
                      Image(
                        width: wImage,
                        height: hImage,
                        image: controllerImageMap.image,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }
                          return Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: Opacity(
                                opacity: 0.5,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Opacity(
                              opacity: 0.1,
                              child: Image.asset(width: 15, "assets/images/error.png"),
                            ),
                          );
                        },
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mission!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    Row(
                      children: [
                        const Text("Inscription : "),
                        Icon(
                          Util.inscriptionIcon(inscripton),
                          color: Util.inscriptionColor(inscripton),
                          size: 14.0,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          Util.inscriptionName(inscripton),
                          style: TextStyle(color: Util.inscriptionColor(inscripton), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text("Jour de la semaine : "),
                    WidgetWeek(week: mission!.daysOfWeek),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_alt_outlined,
                          size: 15,
                          color: C.text,
                        ),
                        const SizedBox(width: 3),
                        Text('Liste d\'attente : ${mission!.inscriptions?.length ?? 0}'),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      );
    }
  }
}
