// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/const.dart';
import 'package:wabap/provider/api_providers.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/provider/mission_provider.dart';
import 'package:wabap/screen/error_screen.dart';
import 'dart:math';
import 'package:wabap/util.dart';

import 'package:wabap/models/ModelProvider.dart';
import 'package:wabap/widgets/widget_week.dart';

class MissionScreen extends HookConsumerWidget {
  final String missionId;
  MissionScreen({Key? key, required this.missionId}) : super(key: key);

  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    safePrint(">>>> BUILD TourneeMapScreen");
    final userId = ref.watch(authProvider).myId;
    final mission = ref.watch(missionProvider.notifier).getMission(missionId);
    final pin = useMemoized(() => _loadCustomPin());
    final pinResult = useFuture(pin);
    final lat = _getCenterAllColis(mission).latitude;
    final lng = _getCenterAllColis(mission).longitude;
    final isBtnLoading = useState(false);

    if (mission == null) return const ErrorScreen("Error inconnue");
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    padding: const EdgeInsets.only(bottom: 20),
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(lat, lng),
                      zoom: _getZoomForAllColis(mission),
                    ),
                    markers: _getMarkers(mission, pinResult.data),
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                    style: STYLE_MAP,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: 20,
                      child: Container(
                          decoration: BoxDecoration(
                        color: C.white,
                        borderRadius:
                            const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(77),
                            spreadRadius: 1,
                            blurRadius: 7,
                          )
                        ],
                      )),
                    ),
                  )
                ],
              ),
            ),
            _getBottomView(ref, mission, userId, isBtnLoading),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          mission.name,
          style: const TextStyle(color: C.white),
        ),
      ),
    );
  }

  _getBottomView(WidgetRef ref, Mission mission, String? userId, isBtnLoading) {
    var inscriptonState = InscriptionState.NO;
    if (mission.inscriptions?.any((i) => i.livreurID == userId) ?? false) inscriptonState = InscriptionState.PENDING;
    if (mission.livreurID == userId) inscriptonState = InscriptionState.ACCEPTED;

    return Container(
        color: C.white,
        child: Padding(
            padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mission.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                Row(
                  children: [
                    const Text("Inscription : "),
                    Icon(
                      Util.inscriptionIcon(inscriptonState),
                      color: Util.inscriptionColor(inscriptonState),
                      size: 14.0,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      Util.inscriptionName(inscriptonState),
                      style: TextStyle(color: Util.inscriptionColor(inscriptonState), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const Text("Jour de la semaine : "),
                const SizedBox(height: 3),
                WidgetWeek(week: mission.daysOfWeek),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt_outlined,
                      size: 15,
                      color: C.text,
                    ),
                    const SizedBox(width: 3),
                    Text('Liste d\'attente : ${mission.inscriptions?.length ?? 0}'),
                  ],
                ),
                Row(
                  children: [
                    Image.asset(width: 15, "assets/images/colis.png"),
                    const SizedBox(width: 3),
                    Text('Colis : ${mission.subscribers?.length ?? 0}'),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: inscriptonState == InscriptionState.NO ? C.primary : C.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                      side: BorderSide(
                        color: isBtnLoading.value || inscriptonState == InscriptionState.ACCEPTED
                            ? C.disable
                            : C.primary, // Couleur de la bordure
                        width: 2, // Épaisseur de la bordure
                      ),
                    ),
                  ),
                  onPressed: isBtnLoading.value || inscriptonState == InscriptionState.ACCEPTED
                      ? null
                      : () async {
                          isBtnLoading.value = true;
                          if (userId != null) {
                            Inscription? inscripton =
                                ref.read(missionProvider.notifier).getInscription(missionId, userId);
                            if (inscripton == null) {
                              final clientName = ref.read(authProvider.notifier).clientName;
                              if (clientName != null) {
                                final newInscription = await API.createInscription(
                                    Inscription(owner: clientName, livreurID: userId, mission: mission));
                                if (newInscription != null) {
                                  ref.read(missionProvider.notifier).addInscrption(newInscription);
                                }
                              }
                            } else {
                              final deletedInscription = await API.deleteInscription(inscripton);
                              if (deletedInscription != null) {
                                ref.read(missionProvider.notifier).deleteInscrption(deletedInscription);
                              }
                            }
                          }
                          isBtnLoading.value = false;
                        },
                  child: isBtnLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: C.primary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          inscriptonState == InscriptionState.NO ? "Postuler à cette mission" : "Se désinscrire",
                          style: TextStyle(
                              color: inscriptonState != InscriptionState.PENDING ? C.white : C.primary, fontSize: 18),
                        ),
                ),
                const SizedBox(height: 10),
              ],
            )));
  }

  _getMarkers(Mission mission, BitmapDescriptor? pin) {
    Set<Marker> markers = {};

    markers.add(Marker(
        icon: BitmapDescriptor.defaultMarkerWithHue(35),
        markerId: MarkerId(mission.id),
        position: LatLng(mission.startLatitude, mission.startLongitude),
        infoWindow: InfoWindow(title: mission.startName)));

    if (mission.subscribers != null) {
      for (var sub in mission.subscribers!) {
        if (sub.longitude != null && sub.latitude != null) {
          markers.add(Marker(
            icon: pin ?? BitmapDescriptor.defaultMarkerWithHue(35),
            markerId: MarkerId(sub.id),
            position: LatLng(sub.latitude!, sub.longitude!),
            infoWindow: InfoWindow(title: sub.address),
          ));
        }
      }
    }
    return markers;
  }

  Future<BitmapDescriptor> _loadCustomPin() async {
    final ByteData bytes = await rootBundle.load('assets/images/pin.png');
    final Uint8List list = bytes.buffer.asUint8List();
    return BitmapDescriptor.bytes(list);
  }

  _getCenterAllColis(Mission? mission) {
    if (mission == null) return LatLng(MARTINIQUE.latitude, MARTINIQUE.longitude);
    double maxLat = mission.startLatitude;
    double minLat = mission.startLatitude;
    double maxLng = mission.startLongitude;
    double minLng = mission.startLongitude;
    if (mission.subscribers != null) {
      for (var sub in mission.subscribers!) {
        if (sub.longitude != null && sub.latitude != null) {
          if (sub.latitude! > maxLat) maxLat = sub.latitude!;
          if (sub.latitude! < minLat) minLat = sub.latitude!;
          if (sub.longitude! > maxLng) maxLng = sub.longitude!;
          if (sub.longitude! < minLng) minLng = sub.longitude!;
        }
      }
    }
    double centerLat = ((maxLat - minLat) / 2.0) + minLat;
    double centerLng = ((maxLng - minLng) / 2.0) + minLng;
    return LatLng(centerLat, centerLng);
  }

  double _getZoomForAllColis(Mission? mission) {
    if (mission == null) return 10;
    double maxLat = mission.startLatitude;
    double minLat = mission.startLatitude;
    double maxLng = mission.startLongitude;
    double minLng = mission.startLongitude;
    if (mission.subscribers != null) {
      for (var sub in mission.subscribers!) {
        if (sub.longitude != null && sub.latitude != null) {
          if (sub.latitude! > maxLat) maxLat = sub.latitude!;
          if (sub.latitude! < minLat) minLat = sub.latitude!;
          if (sub.longitude! > maxLng) maxLng = sub.longitude!;
          if (sub.longitude! < minLng) minLng = sub.longitude!;
        }
      }
    }
    double maxDiff = max(maxLat - minLat, maxLng - minLng);

    if (maxDiff > 0.5 / 2) return 10;
    if (maxDiff > 0.5 / 4) return 11;
    if (maxDiff > 0.5 / 8) return 12;
    if (maxDiff > 0.5 / 16) return 13;
    return 14;
  }
}
