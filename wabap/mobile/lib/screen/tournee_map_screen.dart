// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/const.dart';
import 'dart:math';

import 'package:wabap/models/ModelProvider.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/provider/colis_provider.dart';
import 'package:wabap/provider/tournee_provider.dart';
import 'package:wabap/screen/error_screen.dart';
import 'package:wabap/widgets/item_map_colis.dart';
import 'package:wabap/widgets/item_map_tournee.dart';

class TourneeMapScreen extends HookConsumerWidget {
  final String tourneeId;
  final String? colisId;
  TourneeMapScreen({Key? key, required this.tourneeId, this.colisId}) : super(key: key);

  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  final selectColisProvider = StateProvider<Colis?>((ref) => null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    safePrint(">>>> BUILD TourneeMapScreen");
    final userId = ref.watch(authProvider).myId ?? "";
    final tournee = ref.read(tourneeProvider(userId).notifier).getTournee(tourneeId);
    if (tournee == null) return const ErrorScreen("Tournée non trouvée");
    final listColis = ref.read(colisProvider(tournee.id).notifier).getAllColis();
    final pin = useMemoized(() => _loadCustomPin());
    final pinResult = useFuture(pin);
    final pinDone = useMemoized(() => _loadCustomPinDone());
    final pinDoneResult = useFuture(pinDone);
    final pinError = useMemoized(() => _loadCustomPinError());
    final pinErrorResult = useFuture(pinError);
    final nextColis =
        tournee.status != Status.PENDING ? _nextColisStatus([Status.PENDING, Status.IN_PROGRESS], listColis) : null;
    final colis = colisId != null ? ref.read(colisProvider(tournee.id).notifier).getColis(colisId!) : null;
    final currentSelectColis = ref.watch(selectColisProvider) ?? colis ?? nextColis;
    final lat = tournee.status == Status.PENDING
        ? tournee.startLatitude
        : (currentSelectColis?.latitude ?? _getCenterAllColis(tournee, listColis).latitude);
    final lng = tournee.status == Status.PENDING
        ? tournee.startLongitude
        : (currentSelectColis?.longitude ?? _getCenterAllColis(tournee, listColis).longitude);

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
                      zoom: currentSelectColis != null || tournee.status == Status.PENDING
                          ? 15.0
                          : _getZoomForAllColis(tournee, listColis),
                    ),
                    markers: _getMarkersBySubscriber(currentSelectColis, pinResult.data, pinDoneResult.data,
                        pinErrorResult.data, ref, tournee, listColis),
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                    style: STYLE_MAP,
                    polylines: _loadPolyline(listColis, nextColis),
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        FloatingActionButton(
                          heroTag: null,
                          onPressed: () {
                            final previousColis = currentSelectColis != null
                                ? ref.read(colisProvider(tournee.id).notifier).getPreviousColis(currentSelectColis.id)
                                : null;
                            if (previousColis != null) {
                              ref.read(selectColisProvider.notifier).state = previousColis;
                              _controller.future.then((controller) {
                                controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
                                    target: LatLng(previousColis.latitude, previousColis.longitude), zoom: 15.0)));
                              });
                            }
                          },
                          shape: const CircleBorder(),
                          backgroundColor: Colors.white,
                          foregroundColor: C.primary,
                          mini: true,
                          child: const Icon(Icons.chevron_left_rounded),
                        ),
                        const Spacer(),
                        FloatingActionButton(
                          heroTag: null,
                          onPressed: () {
                            final nextColis = currentSelectColis != null
                                ? ref.read(colisProvider(tournee.id).notifier).getNextColis(currentSelectColis.id)
                                : null;
                            if (nextColis != null) {
                              ref.read(selectColisProvider.notifier).state = nextColis;
                              _controller.future.then((controller) {
                                controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
                                    target: LatLng(nextColis.latitude, nextColis.longitude), zoom: 15.0)));
                              });
                            }
                          },
                          shape: const CircleBorder(),
                          backgroundColor: Colors.white,
                          foregroundColor: C.primary,
                          mini: true,
                          child: const Icon(Icons.chevron_right_rounded),
                        )
                      ],
                    ),
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
            _getBottomView(currentSelectColis, tournee),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          tournee.name,
          style: const TextStyle(color: C.white),
        ),
      ),
    );
  }

  _getBottomView(colis, tournee) {
    if (tournee.status == Status.PENDING) {
      /**
       * START TOURNEE
       */
      return TourneeMapItem(tournee: tournee);
    } else if (colis != null) {
      /**
       * TOURNEE IN PROGRESS
       */
      return ColisMapItem(colisId: colis.id, tourneeId: tournee.id);
    } else {
      /**
         * TOURNEE COMPLETE
         */

      return Container(
        color: C.white,
        child: Padding(
          padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
          child: Column(
            children: [
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(width: 30, "assets/images/check_on.png"),
                    const SizedBox(
                      width: 10,
                    ),
                    const Expanded(
                      child: Text(
                        "Votre tournée est validée.",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  _getMarkersBySubscriber(Colis? nextColis, BitmapDescriptor? pin, BitmapDescriptor? pinDone,
      BitmapDescriptor? pinError, WidgetRef ref, Tournee tournee, List<Colis> listColis) {
    Set<Marker> markers = {};

    markers.add(Marker(
        icon: tournee.status == Status.PENDING
            ? BitmapDescriptor.defaultMarkerWithHue(35)
            : (pin ?? BitmapDescriptor.defaultMarkerWithHue(35)),
        markerId: MarkerId(tournee.id),
        position: LatLng(tournee.startLatitude, tournee.startLongitude),
        infoWindow: InfoWindow(title: tournee.startName)));

    for (var colis in listColis) {
      markers.add(Marker(
        icon: colis.id == nextColis?.id
            ? BitmapDescriptor.defaultMarkerWithHue(35)
            : ((colis.lastStatus.status == Status.COMPLETED
                    ? pinDone
                    : colis.lastStatus.status == Status.ISSUE
                        ? pinError
                        : pin) ??
                BitmapDescriptor.defaultMarkerWithHue(35)),
        markerId: MarkerId(colis.id),
        position: LatLng(colis.latitude, colis.longitude),
        onTap: () {
          ref.read(selectColisProvider.notifier).state = colis;
        },
      ));
    }
    return markers;
  }

  Future<BitmapDescriptor> _loadCustomPin() async {
    final ByteData bytes = await rootBundle.load('assets/images/pin.png');
    final Uint8List list = bytes.buffer.asUint8List();
    return BitmapDescriptor.bytes(list);
  }

  Future<BitmapDescriptor> _loadCustomPinDone() async {
    final ByteData bytes = await rootBundle.load('assets/images/pin_green.png');
    final Uint8List list = bytes.buffer.asUint8List();
    return BitmapDescriptor.bytes(list);
  }

  Future<BitmapDescriptor> _loadCustomPinError() async {
    final ByteData bytes = await rootBundle.load('assets/images/pin_error.png');
    final Uint8List list = bytes.buffer.asUint8List();
    return BitmapDescriptor.bytes(list);
  }

  Colis? _nextColisStatus(List<Status> listStatus, List<Colis> listColis) {
    for (var colis in listColis) {
      if (listStatus.contains(colis.lastStatus.status)) return colis;
    }
    return null;
  }

  Set<Polyline> _loadPolyline(List<Colis>? listColis, nextColis) {
    if (listColis == null || listColis.isEmpty) {
      return Set.from(List.empty());
    }
    final List<List<PointLatLng>> polylinesDecode = [[]];
    for (final colis in listColis) {
      if (colis.polyline != null) {
        polylinesDecode.add(PolylinePoints().decodePolyline(colis.polyline!));
      }
    }

    final nextColisId = nextColis?.id;
    var polylineDone = nextColisId != null;
    Set<Polyline> polylines = {};
    for (final colis in listColis) {
      if (colis.polyline != null) {
        var polyline = PolylinePoints().decodePolyline(colis.polyline!);
        final List<LatLng> points = [];
        for (var point in polyline) {
          points.add(LatLng(point.latitude, point.longitude));
        }
        if (colis.id == nextColisId) polylineDone = false;
        polylines.add(Polyline(
            polylineId: const PolylineId("border"),
            color: polylineDone ? C.route_done_border : C.secondary,
            width: 7,
            points: points));
        polylines.add(Polyline(
            polylineId: const PolylineId("route"),
            color: polylineDone ? C.route_done : C.primary_light,
            width: 4,
            points: points));
      }
    }

    return polylines;
  }

  _getCenterAllColis(Tournee tournee, List<Colis> listColis) {
    double maxLat = tournee.startLatitude;
    double minLat = tournee.startLatitude;
    double maxLng = tournee.startLongitude;
    double minLng = tournee.startLongitude;
    for (var colis in listColis) {
      if (colis.latitude > maxLat) maxLat = colis.latitude;
      if (colis.latitude < minLat) minLat = colis.latitude;
      if (colis.longitude > maxLng) maxLng = colis.longitude;
      if (colis.longitude < minLng) minLng = colis.longitude;
    }
    double centerLat = ((maxLat - minLat) / 2.0) + minLat;
    double centerLng = ((maxLng - minLng) / 2.0) + minLng;
    return LatLng(centerLat, centerLng);
  }

  double _getZoomForAllColis(Tournee tournee, List<Colis> listColis) {
    double maxLat = tournee.startLatitude;
    double minLat = tournee.startLatitude;
    double maxLng = tournee.startLongitude;
    double minLng = tournee.startLongitude;
    for (var colis in listColis) {
      if (colis.latitude > maxLat) maxLat = colis.latitude;
      if (colis.latitude < minLat) minLat = colis.latitude;
      if (colis.longitude > maxLng) maxLng = colis.longitude;
      if (colis.longitude < minLng) minLng = colis.longitude;
    }
    double maxDiff = max(maxLat - minLat, maxLng - minLng);

    if (maxDiff > 0.5 / 2) return 10;
    if (maxDiff > 0.5 / 4) return 11;
    if (maxDiff > 0.5 / 8) return 12;
    if (maxDiff > 0.5 / 16) return 13;
    return 14;
  }
}
