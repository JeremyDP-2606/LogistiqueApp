import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/models/ModelProvider.dart';
import 'package:wabap/screen/tournee_map_screen.dart';

class ColisItem extends ConsumerWidget {
  final Colis? colis;

  const ColisItem({super.key, required this.colis});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const p = 15.0;
    if (colis != null) {
      return InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => TourneeMapScreen(tourneeId: colis!.tournee.id, colisId: colis!.id)));
        },
        child: Container(
          color: colis?.lastStatus.status == Status.IN_PROGRESS ? C.primary_highlight : null,
          child: Padding(
            padding: const EdgeInsets.only(left: p, top: p / 2, right: p, bottom: p / 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Image.asset(width: 15, "assets/images/user.png"),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              colis!.subscriber?.name ?? "inconnu",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          )
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Image.asset(width: 15, "assets/images/adresse.png"),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(colis!.address),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(width: 30, _getIconByStatus(colis!.lastStatus.status)))
              ],
            ),
          ),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
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
