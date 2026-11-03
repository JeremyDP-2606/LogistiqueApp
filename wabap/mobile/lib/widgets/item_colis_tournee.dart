import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Ensure this is imported
import 'package:wabap/colors.dart';
import 'package:wabap/models/ModelProvider.dart';
import 'package:wabap/provider/colis_tournee_provider.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:wabap/utils/utils.dart';

/// Runs in a background isolate via [compute]: decoding + re-encoding a full
/// image on the main isolate froze the UI and could OOM with several photos.
Uint8List? _reencodeJpgIsolate(Map<String, Object> args) {
  final bytes = args['bytes'] as Uint8List;
  final quality = args['quality'] as int;
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

class ColisInTourneeItem extends ConsumerStatefulWidget {
  final ColisInTournee? colisInTournee;
  final bool staticItem;
  final Function(List<ColisInTournee>)? updateColis;
  final bool isDeliveringPhase;

  const ColisInTourneeItem({
    super.key,
    required this.colisInTournee,
    required this.staticItem,
    this.updateColis,
    required this.isDeliveringPhase,
  });

  @override
  ConsumerState<ColisInTourneeItem> createState() => _ColisInTourneeItemState();
}

class _ColisInTourneeItemState extends ConsumerState<ColisInTourneeItem> {
  late final ValueNotifier<bool> isLoading;
  late final ValueNotifier<String?> errorMessage;

  @override
  void initState() {
    super.initState();
    isLoading = ValueNotifier<bool>(false);
    errorMessage = ValueNotifier<String?>(null);
  }

  @override
  void dispose() {
    isLoading.dispose();
    errorMessage.dispose();
    super.dispose();
  }

  Future<void> _captureDamageImage(ColisInTournee colisTournee, String damageType) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedFile == null) {
        safePrint("Image picker was cancelled.");
        return;
      }

      final file = File(pickedFile.path);
      int fileSize = await file.length();
      
      File? finalImage;
      try {
        if (fileSize > 1024 * 1024) {
          finalImage = await compressImage(file);
        } else {
          finalImage = file;
        }

        if (finalImage != null) {
          setState(() {
            colisTournee.damaged = damageType;
            colisTournee.image = finalImage;
          });

          final providerToUpdate = widget.isDeliveringPhase
              ? colisInTourneeDeliveryPhaseProvider
              : colisInTourneeProvider;

          widget.updateColis?.call(
            [
              ...ref.read(providerToUpdate.notifier).state.map((colis) {
                if (colis.colis.id == colisTournee.colis.id) {
                  return colis.copyWith(
                    damaged: damageType, 
                    image: finalImage
                  );
                }
                return colis;
              }).toList(),
            ],
          );
        }
      } finally {
        // Clean up the original file if we created a compressed version
        if (finalImage != null && finalImage.path != file.path) {
          try {
            await file.delete();
          } catch (e) {
            safePrint("Error deleting original file: $e");
          }
        }
      }
    } catch (e) {
      safePrint("Error capturing image: $e");
      errorMessage.value = "Erreur lors de la capture de l'image";
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Erreur lors de la capture de l\'image')),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<File?> compressImage(File file) async {
    File? compressedFile;
    try {
      int fileSize = await file.length();
      int quality = 85;
      
      while (fileSize > 1024 * 1024 && quality > 10) {
        quality -= 5;
        final tempFile = await compressImageWithQuality(file, quality);
        if (tempFile == null) break;
        
        final newSize = await tempFile.length();
        if (newSize <= 1024 * 1024) {
          compressedFile = tempFile;
          break;
        }
        
        // Clean up previous attempt if it wasn't successful
        if (compressedFile != null && compressedFile.path != tempFile.path) {
          await compressedFile.delete();
        }
        compressedFile = tempFile;
        fileSize = newSize;
      }
      
      return compressedFile;
    } catch (e) {
      safePrint("Error compressing image: $e");
      // Clean up if something went wrong
      if (compressedFile != null) {
        await compressedFile.delete();
      }
      return null;
    }
  }

  Future<File?> compressImageWithQuality(File file, int quality) async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tempFile = File('$path/$fileName');
    
    try {
      final bytes = await file.readAsBytes();
      // Decode/re-encode in a background isolate to keep the UI responsive.
      final compressedBytes = await compute(
          _reencodeJpgIsolate, {'bytes': bytes, 'quality': quality});
      if (compressedBytes == null) return null;

      await tempFile.writeAsBytes(compressedBytes);
      return tempFile;
    } catch (e) {
      safePrint("Error in compressImageWithQuality: $e");
      // Clean up if something went wrong
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      return null;
    }
  }

  void _captureDamageColis(BuildContext context, ColisInTournee colisTournee, String damageType) {
    setState(() {
      colisTournee.damaged = damageType;
      colisTournee.image = null;
    });
    final providerToUpdate = widget.isDeliveringPhase
        ? colisInTourneeDeliveryPhaseProvider
        : colisInTourneeProvider;

    widget.updateColis?.call(
      [
        ...ref.read(providerToUpdate.notifier).state.map((colis) {
          if (colis.colis.id == colisTournee.colis.id) {
            return colis.copyWith(damaged: colisTournee.damaged, image: null);
          }
          return colis;
        }).toList(),
      ],
    );
  }

  void _showPicture(BuildContext context, ColisInTournee colisTournee) {
    if (colisTournee.image == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Photo du colis",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                child: Image.file(
                  colisTournee.image!,
                  fit: BoxFit.contain,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Fermer"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _chooseDamageDialog(BuildContext context, ColisInTournee colisTournee) {
    safePrint('Showing damage dialog');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Selection du type de dommage."),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(widget.isDeliveringPhase ? "Endommagé et livraison validée." :"Endommagé et récupération validée." ),
                onTap: () {
                  Navigator.pop(context);
                  _captureDamageImage(colisTournee, widget.isDeliveringPhase ? "Endommage, livraison validee" : "Endommage, récupération validee");
                },
              ),
              ListTile(
                title: Text(widget.isDeliveringPhase ? "Endommagé et refus de livraison." : "Endommagé et refus de récupération." ),
                onTap: () {
                  Navigator.pop(context);
                  _captureDamageImage(colisTournee, widget.isDeliveringPhase ? "Endommage, livraison refusee" : "Endommage, récupération refusee");
                },
              ),
              ListTile(
                title: Text(widget.isDeliveringPhase ? "Scan échoué, livraison validée" : "Scan échoué, récupération validée"),
                onTap: () {
                  Navigator.pop(context);
                  _captureDamageColis(context, colisTournee, 
                  widget.isDeliveringPhase 
                  ? "Scan échoué, livraison validee"
                  : "Scan échoué, récupération validee");
                },
              ),
              ListTile(
                title: const Text("Colis en bon état."),
                onTap: () {
                  Navigator.pop(context);
                  _captureDamageColis(context, colisTournee,
                      widget.isDeliveringPhase
                      ? "Bon etat, livraison validee"
                      : "Bon etat, récupération validee");
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const p = 15.0;
    final colisTournee = widget.colisInTournee;

    if (colisTournee != null) {
      return InkWell(
        child: Container(
          color: colisTournee.colis?.lastStatus.status == Status.IN_PROGRESS
              ? C.primary_highlight
              : null,
          child: Padding(
            padding: const EdgeInsets.all(p / 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset("assets/images/user.png", width: 15),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              colisTournee.colis.subscriber?.name ?? "inconnu",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Image.asset("assets/images/adresse.png", width: 15),
                          const SizedBox(width: 3),
                          Expanded(child: Text(colisTournee.colis.address)),
                          const SizedBox(width: 3),
                          Row(
                            children: [
                              Icon(
                                colisTournee.isScanned
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: colisTournee.isScanned
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                colisTournee.isScanned
                                    ? "Scanné"
                                    : colisTournee.isValidatedByGPS
                                    ? "Validé par GPS"
                                    : "Non scanné",
                                style: TextStyle(
                                  color: colisTournee.isScanned || colisTournee.isValidatedByGPS
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                          children: [
                            if(!widget.staticItem)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(80, 30),
                                ),
                                onPressed: () => _chooseDamageDialog(context, colisTournee),
                                child: const Text("Signaler"),
                              ),
                            if(!widget.staticItem)
                              const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                colisTournee.damaged=="" ? "Aucun dommage" : colisTournee.damaged,
                                style: TextStyle(
                                  color: colisTournee.damaged=="" ?
                                  Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            if(colisTournee.image!=null)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(80, 30),
                                ),
                                onPressed: () => _showPicture(context, colisTournee),
                                child: const Text("Voir photo"),
                              ),
                          ]
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }
}
