import 'dart:async';
import 'dart:io';

import 'package:wabap/backend/backend.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wabap/main.dart';
import 'package:wabap/models/Status.dart';
import 'package:wabap/models/Tournee.dart';
import 'package:wabap/provider/api_providers.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/provider/tournee_provider.dart';
import 'package:flutter/material.dart';

final positionProvider = StreamProvider<Position?>((ref) {
  final streamController = StreamController<Position?>();

  // watch(select), not read: this provider is not autoDispose, so with a plain
  // read a forced sign-out (expired session) left it cached with userId == null
  // and GPS tracking stayed dead until the process restarted. Selecting on the
  // id alone rebuilds on sign-out/sign-in without reacting to every notify.
  final userId = ref.watch(authProvider.select((auth) => auth.myTrueId));
  if (userId == null) {
    streamController.add(null);
    ref.onDispose(() => streamController.close());
    return streamController.stream;
  }

  // Only re-evaluate when the "is any tournee in progress" flag actually flips.
  // Watching the whole tournee list re-ran this provider on every list change,
  // which created (and leaked) a new GPS subscription each time.
  final isInProgress = ref.watch(tourneeProvider(userId).select((async) =>
      async.maybeWhen(
        data: (tournees) => tournees.any((t) => t.status == Status.IN_PROGRESS),
        orElse: () => false,
      )));

  if (isInProgress) {
    _determinePosition(streamController, ref);
  } else {
    streamController.add(null);
    gpsStream?.cancel();
    gpsStream = null;
    API.updateLocation(userId, null, [], 0, 0); //remove all
  }

  ref.onDispose(() {
    streamController.close();
    gpsStream?.cancel();
    gpsStream = null;
  });

  return streamController.stream;
});

StreamSubscription<Position>? gpsStream;
void _determinePosition(StreamController<Position?> streamController, ref) async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    final context = WabapApp.navigatorKey.currentContext;
    if (context != null && context.mounted && Platform.isAndroid) {
      await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
                title: const Text(
                  "Autirisation GPS :",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: const SingleChildScrollView(
                    child: Text(
                        "Wabap à besoin de récupérer votre localisation GPS pour vous suivre lors d'une tournée, même lorsque l'application est fermée ou non utilisée.")),
                actions: [
                  TextButton(
                    child: const Text("OK"),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ]);
          });
    }

    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error("Localisation refusée");
    }
  }

  bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
  safePrint(">>>>> isLocationServiceEnabled=[$isLocationServiceEnabled]");

  late LocationSettings locationSettings;
  if (defaultTargetPlatform == TargetPlatform.android) {
    locationSettings = AndroidSettings(accuracy: LocationAccuracy.high, distanceFilter: 1);
  } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
    locationSettings = AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.fitness,
      distanceFilter: 1,
      pauseLocationUpdatesAutomatically: true,
      showBackgroundLocationIndicator: true,
    );
  } else {
    locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );
  }

  // Cancel any previous subscription before creating a new one (prevents
  // leaking GPS streams that keep firing and hammering updateLocation).
  await gpsStream?.cancel();
  gpsStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
    streamController.add(position);
    final userId = ref.read(authProvider.notifier).myTrueId;
    final userName = ref.read(authProvider.notifier).name;
    final tournees = ref.read(tourneeProvider(userId).notifier).getTournees();
    final listTourneeInProgress = <Tournee>[];
    for (var tournee in tournees) {
      if (tournee.status == Status.IN_PROGRESS) {
        listTourneeInProgress.add(tournee);
      }
    }
    API.updateLocation(userId, userName, listTourneeInProgress, position.latitude, position.longitude);
  }, onError: (error) {
    if (error is LocationServiceDisabledException) {
      streamController.addError('GPS désactivé');
    } else if (error is PermissionDeniedException) {
      streamController.addError("Localisation refusée");
    } else {
      streamController.addError("Erreur inconnue");
    }
  });

  streamController.onCancel = () {
    gpsStream?.cancel();
  };
}
