import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
//import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/utils/utils.dart';

import 'package:wabap/provider/colis_tournee_provider.dart';
import 'package:wabap/provider/location_provider.dart';
import 'package:wabap/provider/tournee_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wabap/screen/error_screen.dart';
import 'package:wabap/models/Colis.dart';

import 'package:mobile_scanner/mobile_scanner.dart';


// Top-level (was previously created per-widget-instance, which is an anti-pattern).
final loadingProvider = StateProvider.autoDispose<bool>((ref) => false);

class ScannerView extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final bool isDeliveringPhase;

  const ScannerView({super.key, required this.onNext, required this.isDeliveringPhase});

  @override
  ScannerViewState createState() => ScannerViewState();
}

class ScannerViewState extends ConsumerState<ScannerView> {
  final MobileScannerController controller = MobileScannerController();
  bool oneScanned = false;
  Map<String, DateTime> scannedPackagesTimestamps = {};
  Position? lastPosition;
  bool disableCamera = false;
  String? lastErrorColisId; // Track the last colis ID that showed an error

  @override
  void initState() {
    super.initState();
    _fetchLastPosition();
  }

  Future<void> _fetchLastPosition() async {
    final position = await ref.read(positionProvider.future);
    if (!mounted) return;
    lastPosition = position;
    setState(() {}); // Update the UI after fetching the position
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (disableCamera) {
      safePrint("Camera is disabled, skipping scan");
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    safePrint("Scan detected - Phase: ${widget.isDeliveringPhase ? 'Delivery' : 'Pickup'}");
    
    _processScan(barcodes);
  }

  Future<void> _processScan(List<Barcode> barcodes) async {
    for (final barcode in barcodes) {
      if (!mounted) return;
      final scannedId = barcode.rawValue;
      if (scannedId == null) {
        safePrint("Null barcode detected");
        continue;
      }

      safePrint("Processing barcode: $scannedId");

      if (scannedPackagesTimestamps.containsKey(scannedId)) {
        final lastScanTime = scannedPackagesTimestamps[scannedId]!;
        final now = DateTime.now();
        final difference = now.difference(lastScanTime);

        if (difference.inSeconds < 3) {
          safePrint("Colis $scannedId scanned recently (${difference.inSeconds}s ago), ignoring.");
          continue;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ce colis a déjà été scanné"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
          scannedPackagesTimestamps[scannedId] = now;
          continue;
        }
      }

      // Select the correct provider based on the phase
      final providerToUpdate = widget.isDeliveringPhase
          ? colisInTourneeDeliveryPhaseProvider
          : colisInTourneeProvider;

      // Get the current state
      final listColisInTournee = ref.read(providerToUpdate);
      if (listColisInTournee.isEmpty) {
        safePrint("No colis in tournee to process");
        continue;
      }

      bool oneUpdated = false;
      final isColisId = listColisInTournee.any((colisTournee) => colisTournee.colis.id == scannedId);

      if (isColisId) {
        final colis = listColisInTournee.firstWhere((c) => c.colis.id == scannedId);

        if (colis.isScanned) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ce colis a déjà été scanné"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
          scannedPackagesTimestamps[scannedId] = DateTime.now();
        }

        bool isGoodGeoloc = true;
        if (widget.isDeliveringPhase) {
          // Fetch fresh GPS position like the GPS button does
          try {
            LocationAccuracyStatus accuracyStatus = await Geolocator.getLocationAccuracy();
            
            if (accuracyStatus == LocationAccuracyStatus.reduced) {
              accuracyStatus = await Geolocator.requestTemporaryFullAccuracy(
                purposeKey: "DeliveryVerification", // Must match the key in Info.plist
              );
              
              if (accuracyStatus == LocationAccuracyStatus.reduced) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Veuillez activer la précision maximale dans les paramètres iOS pour valider'),
                    duration: Duration(seconds: 3),
                  ));
                }
                return;
              }
            }
            Position freshPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 10),
            );
            if (freshPosition.accuracy > 50) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Précision GPS insuffisante (${freshPosition.accuracy.toStringAsFixed(0)}m). Veuillez réessayer.'),
                  duration: Duration(seconds: 3),
                ));
              }
              return;
            }
            isGoodGeoloc = listColisInTournee.any((colisInTournee) {
              return (colisInTournee.colis.id == scannedId && _checkGps(freshPosition, colisInTournee.colis));
            });
          } catch (e) {
            safePrint("Error getting GPS position during scan: $e");
            isGoodGeoloc = false;
          }
        }

        if (isGoodGeoloc && !colis.isScanned) {
          try {
            final updatedList = listColisInTournee.map((colis) {
              return colis.colis.id == scannedId
                  ? colis.copyWith(isScanned: true)
                  : colis;
            }).toList();
            ref.read(providerToUpdate.notifier).updateColisInTournee(updatedList);
            oneUpdated = true;
            safePrint("Successfully updated colis with ID: $scannedId");
            lastErrorColisId = null;
          } catch (e) {
            safePrint("Error updating colis: $e");
          }
        } else if(!isGoodGeoloc) {
          safePrint("Geolocation check failed for colis: $scannedId");
          if (lastErrorColisId != scannedId) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Vous êtes trop loin pour valider le colis (plus de 50m)'),
              duration: Duration(seconds: 1),
            ));
            lastErrorColisId = scannedId;
          }
        }
      } else {
        final filteredList = listColisInTournee.where(
          (colisInTournee) => colisInTournee.colis.subscriber?.numabo == scannedId
        ).toList();

        if (filteredList.isEmpty) {
          safePrint("No matching colis found for scanned ID: $scannedId");
          continue;
        }

        final String? nameNumAbo = filteredList.first.colis.subscriberName;
        List<ColisInTournee> colisWithCheckedGPS = [];
        
        if (!widget.isDeliveringPhase) {
          colisWithCheckedGPS = filteredList;
        } else {
          // Fetch fresh GPS position like the GPS button does
          try {
            LocationAccuracyStatus accuracyStatus = await Geolocator.getLocationAccuracy();
            
            if (accuracyStatus == LocationAccuracyStatus.reduced) {
              accuracyStatus = await Geolocator.requestTemporaryFullAccuracy(
                purposeKey: "DeliveryVerification", // Must match the key in Info.plist
              );
              
              if (accuracyStatus == LocationAccuracyStatus.reduced) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Veuillez activer la précision maximale dans les paramètres iOS pour valider'),
                    duration: Duration(seconds: 3),
                  ));
                }
                return;
              }
            }
            Position freshPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 10),
            );
            if (freshPosition.accuracy > 50) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Précision GPS insuffisante (${freshPosition.accuracy.toStringAsFixed(0)}m). Veuillez réessayer.'),
                  duration: Duration(seconds: 3),
                ));
              }
              return;
            }
            colisWithCheckedGPS = filteredList.where(
              (colisInTournee) => _checkGps(freshPosition, colisInTournee.colis)
            ).toList();
          } catch (e) {
            safePrint("Error getting GPS position during subscriber scan: $e");
            colisWithCheckedGPS = [];
          }
        }

        if (nameNumAbo != null && colisWithCheckedGPS.isNotEmpty) {
          try {
            List<String> colisIdsToValidate = colisWithCheckedGPS
                .map((colisInTournee) => colisInTournee.colis.id)
                .toList();
            
            final updatedList = listColisInTournee.map((colisInTournee) {
              return (colisInTournee.colis.subscriberName == nameNumAbo &&
                      colisIdsToValidate.contains(colisInTournee.colis.id ?? "-1"))
                  ? colisInTournee.copyWith(isScanned: true)
                  : colisInTournee;
            }).toList();
            
            ref.read(providerToUpdate.notifier).updateColisInTournee(updatedList);
            oneUpdated = true;
            safePrint("Successfully updated colis with subscriber: $nameNumAbo");
          } catch (e) {
            safePrint("Error updating colis by subscriber: $e");
          }
        }
      }

      if (oneUpdated) {
        if (!mounted) return;
        setState(() {
          oneScanned = true;
          scannedPackagesTimestamps[scannedId] = DateTime.now();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Le colis $scannedId a bien été scanné!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }


  Future<void> _onNext() async {
    // Guard re-enabled (was dead-coded with `if (false)`): warn when nothing
    // was scanned or GPS-validated, but let the driver confirm - proceeding
    // with zero scans is legitimate when the colis are genuinely absent.
    final listColisInTournee = ref.read(widget.isDeliveringPhase
        ? colisInTourneeDeliveryPhaseProvider
        : colisInTourneeProvider);
    final anyValidated = listColisInTournee
        .any((colis) => colis.isScanned || colis.isValidatedByGPS);

    if (!anyValidated) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Aucun colis scanné"),
            content: Text(widget.isDeliveringPhase
                ? "Aucun colis n'a été scanné ou validé par GPS. Voulez-vous vraiment continuer ?"
                : "Aucun colis n'a été scanné. Les colis non scannés seront marqués comme non récupérés. Voulez-vous vraiment continuer ?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Non"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Oui"),
              ),
            ],
          );
        },
      );
      if (shouldContinue != true) return;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).myId;
    if (userId == null) {
      return const Center(child: Text("User authentication required!"));
    }
    final listColisInTournee = widget.isDeliveringPhase
        ? ref.watch(colisInTourneeDeliveryPhaseProvider) 
        : ref.watch(colisInTourneeProvider);
    safePrint("listColisInTournee: ${listColisInTournee.length}");
    // Show loading indicator while data is being loaded
    if (listColisInTournee.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Chargement des colis..."),
          ],
        ),
      );
    }

    final tourneeId = listColisInTournee[0].colis.tournee?.id;
    if (tourneeId == null) {
      return const ErrorScreen("Tournée non trouvée");
    }
    final tournee = ref.read(tourneeProvider(userId).notifier).getTournee(tourneeId);
    if (tournee == null) {
      return const ErrorScreen("Tournée non trouvée");
    }
    final bool? deliveryChecking = tournee.deliveryChecking;

    return Column(
      children: [
        const Divider(color: Colors.white, height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey[200], // Light grey background for better visibility
          ),
          child: const Text(
            "Veuillez scanner les colis",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // **Visual Separation Between Sections**
        const Divider(thickness: 4, height: 10), // Thicker divider for clarity
        Expanded(
          flex: 5,
          child: MobileScanner(
            controller: controller,
            onDetect: _onDetect,
            overlay: null,//const ScannerOverlay(
              //borderColor: C.primary,
              //borderRadius: 10,
              //borderLength: 30,
              //borderWidth: 10,
              //cutOutSize: 300,
            //),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:[
                if(widget.isDeliveringPhase) _getBtnGps(context, ref, listColisInTournee,deliveryChecking),
                if(widget.isDeliveringPhase) const SizedBox(height: 20),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children:[
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // ✅ Go back to the previous page
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), // Optional: change button color
                        child: const Text("Retour"), // "Back" button
                      ),
                      ElevatedButton(
                        onPressed: _onNext,
                        child: const Text("Suivant"),
                      ),
                    ]
                ),
              ]
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> warningMessageTourneeSecurisee(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Vérification"),
          content: const Text("Cette tournée nécessite le scan des colis. Voulez-vous continuer en reportant une erreur et en validant par GPS ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // ❌ No
              child: const Text("Non"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // ✅ Yes
              child: const Text("Oui"),
            ),
          ],
        );
      },
    ) ?? false;
  }

  _checkGps(Position? lastPosition, Colis colis) {
    if (lastPosition != null) {
      var distance = Geolocator.distanceBetween(
          lastPosition.latitude,
          lastPosition.longitude,
          colis.latitude,
          colis.longitude);
      safePrint("VALIDATION GPS DISTANCEEEEE $distance IDDDDD : ${colis.id}");
      if ( !widget.isDeliveringPhase || ( widget.isDeliveringPhase && distance < 75) ){
        return true;
      }
      else {
        return false;
      }
    } else {
      safePrint("No position available.");
      return false;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  _getBtnGps(BuildContext context, WidgetRef ref, List<ColisInTournee> listColisInTournee, bool? deliveryChecking)  {
    return
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: C.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          onPressed: () async {
            bool isContinue = false;
            if (deliveryChecking ?? false) {
              isContinue = await warningMessageTourneeSecurisee(context) ?? false;
            } else {
              isContinue = true;
            }
            if (!isContinue) {
              return;
            }

            List<String> colisIdsValidated = [];
            ref.read(loadingProvider.notifier).state = true;
            
            if (!mounted) {
              ref.read(loadingProvider.notifier).state = false;
              return;
            }

            try {

              LocationAccuracyStatus accuracyStatus = await Geolocator.getLocationAccuracy();
            
              if (accuracyStatus == LocationAccuracyStatus.reduced) {
                accuracyStatus = await Geolocator.requestTemporaryFullAccuracy(
                  purposeKey: "DeliveryVerification", // Must match the key in Info.plist
                );
                
                if (accuracyStatus == LocationAccuracyStatus.reduced) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Veuillez activer la précision maximale dans les paramètres iOS pour valider'),
                      duration: Duration(seconds: 3),
                    ));
                  }
                  return;
                }
              }
              // Get current position directly from Geolocator
              Position lastPosition = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.best, // Changed from high to best
                timeLimit: Duration(seconds: 10), // Add timeout
              );

              bool hasColisTooFar = false;
              for(int i=0; i< listColisInTournee.length; i++){
                var colis = listColisInTournee[i].colis;
                var distance = Geolocator.distanceBetween(
                    lastPosition.latitude,
                    lastPosition.longitude,
                    colis.latitude,
                    colis.longitude);
                if ( !widget.isDeliveringPhase || ( widget.isDeliveringPhase && distance < 75) ) {
                  colisIdsValidated.add(colis.id);
                } else {
                  hasColisTooFar = true;
                }
              }

              
              // Show distance error if any colis is too far
              if (hasColisTooFar) {
                if (lastPosition.accuracy > 50) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Précision GPS insuffisante (${lastPosition.accuracy.toStringAsFixed(0)}m). Veuillez réessayer.'),
                      duration: Duration(seconds: 3),
                    ));
                  }
                  return;
                }
                _showSnackBar('Vous êtes trop loin pour valider certains colis (plus de 50m)');
              }
              
              // Update colis that are within range
              if (colisIdsValidated.isNotEmpty) {
                List<ColisInTournee> updatedList;
                if(deliveryChecking != true){
                  updatedList = listColisInTournee.map((colisTournee) {
                    return colisIdsValidated.contains(colisTournee.colis.id)
                        ? colisTournee.copyWith(isScanned: true)
                        : colisTournee;
                  }).toList();
                }else{
                  updatedList = listColisInTournee.map((colisTournee) {
                    return colisIdsValidated.contains(colisTournee.colis.id)
                        ? colisTournee.copyWith(isValidatedByGPS: true)
                        : colisTournee;
                  }).toList();
                }

                ref.read(colisInTourneeDeliveryPhaseProvider.notifier).updateColisInTournee(updatedList);
                if (!hasColisTooFar) {
                  _showSnackBar('Colis bien validés, veuillez passer à l\'étape suivante.');
                }
              }
            } catch (e) {
              safePrint("Error getting GPS position: $e");
              _showSnackBar('Impossible de valider le colis avec votre GPS');
            } finally {
              ref.read(loadingProvider.notifier).state = false;
            }
          },
          child: const Center(
            child: Text(
              "Validation par GPS",
              style: TextStyle(color: C.white, fontSize: 18),
            ),
          ),
        )
      );
  }


}
