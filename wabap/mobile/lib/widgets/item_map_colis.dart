import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/models/ModelProvider.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/provider/colis_provider.dart';
import 'package:wabap/provider/tournee_provider.dart';
import 'package:wabap/screen/qr_screen.dart';
import 'package:wabap/util.dart';

class ColisMapItem extends ConsumerWidget {
  final String tourneeId;
  final String colisId;

  const ColisMapItem({super.key, required this.tourneeId, required this.colisId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider).myId ?? "";
    final tourneeList = ref.watch(tourneeProvider(userId));
    final tournee = tourneeList.value?.firstWhere((colis) => colis.id == tourneeId);
    final colisList = ref.watch(colisProvider(tourneeId));
    final colis = colisList.value?.firstWhere((colis) => colis.id == colisId);

    if (colis != null) {
      return Container(
        width: double.infinity,
        color: C.white,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Image.asset(width: 15, "assets/images/user.png"),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      colis.subscriber?.name ?? "inconnu",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(colis.address, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
              if (colis.subscriber?.phone1 != null || colis.subscriber?.phone2 != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                      "Tél : ${colis.subscriber?.phone1 ?? ""}${colis.subscriber?.phone1 != null && colis.subscriber?.phone2 != null ? " / " : ""}${colis.subscriber?.phone2 ?? ""}"),
                ),
              if (colis.subscriber?.instructions != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text("Instructions : « ${colis.subscriber!.instructions!} »"),
                ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Statut : ",
                      ),
                      Icon(
                        Util.statusIcon(colis.lastStatus.status),
                        color: Util.statusColor(colis.lastStatus.status),
                        size: 14.0,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        Util.statusName(colis.lastStatus.status),
                        style: TextStyle(color: Util.statusColor(colis.lastStatus.status), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(width: 5),
                  if (colis.lastStatus.message != null)
                    Expanded(
                        child: Text(
                      "(${colis.lastStatus.message!})",
                      style: const TextStyle(color: C.textColor),
                    ))
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: C.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                    side: const BorderSide(
                      color: C.primary, // Couleur de la bordure
                      width: 2, // Épaisseur de la bordure
                    ),
                  ),
                ),
                onPressed: () async {
                  String googleUrl =
                      'https://www.google.com/maps/search/?api=1&query=${colis.latitude},${colis.longitude}';
                  if (await canLaunchUrlString(googleUrl)) {
                    await launchUrlString(googleUrl, mode: LaunchMode.externalApplication);
                  } else {
                    throw 'Unable open the map.';
                  }
                },
                child: const Text(
                  "Itinéraire",
                  style: TextStyle(color: C.primary, fontSize: 18),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: C.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                onPressed: colis.lastStatus.status == Status.COMPLETED || tournee?.status != Status.IN_PROGRESS
                    ? null
                    : () async {
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => QrScreen(colis: colis)));
                      },
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code, color: C.white),
                      SizedBox(width: 10),
                      Text(
                        "Valider la livraison",
                        style: TextStyle(color: C.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      );
    } else {
      return const Center(child: Text("Error"));
    }
  }

  String _getIconByStatus(status) {
    switch (status) {
      case Status.COMPLETED:
        return "assets/images/check_on.png";
      case Status.ISSUE:
        return "assets/images/nok.png";
      case Status.IN_PROGRESS:
        return "assets/images/progress.png";
      case Status.PENDING:
        return "assets/images/check_off.png";
      default:
        return "assets/images/check_off.png";
    }
  }
}
