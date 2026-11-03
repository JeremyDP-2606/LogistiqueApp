import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_static_maps_controller/google_static_maps_controller.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/const.dart';
import 'package:wabap/models/Status.dart';
import 'package:wabap/util.dart';
import 'package:wabap/models/Tournee.dart';
import 'package:wabap/screen/tournee_screen.dart';

class TourneeItem extends ConsumerWidget {
  final Tournee? tournee;

  const TourneeItem({
    super.key,
    required this.tournee,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tournee == null) {
      return const Center(child: CircularProgressIndicator());
    } else {
      final List<Location> pins = [];
      if (tournee!.colis != null) {
        for (var i = 0; i < min(tournee!.colis!.length, 99); i++) {
          final colis = tournee!.colis![i];
          pins.add(Location(colis.latitude, colis.longitude));
        }
      }

      const hImage = 130.0;
      const wImage = 110.0;
      const padding = 10.0;
      const scaleImage = 3;

      final List<Marker> markers =
          pins.isNotEmpty ? [Marker(locations: pins, size: MarkerSize.mid, color: C.app[300])] : [];

      markers.add(Marker(locations: [Location(tournee!.startLatitude, tournee!.startLongitude)]));

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
          if (tournee?.id != null) {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => TourneeScreen(tourneeId: tournee!.id)));
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
                    Text(tournee!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    Row(
                      children: [
                        const Text(
                          "Statut : ",
                        ),
                        Icon(
                          Util.statusIcon(tournee!.status),
                          color: Util.statusColor(tournee!.status),
                          size: 14.0,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          Util.statusName(tournee!.status),
                          style: TextStyle(color: Util.statusColor(tournee!.status), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Image.asset(width: 15, "assets/images/colis.png"),
                        const SizedBox(width: 3),
                        Text('Colis : ${_nbColisByStatus(tournee!.colis, [
                              Status.COMPLETED,
                              Status.ISSUE
                            ])}/${tournee!.nbColis ?? "?"} livré'),
                      ],
                    ),
                    Row(
                      children: [
                        Image.asset(width: 15, "assets/images/distance.png"),
                        const SizedBox(width: 3),
                        Text('Distance : ${Util.formatDistance(tournee!.distance ?? 0)}'),
                      ],
                    ),
                    Row(
                      children: [
                        Image.asset(width: 15, "assets/images/duration.png"),
                        const SizedBox(width: 3),
                        Text('Durée : ${Util.formatDuration(tournee!.duree ?? 0)}'),
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

  int _nbColisByStatus(listColis, listStatus) {
    var nb = 0;
    for (var colis in listColis) {
      if (listStatus.contains(colis.lastStatus.status)) nb++;
    }
    return nb;
  }
}
