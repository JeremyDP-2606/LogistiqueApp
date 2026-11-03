import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wabap/screen/error_screen.dart';

import 'package:wabap/colors.dart';
import 'package:wabap/models/Colis.dart';
import 'package:wabap/models/Status.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/provider/tournee_provider.dart';
import 'package:wabap/provider/colis_provider.dart';
import 'package:wabap/provider/location_provider.dart';
import 'package:wabap/screen/preuve_livraison/signature_view.dart';
import 'package:wabap/provider/colis_tournee_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScreen extends ConsumerStatefulWidget {
  final Colis colis;

  QrScreen({required this.colis, Key? key}) : super(key: key);

  @override
  QrScreenState createState() => QrScreenState();
}

class QrScreenState extends ConsumerState<QrScreen> {
  final MobileScannerController controller = MobileScannerController();
  final loadingProvider = StateProvider.autoDispose<bool>((ref) => false);
  bool disableCamera = false;
  String? lastScannedCode = "";
  Position? _initialPosition;
  bool _isGettingPosition = true;


  Future<void> _getInitialPosition() async {
    setState(() {
      _isGettingPosition = true;
    });

    try {
      // Use the same simple approach as colis_pickup_scanner_view.dart
      _initialPosition = await ref.read(positionProvider.future);
      safePrint("Initial position: $_initialPosition");
    } catch (e) {
      safePrint("Error getting position: $e");
      _initialPosition = null;
    } finally {
      if (mounted) {
        setState(() {
          _isGettingPosition = false;
        });
      }
    }
  }




  @override
  void dispose() {
    controller.dispose();// Ensure the camera stops when leaving the screen
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getInitialPosition(); // Fetch GPS on screen open
  }

  void _showSignatureAndReport(BuildContext context, WidgetRef ref, String colisId, bool isScanned, bool isGps) {
    ref.read(colisInTourneeDeliveryPhaseProvider.notifier).updateColisInTournee([
      ColisInTournee(colis: widget.colis, isScanned: isScanned, isValidatedByGPS: isGps),
    ]);

    controller.stop();
    disableCamera = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text("Signature")),
          body: SignatureView(isDeliveringPhase: true, isColisStatic: false),
        ),
      ),
    ).then((_) {
      controller.start();
    });
    disableCamera = false;
  }




  // Method to update the colis status.
  void _updateStatusColis(Status status, BuildContext context, WidgetRef ref, {String? message}) async {
    try {
      ref.read(loadingProvider.notifier).state = true;
      var clientName = ref.read(authProvider.notifier).clientName;
      if (clientName == null) throw Exception("clientName null");
      //var lastPosition = await ref.read(positionProvider.future);
      var lastPosition = _initialPosition;
      await ref
          .read(colisProvider(widget.colis.tournee.id).notifier)
          .updateStatusColis(status, widget.colis, message: message, position: lastPosition);
      // The backend triggerColisStatus Lambda flips the next PENDING colis to
      // IN_PROGRESS; the list shows it on the next reload. (The old local-only
      // updateFirstPending was reverted by every refetch and was removed.)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Colis bien mis à jour'),
        ));
        Navigator.of(context).pop();
      }
    } catch (error) {
      safePrint("ERROR : $error");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error : Impossible de mettre à jour le colis ($error)'),
        ));
      }
    } finally {
      ref.read(loadingProvider.notifier).state = false;
      disableCamera = false;
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (disableCamera) return;
    disableCamera = true;
    try {
      final List<Barcode> barcodes = capture.barcodes;
      for (final barcode in barcodes) {
        final scannedCode = barcode.rawValue;
        if (scannedCode == null) {
          safePrint("Null barcode detected");
          continue;
        }
        if (scannedCode == lastScannedCode){
          return;
        }else{
          lastScannedCode = scannedCode;
        }
        safePrint("CODE SCANNE : $scannedCode");

        if (scannedCode == widget.colis.subscriber?.numabo) {
          _updateStatusColis(Status.COMPLETED, context, ref);
        } else if (scannedCode == widget.colis.id) {
          ref.read(loadingProvider.notifier).state = true;
          
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

            if (!mounted) {
              ref.read(loadingProvider.notifier).state = false;
              return;
            }

            if (lastPosition.accuracy > 50) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Précision GPS insuffisante (${lastPosition.accuracy.toStringAsFixed(0)}m). Veuillez réessayer.'),
                  duration: Duration(seconds: 3),
                ));
              }
              return;
            }

            var distance = Geolocator.distanceBetween(
              lastPosition.latitude,
              lastPosition.longitude,
              widget.colis.latitude,
              widget.colis.longitude,
            );

            if (distance < 75) {
              safePrint("GOOOOOOOOOOOOOOOOOOD DISTANCE : $distance");
              if (mounted) {
                _showSignatureAndReport(context, ref, widget.colis.id, true, false);
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Vous êtes trop loin pour valider le colis (plus de 50m)'),
                  duration: Duration(seconds: 1),
                ));
              }
            }
          } catch (e) {
            safePrint("Error getting position during QR scan: $e");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Impossible de valider le colis avec votre GPS'),
                duration: Duration(seconds: 1),
              ));
            }
          } finally {
            ref.read(loadingProvider.notifier).state = false;
          }
        } else {
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('QR Code incorrect'),
                  content: Text(
                    'Le QR Code scanné ne correspond pas à celui de la boite aux lettres de : ${widget.colis.subscriber?.name ?? "inconnu"}',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        disableCamera = false;
                      },
                      child: const Text('Fermer'),
                    ),
                  ],
                );
              },
            );
          }
        }
      }
      disableCamera = false;
    } catch (e) {
      safePrint("Error during QR scan: $e");
    } finally {
      disableCamera = false;
    }
  }

  void _validateWithGps() async {
    if (!mounted) return;
    ref.read(loadingProvider.notifier).state = true;
    
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
      
      if (!mounted) {
        ref.read(loadingProvider.notifier).state = false;
        return;
      }

      if (lastPosition.accuracy > 50) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Précision GPS insuffisante (${lastPosition.accuracy.toStringAsFixed(0)}m). Veuillez réessayer.'),
            duration: Duration(seconds: 3),
          ));
        }
        return;
      }

      var distance = Geolocator.distanceBetween(
        lastPosition.latitude,
        lastPosition.longitude,
        widget.colis.latitude,
        widget.colis.longitude,
      );
      
      if (distance < 75) {
        if (mounted) {
          _showSignatureAndReport(context, ref, widget.colis.id, false, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Vous êtes trop loin pour valider le colis (plus de 50m)'),
            duration: Duration(seconds: 1),
          ));
        }
      }
    } catch (e) {
      safePrint("Error in GPS validation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible de valider le colis avec votre GPS'),
          duration: Duration(seconds: 1),
        ));
      }
    } finally {
      if (mounted) {
        ref.read(loadingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    safePrint(">>>> BUILD QrScreen");
    final loading = ref.watch(loadingProvider);

    if (_isGettingPosition) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final userId = ref.watch(authProvider).myId ?? "";
    final tourneeId = widget.colis.tournee.id;
    if (tourneeId == null) {
      return const ErrorScreen("Tournée non trouvée");
    }
    final tournee = ref.read(tourneeProvider(userId).notifier).getTournee(tourneeId);
    if (tournee == null) {
      return const ErrorScreen("Tournée non trouvée");
    }
    final bool? deliveryChecking = tournee.deliveryChecking;

    return PopScope(
      canPop: !loading,
      child: Scaffold(
        body: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              overlay: null,
            ),
            if (!loading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      controller.stop();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 200, left: 200),
                child: FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    controller.toggleTorch();
                  },
                  shape: const CircleBorder(),
                  child: const Icon(Icons.flash_on),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deliveryChecking == true
                                ? "Veuillez scanner le QR Code du colis de :"
                                : "Veuillez scanner le QR Code de la boite aux lettres de :",
                            style: const TextStyle(fontSize: 20, color: C.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.person, color: C.white, size: 22),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  widget.colis.subscriber?.name ?? "inconnu",
                                  style: const TextStyle(fontSize: 18, color: C.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: C.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                      },
                      child: const Center(
                        child: Text(
                          "Fermer",
                          style: TextStyle(color: C.white, fontSize: 18),
                        ),
                      ),
                    ),
                    
                    // NEW BUTTON FOR DELIVERY CHECKING TOURNEES
                    if (deliveryChecking == true) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: C.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                              side: const BorderSide(
                                color: C.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          onPressed: _validateWithGps,
                          child: const Center(
                            child: Text(
                              "Validation par GPS",
                              style: TextStyle(color: C.white, fontSize: 18),
                            ),
                          ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: C.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                            side: const BorderSide(
                              color: C.error,
                              width: 2,
                            ),
                          ),
                        ),
                        onPressed: () {
                          _showSignatureAndReport(context, ref, widget.colis.id, false, false);
                        },
                        child: const Center(
                          child: Text(
                            "Echec des validations ?",
                            style: TextStyle(color: C.white, fontSize: 18),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: C.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                            side: const BorderSide(
                              color: C.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onPressed: () async {
                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                title: const Text('Un problème ?'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 20),
                                    _getBtnProbleme("Valider avec le GPS", dialogContext, context, action: () async {
                                      ref.read(loadingProvider.notifier).state = true;
                                      
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

                                        if (lastPosition.accuracy > 50) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                              content: Text('Précision GPS insuffisante (${lastPosition.accuracy.toStringAsFixed(0)}m). Veuillez réessayer.'),
                                              duration: Duration(seconds: 3),
                                            ));
                                          }
                                          return;
                                        }
                                        
                                        var distance = Geolocator.distanceBetween(
                                          lastPosition.latitude,
                                          lastPosition.longitude,
                                          widget.colis.latitude,
                                          widget.colis.longitude,
                                        );
                                        if (distance < 75) {
                                          if (dialogContext.mounted && context.mounted) {
                                            _updateStatusColis(Status.COMPLETED, context, ref,
                                                message: "Validé sans QR code");
                                          }
                                        } else {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                              content: Text('Vous êtes trop loin pour valider le colis (plus de 50m)'),
                                              duration: Duration(seconds: 1),
                                            ));
                                          }
                                          ref.read(loadingProvider.notifier).state = false;
                                        }
                                      } catch (e) {
                                        safePrint("Error in GPS validation (problem dialog): $e");
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                            content: Text('Impossible de valider le colis avec votre GPS'),
                                            duration: Duration(seconds: 1),
                                          ));
                                        }
                                        ref.read(loadingProvider.notifier).state = false;
                                      }
                                    }),
                                    const SizedBox(height: 20),
                                    _getBtnProbleme("QR code absent", dialogContext, context,
                                        ref: ref, textBtn: "QR code absent ?"),
                                    const SizedBox(height: 20),
                                    _getBtnProbleme("Adresse introuvable", dialogContext, context,
                                        ref: ref, textBtn: "Adresse introuvable ?"),
                                    const SizedBox(height: 20),
                                    _getBtnProbleme("Livré, mais pas validé", dialogContext, context,
                                        ref: ref, textBtn: "Livré, mais pas validé ?"),
                                  ],
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                    },
                                    child: const Text('Fermer'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: const Text(
                          "Un problème ?",
                          style: TextStyle(color: C.white, fontSize: 18),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            if (loading)
              Container(
                decoration: const BoxDecoration(color: C.overlay),
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), color: C.overlay),
                    child: const Padding(
                      padding: EdgeInsets.all(30.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  _getBtnProbleme(message, dialogContext, context, {ref, action, textBtn}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: C.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      onPressed: () async {
        Navigator.of(dialogContext).pop();
        if (action != null) {
          action();
        }
        if (ref != null) {
          _updateStatusColis(Status.ISSUE, context, ref, message: message);
        }
      },
      child: Center(
        child: Text(
          textBtn ?? message,
          style: const TextStyle(color: C.white, fontSize: 18),
        ),
      ),
    );
  }
}
