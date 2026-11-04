import 'package:wabap/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wabap/models/ModelProvider.dart';
import 'package:wabap/provider/location_provider.dart';
import 'package:wabap/provider/tournee_provider.dart';
import 'package:wabap/screen/missions_screen.dart';
import 'package:wabap/screen/tournees_screen.dart';
import 'package:wabap/screen/users_screen.dart';
import 'package:wabap/widgets/item_tournee.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../colors.dart';
import '../provider/auth_provider.dart';
import 'package:wabap/provider/colis_tournee_provider.dart';
import 'package:wabap/screen/preuve_livraison/colis_pickup_process_screen.dart';
import 'package:wabap/services/colis_status_sync_service.dart';
import 'package:wabap/v2/screens/courier_tours_screen.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    safePrint(">>>> BUILD HomeScreen");
    final name = ref.watch(authProvider).name;
    final userId = ref.watch(authProvider).myId;
    final isAdmin = ref.watch(authProvider).isAdmin;
    final isSuperAdmin = ref.watch(authProvider).isSuperAdmin;
    final tourneesAsync = ref.watch(tourneeProvider(userId ?? ""));
    final AsyncValue<PackageInfo> packageInfo = ref.watch(packageInfoProvider);
    final currentPosition = ref.watch(positionProvider);

    useEffect(() {
      Future.microtask(() {
        return ref.read(tourneeProvider(userId ?? "").notifier).reloadTournee();
      });
      // Refresh the pending-sync badge and try to flush whatever is left.
      ColisStatusSyncService.instance.refreshCount();
      ColisStatusSyncService.instance.tryFlush();
      return () {};
    }, [userId]);

    return Scaffold(
      body: Center(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(color: C.secondary),
          child: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAdmin || isSuperAdmin)
                        ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const UsersScreen()));
                            },
                            style: ElevatedButton.styleFrom(
                              fixedSize: const Size(30, 30),
                              shape: const CircleBorder(),
                            ),
                            child: SizedBox(width: 20, height: 20, child: Image.asset('assets/images/users.png'))),
                      if (!(isAdmin || isSuperAdmin)) const SizedBox(width: 50, height: 50),
                      const Spacer(),
                      currentPosition.when(
                        data: (data) {
                          if (data == null) return const SizedBox();
                          return Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.near_me, size: 14, color: C.ok),
                                  SizedBox(width: 3),
                                  Text(
                                    'Suivie de position GPS activé',
                                    style: TextStyle(color: C.white, fontSize: 12),
                                  ),
                                ],
                              ),
                              Text(
                                '${data.latitude}, ${data.longitude}',
                                style: const TextStyle(color: C.white, fontSize: 8),
                              ),
                            ],
                          );
                        },
                        error: (error, stackTrace) {
                          return Row(
                            children: [
                              const Icon(Icons.near_me_disabled, size: 14, color: C.error),
                              const SizedBox(width: 3),
                              Text(
                                'Erreur : $error',
                                style: const TextStyle(color: C.white, fontSize: 12),
                              ),
                            ],
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: SizedBox(height: 10, width: 10, child: CircularProgressIndicator()),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                          onPressed: () {
                            // Clear the global working lists so the next account
                            // never inherits this driver's colis/scan state.
                            ref.read(colisInTourneeProvider.notifier).updateColisInTournee([]);
                            ref.read(colisInTourneeDeliveryPhaseProvider.notifier).updateColisInTournee([]);
                            ref.read(authProvider).logout();
                            ColisStatusSyncService.instance.refreshCount();
                          },
                          style: ElevatedButton.styleFrom(
                            fixedSize: const Size(30, 30),
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.power_settings_new,
                              size: 20,
                              color: C.white
                            ),
                          ),
                      ),
                    ],
                  ),
                ),
                Column(children: [
                  const SizedBox(height: 50),
                  SizedBox(height: 40, child: Image.asset('assets/images/logo_small.png')),
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      ColisStatusSyncService.instance.count,
                      ColisStatusSyncService.instance.uploadCount,
                      ColisStatusSyncService.instance.pendingColisCount,
                      ColisStatusSyncService.instance.tourneeStatusCount,
                      ColisStatusSyncService.instance.isFlushing,
                    ]),
                    builder: (context, _) {
                      final statuses = ColisStatusSyncService.instance.count.value;
                      final uploads = ColisStatusSyncService.instance.uploadCount.value;
                      final tournees = ColisStatusSyncService.instance.tourneeStatusCount.value;
                      final nbColis = ColisStatusSyncService.instance.pendingColisCount.value;
                      final flushing = ColisStatusSyncService.instance.isFlushing.value;
                      if (statuses + uploads + tournees == 0) return const SizedBox.shrink();

                      // Drivers think in colis, not technical records. When only
                      // the tournee itself remains (status/report), say so; for
                      // other tournee-level items (pickup signature), stay generic.
                      final label = nbColis > 0
                          ? "$nbColis colis à synchroniser"
                          : tournees > 0
                              ? "Tournée en attente de validation"
                              : "Synchronisation en attente";

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Material(
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: flushing
                                ? null
                                : () => ColisStatusSyncService.instance.tryFlush(force: true),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.sync_problem, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  if (flushing) ...[
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text("Synchronisation…",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  ] else
                                    const Text("Réessayer",
                                        style: TextStyle(
                                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(flex: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Bonjour ${name != null ? "$name " : ""}!",
                      style: const TextStyle(color: C.white, fontSize: 30),
                    ),
                  ),
                  if (ref.watch(authProvider).isCourier)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, left: 40, right: 40),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: C.white,
                          foregroundColor: C.secondary,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        ),
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const CourierToursScreen())),
                        icon: const Icon(Icons.route),
                        label: const Text('Mes tournées et gains', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  const Spacer(flex: 3),
                  tourneesAsync.when(
                    data: (tournees) {
                      var first = firstInProgress(tournees);
                      if (first != null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Votre dernière tournée en cours :",
                                    style: TextStyle(color: C.white, fontSize: 15),
                                  ),
                                  const Spacer(),
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        ref.read(tourneeProvider(userId ?? "").notifier).reloadTournee();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        fixedSize: const Size(30, 30),
                                        shape: const CircleBorder(),
                                      ),
                                      child: const Icon(Icons.refresh, size: 20, color: C.white)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10.0),
                                child: Container(
                                  color: C.white,
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 5),
                                      child: Material(child: TourneeItem(tournee: first))),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10)
                          ],
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.only(right: 40),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: C.primary,
                              disabledBackgroundColor: C.white09,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(50),
                                  bottomRight: Radius.circular(50),
                                ),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (context) => const TourneesScreen()));
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 40),
                              child: Text(
                                "Mes tournées",
                                style: TextStyle(color: C.white, fontSize: 18),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    loading: () {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: SizedBox(height: 10, width: 10, child: CircularProgressIndicator()),
                      );
                    },
                    error: (err, stack) {
                      return Padding(
                        padding: const EdgeInsets.all(1),
                        child: ElevatedButton(
                            onPressed: () {
                              ref.read(tourneeProvider(userId ?? "").notifier).reloadTournee();
                            },
                            style: ElevatedButton.styleFrom(
                              fixedSize: const Size(30, 30),
                              shape: const CircleBorder(),
                            ),
                            child: const Icon(Icons.refresh, size: 20, color: C.white)),
                      );
                    },
                  ),
                  const Spacer(flex: 1),
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: C.primary,
                        disabledBackgroundColor: C.white09,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(50),
                            bottomLeft: Radius.circular(50),
                          ),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MissionsScreen()));
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 40),
                        child: Text(
                          "Postuler à une mission",
                          style: TextStyle(color: C.white, fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  Padding(
                    padding: const EdgeInsets.only(right: 40),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: C.primary,
                        disabledBackgroundColor: C.white09,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(50),
                            bottomRight: Radius.circular(50),
                          ),
                        ),
                      ),
                      onPressed: () async {
                        const phoneNumber = '00596696955076';
                        Uri callUrl = Uri.parse('tel:$phoneNumber');
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        
                        if (await canLaunchUrl(callUrl)) {
                          await launchUrl(callUrl);
                        } else {
                          if (context.mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Impossible d\'ouvrir l\'application téléphone.'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 5),
                              ),
                            );
                          }
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(left: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone_outlined, size: 30, color: C.white),
                            SizedBox(width: 5),
                            Text(
                              "Assistance",
                              style: TextStyle(color: C.white, fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        color: Colors.white,
                        onPressed: () {
                          final navigator = Navigator.of(context);
                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                title: const Text('Wabap'),
                                content: Text('Version : ${packageInfo.value?.version ?? ""}'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () async {
                                      String googleUrl = 'http://www.wabap.fr/index.php/politique-de-confidentialite/';
                                      if (await canLaunchUrlString(googleUrl)) {
                                        await launchUrlString(googleUrl, mode: LaunchMode.externalApplication);
                                      } else {
                                        if (dialogContext.mounted) {
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            const SnackBar(content: Text('Impossible d\'ouvrir l\'URL')),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Politique de confidentialité'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      navigator.pop();
                                    },
                                    child: const Text('Fermer'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

firstInProgress(tournees) {
  try {
    return tournees.firstWhere((t) => t.status == Status.IN_PROGRESS);
  } catch (e) {
    return null;
  }
}
