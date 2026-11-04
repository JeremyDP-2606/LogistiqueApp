import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/provider/colis_tournee_provider.dart';
import 'package:wabap/widgets/item_colis_tournee.dart';
import 'package:wabap/models/Status.dart';
import 'package:wabap/provider/colis_provider.dart';

import 'dart:ui' as ui;
import 'package:wabap/models/Tournee.dart';
import 'package:wabap/provider/tournee_provider.dart';
import 'package:wabap/provider/location_provider.dart';
import 'package:wabap/backend/backend.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:pool/pool.dart';
import 'package:uuid/uuid.dart';
import 'package:wabap/services/colis_status_sync_service.dart';
import 'package:wabap/utils/retry.dart';




class SignatureView extends ConsumerStatefulWidget {
  final void Function()? onPrevious;
  final bool isDeliveringPhase;
  final bool? isColisStatic;
  final Tournee? tournee;

  const SignatureView({
    super.key,
    this.isColisStatic,
    this.onPrevious,
    required this.isDeliveringPhase,
    this.tournee,
  });

  @override
  ConsumerState<SignatureView> createState() => _SignatureViewState();
}

class _SignatureViewState extends ConsumerState<SignatureView> {
  late final SignatureController _signatureController;
  late final ValueNotifier<bool> isLoading;
  final ValueNotifier<int> progressCount = ValueNotifier<int>(0);
  int totalColis = 0;
  late final ValueNotifier<String?> errorMessage;
  Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController();
    isLoading = ValueNotifier<bool>(false);
    errorMessage = ValueNotifier<String?>(null);
    _preloadData();
  }

  @override
  void dispose() {
    safePrint("SignatureView disposing...");
    
    // Cancel any ongoing operations
    isLoading.value = false;
    errorMessage.value = null;
    
    // Dispose controllers
    _signatureController.dispose();
    isLoading.dispose();
    errorMessage.dispose();
    
    safePrint("SignatureView disposed successfully");
    super.dispose();
  }

  Future<void> _preloadData() async {
    try {
      // Use longer timeout for France-Antilles (same as QR screen fix)
      _lastPosition = await ref.read(positionProvider.future).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          safePrint("⏰ Position fetch timed out after 15s");
          return null;
        },
      );
      safePrint("📍 Position loaded: $_lastPosition");
    } catch (e) {
      safePrint("⚠️ Error fetching position: $e");
      _lastPosition = null;
    }
  }


  bool isColisAccepted(ColisInTournee colisInTournee) {
    if ((colisInTournee.isScanned || colisInTournee.isValidatedByGPS) && colisInTournee.damaged == "") {
      return true;
    } else if (colisInTournee.damaged.toLowerCase().contains("validee") ) {
      safePrint("COLIS ACCEPTED with damaged: ${colisInTournee.damaged} and id: ${colisInTournee.colis.id}");
      return true;
    } else {
      return false;
    }
  }

  Future<void> validateDeliveryColis() async {

    safePrint("BEGINING VALIDATION OF DELIVERY");final listColisInTournee = ref.read(colisInTourneeDeliveryPhaseProvider);
    safePrint("NB OF COLIS TO VALIDATE : ${listColisInTournee.length}");

    if (listColisInTournee.isEmpty) {
      safePrint("ERROR: No colis to validate!");
      throw Exception("No colis to validate");
    }
    totalColis = listColisInTournee.length;
    progressCount.value = 0;

    safePrint("First colis details: ${listColisInTournee[0].colis.id}");
    final tourneeId = listColisInTournee[0].colis.tournee.id;
    safePrint("Tournee ID: $tourneeId");
    final pool = Pool(5);

    // Capture the signature ONCE (rendering it per colis wasted memory), so it
    // can be persisted to disk before any upload attempt.
    Uint8List? signatureBytes;
    if (_signatureController.isNotEmpty) {
      signatureBytes = await _captureSignatureBytes();
    }

    try {
      final statusFutures = <Future>[];
      final imageFutures = <Future>[];
      final signatureFutures = <Future>[];

      for (int i = 0; i < listColisInTournee.length; i++) {
        final colisInTournee = listColisInTournee[i];
        safePrint("Processing colis ${i + 1}/${listColisInTournee.length}");
        safePrint("COLIS IS PROCEESSEEEDDDDD");
        var message = "";
        if (colisInTournee.isValidatedByGPS) {
          message = (colisInTournee.damaged).isEmpty
              ? "Validation GPS"
              : "Validation GPS, ${colisInTournee.damaged ?? ""}";
        } else if (colisInTournee.isScanned) {
          message = (colisInTournee.damaged).isEmpty
              ? "Scanné"
              : "Scanné, ${colisInTournee.damaged ?? ""}";
        } else {
          message = (colisInTournee.damaged).isEmpty
              ? ""
              : colisInTournee.damaged ?? "";
        }

        Status statusColis = Status.COMPLETED;
        if (!isColisAccepted(colisInTournee)) {
          statusColis = Status.ISSUE;
        }
        final statusClientId = const Uuid().v4();
        final statusFuture = pool.withResource(() async {
          try {
            await retryWithBackoff(
                () => ref
                    .read(colisProvider(tourneeId).notifier)
                    .updateStatusColis(
                      statusColis,
                      colisInTournee.colis,
                      message: message,
                      position: _lastPosition,
                      clientId: statusClientId,
                    )
                    .timeout(const Duration(seconds: 10)),
                retryIf: isRetryableError);
          } catch (e) {
            // The status is safe in the local queue; the sync service will retry.
            safePrint("Status update failed for colis ${colisInTournee.colis.id} even after retry (kept in local queue): $e");
          } finally {
            progressCount.value++;
          }
        });
        statusFutures.add(statusFuture);

        if (colisInTournee.image != null) {
          final imageFuture = pool.withResource(() async {
            try {
              // Persisted to disk + queued: a failed upload is replayed later
              // by the sync service instead of being lost.
              await _sendPackagePicture(
                colisInTournee.colis.id,
                colisInTournee.colis.subscriberName,
                tourneeId,
                colisInTournee.image!,
              );
            } catch (e) {
              safePrint("Image persistence failed for colis ${colisInTournee.colis.id}: $e");
            }
          });
          imageFutures.add(imageFuture);
        }
        if (signatureBytes != null) {
          final bytes = signatureBytes;
          final signatureFuture = pool.withResource(() async {
            try {
              await _sendPackageSignature(
                bytes,
                colisInTournee.colis.id,
                colisInTournee.colis.subscriberName,
                tourneeId,
              );
            } catch (e) {
              safePrint("Signature persistence failed for colis ${colisInTournee.colis.id}: $e");
            }
          });
          signatureFutures.add(signatureFuture);
        }
      }
      await Future.wait([
        ...statusFutures,
        ...imageFutures,
        ...signatureFutures,
      ]);
      await pool.close();

      // Replay anything that didn't make it through the burst.
      ColisStatusSyncService.instance.tryFlush(force: true);

      // Use helper methods for proper cleanup
      await _ensureProviderCleanup();
      await _safeReloadColis(tourneeId);
      
    } catch (e) {
      await pool.close();
      
      // Use helper methods for proper cleanup even on error
      await _ensureProviderCleanup();
      await _safeReloadColis(tourneeId);
      
      errorMessage.value = '❌ Upload failed: $e';
    }
  }

  Future<void> validatePickingUpColis() async {
    final listColisInTournee = ref.read(colisInTourneeProvider);
    final tourneeId = listColisInTournee[0].colis.tournee.id;
    final statusFutures = <Future>[];
    final imageFutures = <Future>[];
    totalColis = listColisInTournee.length;
    progressCount.value = 0;
    // Lower concurrency than before (was 15): with ~200 colis on a weak link,
    // fewer parallel requests saturate the uplink less and succeed more often.
    final pool = Pool(8);

    for (int i = 0; i < listColisInTournee.length; i++) {
      final colisInTournee = listColisInTournee[i];
      safePrint("Processing colis ${i + 1}/${listColisInTournee.length}");

      final statusFuture = pool.withResource(() async {
        try {
          Status statusColis = Status.PENDING;

          if (isColisAccepted(colisInTournee)) {
            statusColis = Status.PICKED_UP;
          } else if (colisInTournee.damaged.toLowerCase().contains("refuse")) {
            statusColis = Status.ISSUE;
          } else if (!colisInTournee.isScanned) {
            statusColis = Status.NOT_PICKED_UP_NOT_EXIST;
          } else {
            statusColis = Status.ISSUE;
          }
          try {
            final statusClientId = const Uuid().v4();
            await retryWithBackoff(
                () => ref
                    .read(colisProvider(tourneeId).notifier)
                    .updateStatusColis(
                      statusColis,
                      colisInTournee.colis,
                      message: colisInTournee.damaged,
                      clientId: statusClientId,
                    )
                    .timeout(const Duration(seconds: 10)),
                retryIf: isRetryableError);
          } catch (e) {
            // The status is safe in the local queue; the sync service will retry.
            safePrint("Status update failed for colis ${colisInTournee.colis.id} even after retry (kept in local queue): $e");
          }
        } catch (e) {
          safePrint("Status update failed for colis ${colisInTournee.colis.id}: $e");
        } finally {
          progressCount.value++;
        }
      });
      statusFutures.add(statusFuture);

      if (colisInTournee.image != null) {
        final imageFuture = pool.withResource(() async {
          try {
            // Persisted to disk + queued: a failed upload is replayed later by
            // the sync service instead of being lost.
            await _sendPackagePicture(
              colisInTournee.colis.id,
              colisInTournee.colis.subscriberName,
              tourneeId,
              colisInTournee.image!,
            );
          } catch (e) {
            safePrint("Image persistence failed for colis ${colisInTournee.colis.id}: $e");
          }
        });
        imageFutures.add(imageFuture);
      }
    }
    // Run all uploads in parallel
    try {
      await Future.wait([...statusFutures, ...imageFutures]);
    } catch (e) {
      safePrint("Error in one or more futures: $e");
    }
    await pool.close();

    // Replay anything that didn't make it through the burst.
    ColisStatusSyncService.instance.tryFlush(force: true);

    // Clear the pickup provider first
    ref.read(colisInTourneeProvider.notifier).updateColisInTournee([]);
    
    // Handle signature upload if present (persisted to disk + queued).
    if (_signatureController.isNotEmpty) {
      try {
        final signatureBytes = await _captureSignatureBytes();
        if (signatureBytes != null) {
          await _sendPackageSignature(signatureBytes, "", "", tourneeId);
        }
      } catch (e) {
        safePrint("Signature persistence failed: $e");
      }
    }

    // Update tournee status if needed
    if (context.mounted) {
      final userId = ref.read(authProvider).myId;
      if (userId != null && widget.tournee != null) {
        // Local-first: the intent is persisted and replayed by the sync
        // service if the push fails, so no retry wrapper is needed anymore.
        await ref
            .read(tourneeProvider(userId).notifier)
            .updateStatus(Status.IN_PROGRESS, widget.tournee!);
      } else {
        safePrint("Error: userId or tournee is null!");
      }
    }
    
    // Use helper methods for proper cleanup
    await _ensureProviderCleanup();
    await _safeReloadColis(tourneeId);
  }

  String sanitizeFileName(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9-_]'), '_');
  }

  // Helper method to ensure proper cleanup of providers
  Future<void> _ensureProviderCleanup() async {
    try {
      // Check if widget is still mounted
      if (!mounted) {
        safePrint("Widget disposed, skipping provider cleanup");
        return;
      }
      
      if (widget.isDeliveringPhase) {
        ref.read(colisInTourneeDeliveryPhaseProvider.notifier).updateColisInTournee([]);
      } else {
        ref.read(colisInTourneeProvider.notifier).updateColisInTournee([]);
      }
      
      // Wait to ensure provider update is processed
      await Future.delayed(const Duration(milliseconds: 100));
      
      safePrint("Provider cleanup completed");
    } catch (e) {
      safePrint("Error during provider cleanup: $e");
    }
  }

  // Helper method to safely reload colis data
  Future<void> _safeReloadColis(String tourneeId) async {
    try {
      // Check if widget is still mounted
      if (!mounted) {
        safePrint("Widget disposed, skipping colis reload");
        return;
      }
      
      await ref.read(colisProvider(tourneeId).notifier).loadColis(force: true);
      safePrint("Colis data reloaded successfully");
    } catch (e) {
      safePrint("Error reloading colis data: $e");
      // Don't throw here, just log the error
    }
  }

  /// Renders the signature pad to PNG bytes. Done once per validation - NOT
  /// once per colis - so the proof exists in memory a single time and can be
  /// persisted to disk before any upload attempt.
  Future<Uint8List?> _captureSignatureBytes() async {
    try {
      final signatureImage = await _signatureController.toImage();
      if (signatureImage == null) {
        throw Exception("Failed to capture signature.");
      }
      final byteData = await signatureImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception("Failed to convert signature to bytes.");
      }
      final buffer = byteData.buffer.asUint8List();
      safePrint("📊 Signature size: ${buffer.length} bytes");
      return buffer;
    } catch (e) {
      safePrint("❌ Signature capture failed: $e");
      errorMessage.value = '❌ Signature capture failed: $e';
      return null;
    }
  }

  /// Persists the signature to disk and queues its S3 upload. A failed upload
  /// is retried by [ColisStatusSyncService] (connectivity back, app start...)
  /// instead of being silently lost.
  Future<void> _sendPackageSignature(
      Uint8List signatureBytes, String colisId, String subscriberName, String tourneeId) async {
    try {
      final folder = "tournee_$tourneeId";
      final colisReference = "colis-$colisId";
      final safeSubscriber = sanitizeFileName(subscriberName);
      final subscriberReference = "subscriber-$safeSubscriber";
      final keyImageSignature = widget.isDeliveringPhase
          ? "$folder/signature_delivery_${colisReference}_$subscriberReference.jpg"
          : "$folder/signature_picking.jpg";

      safePrint("📝 Persisting + uploading signature to: $keyImageSignature");
      await ColisStatusSyncService.instance.saveAndUpload(
        s3Key: keyImageSignature,
        tourneeId: tourneeId,
        colisId: colisId.isEmpty ? null : colisId,
        bytes: signatureBytes,
        uploadTimeout: const Duration(seconds: 14),
      );
    } catch (e, stackTrace) {
      // Only disk persistence can throw here; upload failures are queued.
      safePrint("❌ Signature persistence failed: $e");
      safePrint("📚 Stack trace: $stackTrace");
      errorMessage.value = '❌ Signature persistence failed: $e';
    }
  }

  /// Persists the damage photo into an app-owned folder and queues its S3
  /// upload, same lifecycle as the signature.
  Future<void> _sendPackagePicture(String colisId, String subscriberName,
      String tourneeId, File? packageRelatedImg) async {
    if (packageRelatedImg == null) {
      return;
    }

    try {
      final folder = "tournee_$tourneeId";
      const imgType = "package";
      final tourneePhase = widget.isDeliveringPhase ? "delivery" : "picking";
      final colisReference = "colis-$colisId";
      final safeSubscriber = sanitizeFileName(subscriberName);
      final subscriberReference = "subscriber-$safeSubscriber";

      final keyImagePackage = "$folder/${imgType}_${tourneePhase}_${colisReference}_$subscriberReference.jpg";
      safePrint("📝 Persisting + uploading package picture to: $keyImagePackage");
      await ColisStatusSyncService.instance.saveAndUpload(
        s3Key: keyImagePackage,
        tourneeId: tourneeId,
        colisId: colisId,
        sourceFile: packageRelatedImg,
        uploadTimeout: const Duration(seconds: 15),
      );
    } catch (e, stackTrace) {
      safePrint("❌ Package picture persistence failed: $e");
      safePrint("📚 Stack trace: $stackTrace");
      errorMessage.value = '❌ Package picture persistence failed: $e';
    }
  }


  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).myId; // Access the ref here
    final scrollController = ScrollController();
    if (userId == null) {
      return const Center(child: Text("User authentication required!"));
    }
    if (!widget.isDeliveringPhase && widget.tournee == null) {
      return const Center(child: Text("Tournee required when picking-up"));
    }
    final listColisInTournee = widget.isDeliveringPhase
        ? ref.watch(colisInTourneeDeliveryPhaseProvider) : ref.watch(colisInTourneeProvider);
    final scannedCount = listColisInTournee.where((item) => item.isScanned).length;
    return Column(
      children: [
        const Divider(color: Colors.white, height: 10),
        // **Grey Section for Title Above Colis List**
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey[200], // Light grey background for better visibility
          ),
          child: Text(
            "Vérification des colis, $scannedCount scannés",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // **Visual Separation Between Sections**
        const Divider(thickness: 4, height: 10), // Thicker divider for clarity
        // Colis List Section
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 15.0),
                itemCount: listColisInTournee.length,
                itemBuilder: (context, index) {
                  if (index < listColisInTournee.length) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SizedBox(
                          width: constraints.maxWidth,
                          child: ColisInTourneeItem(
                            colisInTournee: listColisInTournee[index],
                            staticItem: widget.isColisStatic ?? true,
                            isDeliveringPhase: widget.isDeliveringPhase,
                          ),
                        );
                      }
                    );
                  }
                  return null;
                },
                separatorBuilder: (context, index) {
                  return const Divider(height: 0.5);
                },
                controller: scrollController,
              ),
            ),
          ),
        ),

        // **Visual Separation Between Sections**
        const Divider(thickness: 4, height: 30), // Thicker divider for clarity

        // Signature Section
        Container(
          padding: const EdgeInsets.all(12.0),
          color: Colors.grey[100],
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.40, // 35% of screen height
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // This will make the Column take minimum required space
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Signature du ${widget.isDeliveringPhase ? 'client' : 'responsable'}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              Flexible(
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.grey[200]!,
                ),
              ),
              const SizedBox(height: 12),
              // 👇 Insert Progress Indicator Here
              ValueListenableBuilder<int>(
                valueListenable: progressCount,
                builder: (context, count, _) {
                  if (!isLoading.value || totalColis == 0) return const SizedBox.shrink();

                  final progress = count / totalColis;
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Text(
                        "Progression: $count / $totalColis colis traités",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  );
                },
              ),
              // Responsive Button Row
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onPrevious ?? () => Navigator.pop(context),
                          child: const Text("Retour"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _signatureController.clear();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            "Effacer",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: isLoading,
                          builder: (context, loading, _) {
                            return ElevatedButton(
                              onPressed: loading ? null : _handleValidationWithSignatureCheck,
                              child: loading 
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text("Valider"),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleValidationWithSignatureCheck() async {
    final userId = ref.read(authProvider).myId ?? "";
    final listColisInTournee = widget.isDeliveringPhase
        ? ref.read(colisInTourneeDeliveryPhaseProvider) : ref.read(colisInTourneeProvider);
    
    if (listColisInTournee.isEmpty) {
      safePrint("ERROR: No colis to validate!");
      throw Exception("No colis to validate");
    }

    final tourneeId = listColisInTournee[0].colis.tournee.id;
    if (tourneeId == null) {
      throw Exception("Tournée non trouvée");
    }

    final tournee = ref.read(tourneeProvider(userId).notifier).getTournee(tourneeId);
    bool deliveryChecking = false;
    if (tournee != null && tournee.deliveryChecking != null) {
      deliveryChecking = tournee.deliveryChecking!;
    }

    final unscannedColis = listColisInTournee.where((colisInTournee) => !colisInTournee.isScanned).toList();
    safePrint("UNSCANNED COLIS: ${unscannedColis.length}");
    String message = "valide";
    if(widget.isDeliveringPhase && _signatureController.isEmpty && unscannedColis.isNotEmpty && deliveryChecking){
      message = "Des colis ne sont pas scannés. \n La livraison nécessite une signature. \n Voulez-vous continuer ?";
    }else if(widget.isDeliveringPhase && _signatureController.isEmpty && unscannedColis.isEmpty && deliveryChecking){
      message = "La livraison nécessite une signature. \n Voulez-vous continuer ?";
    }
    if (message != "valide") {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Signature manquante'),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                child: const Text('Non'),
                onPressed: () {
                  Navigator.of(context).pop(false); // Do not continue
                },
              ),
              TextButton(
                child: const Text('Oui'),
                onPressed: () {
                  Navigator.of(context).pop(true); // Continue
                },
              ),
            ],
          );
        },
      );
      if (shouldContinue != true) {
        // User chose No or dismissed the dialog
        isLoading.value = false;
        return;
      }
  }
  safePrint("BEFORE HANDLE VALIDATION");
  await _handleValidation();
}

  Future<void> _handleValidation() async {
    isLoading.value = true;
    errorMessage.value = null;
    
    try {
      if (widget.isDeliveringPhase) {
        safePrint("DELIVERY PRESSSEEED");
        await validateDeliveryColis();
      } else {
        await validatePickingUpColis();
      }
      
      safePrint("Validation completed successfully");
      
      // Wait longer to ensure all provider updates are fully processed
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Double-check that widget is still mounted and context is valid
      if (mounted && context.mounted) {
        safePrint("IT IS MOUNTED, REDIRECTION IN PROCESS");
        
        try {
          Navigator.of(context).popUntil((route) => route.isFirst);
          safePrint("Navigation completed successfully");
        } catch (navError) {
          safePrint("Navigation error: $navError");
        }
      } else {
        safePrint("Widget or context not mounted, skipping navigation");
      }
    } catch (e) {
      safePrint("ERROR ON THE BUTTON: $e");
      errorMessage.value = "Error: $e";
      
      // Even on error, ensure providers are in a clean state
      try {
        // Check if widget is still mounted before accessing providers
        if (!mounted) {
          safePrint("Widget disposed, skipping cleanup");
          return;
        }
        
        // Get tournee ID for cleanup before clearing providers
        final listColisInTournee = widget.isDeliveringPhase
            ? ref.read(colisInTourneeDeliveryPhaseProvider)
            : ref.read(colisInTourneeProvider);
        
        if (listColisInTournee.isNotEmpty) {
          final tourneeId = listColisInTournee[0].colis.tournee.id;
          
          // Use helper methods for proper cleanup
          await _ensureProviderCleanup();
          await _safeReloadColis(tourneeId);
        }
      } catch (cleanupError) {
        safePrint("Error during cleanup: $cleanupError");
      }
    } finally {
      isLoading.value = false;
    }
  }

}






