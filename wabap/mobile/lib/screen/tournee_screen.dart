import 'package:wabap/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_static_maps_controller/google_static_maps_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/const.dart';
import 'package:wabap/models/Colis.dart';
import 'package:wabap/models/Status.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/provider/colis_provider.dart';
import 'package:wabap/provider/location_provider.dart';
import 'package:wabap/provider/tournee_provider.dart';
import 'package:wabap/screen/error_screen.dart';
import 'package:wabap/screen/tournee_map_screen.dart';
import 'package:wabap/util.dart';
import 'package:wabap/widgets/item_colis.dart';

import 'package:wabap/screen/preuve_livraison/colis_pickup_process_screen.dart';
import 'package:wabap/widgets/item_list_colis.dart';
import 'package:wabap/models/MinorModels.dart';
import 'package:wabap/services/colis_status_sync_service.dart';
import 'package:wabap/services/local_colis_status_store.dart';

class TourneeScreen extends HookConsumerWidget {
  final String tourneeId;

  const TourneeScreen({Key? key, required this.tourneeId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    safePrint(">>>> BUILD TourneeScreen");
    final userId = ref.watch(authProvider).myId ?? "";
    final tourneeList = ref.watch(tourneeProvider(userId));
    final tournee = tourneeList.value?.firstWhere((colis) => colis.id == tourneeId);
    if (tournee == null) return const ErrorScreen("Tournée non trouvée");
    final colisAsync = ref.watch(colisProvider(tournee.id));
    // Hook-managed: automatically disposed, and not re-created on every rebuild.
    final scrollController = useScrollController();
    
    // Automatic progressive loading - no scroll required
    useEffect(() {
      // `cancelled` stops the loop when the screen is disposed, so the
      // self-rescheduling timers below can never leak / pile up across screens.
      bool cancelled = false;

      // Replay any colis statuses left pending from a previous burst.
      ColisStatusSyncService.instance.tryFlush();

      ref.read(colisProvider(tournee.id).notifier).loadColis();
      
      // Auto-load more packages progressively with retry on error
      // Never truly stops - keeps retrying with increasing delays to allow network recovery
      int retryCount = 0;
      const maxInitialRetries = 3;
      const persistentRetryDelay = 30000; // 30 seconds for persistent retries
      
      void autoLoadMore() {
        if (cancelled) return;
        final colisNotifier = ref.read(colisProvider(tournee.id).notifier);
        if (colisNotifier.isMoreColis() && !colisNotifier.isLoading) {
          colisNotifier.loadMoreColis().then((_) {
            if (cancelled) return;
            // Success - reset retry count and continue loading
            retryCount = 0;
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!cancelled) autoLoadMore();
            });
          }).catchError((error) {
            if (cancelled) return;
            safePrint("Error auto-loading more colis: $error (attempt ${retryCount + 1})");
            // Retry with exponential backoff for initial failures, then persistent retries
            int delayMs;
            if (retryCount < maxInitialRetries) {
              retryCount++;
              delayMs = 1000 * (1 << retryCount); // 2s, 4s, 8s
            } else {
              // After initial retries, keep trying every 30 seconds
              // This allows recovery when network comes back
              delayMs = persistentRetryDelay;
              if (retryCount == maxInitialRetries) {
                safePrint("Initial retries exhausted. Will retry every $persistentRetryDelay ms until network recovers.");
              }
              retryCount++; // Keep incrementing to track attempts
            }
            
            Future.delayed(Duration(milliseconds: delayMs), () {
              if (cancelled) return;
              // Check again if we still have more to load before retrying
              final notifier = ref.read(colisProvider(tournee.id).notifier);
              if (notifier.isMoreColis() && !notifier.isLoading) {
                autoLoadMore();
              }
            });
          });
        }
      }
      
      // Start auto-loading after initial load
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!cancelled) autoLoadMore();
      });
      
      // Stop the loop on dispose.
      return () {
        cancelled = true;
      };
    }, []);
    
    // Auto-load more when data changes and there's more to load
    // This also helps resume loading after network recovery
    useEffect(() {
      bool cancelled = false;
      if (colisAsync.hasValue && !colisAsync.isLoading) {
        // Small delay to allow UI to update before loading more
        Future.delayed(const Duration(milliseconds: 500), () {
          if (cancelled) return;
          final colisNotifier = ref.read(colisProvider(tournee.id).notifier);
          if (colisNotifier.isMoreColis() && !colisNotifier.isLoading) {
            safePrint("Resuming auto-load from useEffect (data changed or network recovered)");
            colisNotifier.loadMoreColis().catchError((error) {
              safePrint("Error in auto-load useEffect: $error");
              // Error is handled in provider, don't crash
            });
          }
        });
      }
      return () {
        cancelled = true;
      };
    }, [colisAsync]);

    //final shouldRefresh = ref.watch(tourneeRefreshProvider);

    return Scaffold(
      body: Center(
        child: colisAsync.when(
          data: (listColis) {
            // Only filter when tournee is in progress or later (not PENDING)
            final shouldFilter = tournee.status != Status.PENDING;
            final filteredColis = shouldFilter
                ? listColis.where((colis) => colis.lastStatus.status != Status.NOT_PICKED_UP_NOT_EXIST).toList()
                : listColis;
            final filteredCount = shouldFilter ? (listColis.length - filteredColis.length) : 0;

            final GroupedColisResult groupedColisAndSubscriber = groupAndOrderedColisBySubscriber(filteredColis);
            final deliveringSortedSubscriber = groupedColisAndSubscriber.listNameClients;
            
            final colisNotifier = ref.read(colisProvider(tournee.id).notifier);
            final isLoadingMore = colisNotifier.isLoading;
            final hasMore = colisNotifier.isMoreColis();

            // Secure tournées only: during the delivery phase every colis
            // should be PICKED_UP (or beyond). A PENDING colis here was never
            // scanned/confirmed at pickup - warn the driver instead of
            // presenting it as a normal stop. (Non-secure tournées have no
            // pickup scan phase, PENDING is their normal state.)
            final nbNonRamasses = (tournee.deliveryChecking == true &&
                    tournee.status == Status.IN_PROGRESS)
                ? filteredColis
                    .where((colis) => colis.lastStatus.status == Status.PENDING)
                    .length
                : 0;

            // ------------------------------ OLD UI -------------------------------------------------
            return Column(
              children: [
                _getTopView(tournee, groupedColisAndSubscriber, listColis, context, ref),
                if (nbNonRamasses > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    color: Colors.red.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.red.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "$nbNonRamasses colis non ramassé${nbNonRamasses > 1 ? 's' : ''} (statut PENDING) — vérifiez avant livraison",
                            style: TextStyle(fontSize: 13, color: Colors.red.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Show loading/completion status banner
                if (isLoadingMore || hasMore)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    color: Colors.orange.shade50,
                    child: Row(
                      children: [
                        if (isLoadingMore) ...[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Chargement en cours... (${listColis.length} colis chargés${shouldFilter && filteredCount > 0 ? ", $filteredCount non récupérés" : ""})",
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ] else if (hasMore) ...[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Chargement automatique... (${listColis.length} colis chargés${shouldFilter && filteredCount > 0 ? ", $filteredCount non récupérés" : ""})",
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    color: Colors.green.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Tous les colis sont chargés (${listColis.length} chargés${shouldFilter && filteredCount > 0 ? ", $filteredCount non récupérés" : ""})",
                            style: TextStyle(fontSize: 13, color: Colors.green.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 5),
                Container(
                  height: 1 / MediaQuery.of(context).devicePixelRatio,
                  width: double.infinity,
                  color: C.textColor,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () {
                      return ref.read(colisProvider(tournee.id).notifier).loadColis(force: true);
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 15.0),
                      itemCount: deliveringSortedSubscriber.length + (isLoadingMore || hasMore ? 1 : 0),
                      itemBuilder: (context, index){
                        // Show simple loading indicator at the end if loading more
                        // (Detailed status is shown in the banner at the top)
                        if (index == deliveringSortedSubscriber.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Util.smallCircularProgressIndicator(),
                          );
                        }
                        
                        final subscriberGroupColis = groupedColisAndSubscriber.groupedColis[deliveringSortedSubscriber[index]];
                        if(subscriberGroupColis?.length == 1){
                          return ColisItem(colis: subscriberGroupColis?[0]);
                        }else{
                          if(subscriberGroupColis!=null) {
                            return GroupColisItem(colisList: subscriberGroupColis, tourneeName: tournee.name);
                          }
                        }
                        return const SizedBox.shrink();
                      },
                      separatorBuilder: (context, index) {
                        // Don't show separator before loading indicator
                        if (index >= deliveringSortedSubscriber.length) {
                          return const SizedBox.shrink();
                        }
                        return const Divider(height: 0.5);
                      },
                      controller: scrollController
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => ErrorScreen('Erreur: $error'),
        ),
      ),
      appBar: AppBar(
        title: Text(
          tournee.name,
          style: const TextStyle(color: C.white),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () {
          if (colisAsync.asData != null) {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => TourneeMapScreen(tourneeId: tourneeId)));
          }
        },
        tooltip: 'carte',
        child: const Icon(Icons.map, color: C.white),
      ),
    );
  }

  Widget _getTopView(tournee, groupedColisAndSubscriber, listColis, context, ref) {
    final userId = ref.watch(authProvider).myId ?? "";
    var nextColis = _nextColisStatus(groupedColisAndSubscriber, [Status.PICKED_UP, Status.PENDING, Status.IN_PROGRESS]);
    final isBtnLoading = useState(false);
    const padding = 15.0;
    const hImage = 100.0;
    const wImage = 90.0;
    const scaleImage = 3;

    if (tournee.status == Status.PENDING) {
      /**
       * START TOURNEE
       */

      var lat = tournee.startLatitude;
      var lng = tournee.startLongitude;

      final controllerImageMap = StaticMapController(
          googleApiKey: GOOGLE_API_KEY,
          width: wImage.toInt() * scaleImage,
          height: (hImage * 1.2).toInt() * scaleImage, //*1.2 remove logo
          zoom: 12,
          center: GeocodedLocation.latLng(lat, lng),
          styles: Util.retroMapStyle,
          markers: [
            Marker(locations: [Location(lat, lng)], color: C.app[300])
          ]);

      return Padding(
        padding: const EdgeInsets.only(left: padding, top: padding / 2, right: padding, bottom: padding / 2),
        child: Column(
          children: [
            const SizedBox(height: 5),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.looks_one_outlined, color: C.primary, size: 30),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      "Avant de commencer cette tournée, vous devez vous rendre au point de récupération :",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: SizedBox(
                    width: wImage,
                    height: hImage,
                    child: Stack(
                      children: [
                        Container(color: Colors.grey[200]),
                        Image(
                          width: wImage,
                          height: hImage,
                          image: controllerImageMap.image,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: Opacity(
                                  opacity: 0.5,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Opacity(
                                opacity: 0.1,
                                child: Image.asset(width: 15, "assets/images/error.png"),
                              ),
                            );
                          },
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournee.startName ?? Util.formatCoordonate(tournee.startLatitude, tournee.startLongitude),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (tournee.startName != null)
                        Text(Util.formatCoordonate(tournee.startLatitude, tournee.startLongitude))
                    ],
                  ),
                )
              ],
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
              onPressed: () async {
                final lat = tournee.startLatitude;
                final lng = tournee.startLongitude;
                String googleUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                if (await canLaunchUrlString(googleUrl)) {
                  await launchUrlString(googleUrl, mode: LaunchMode.externalApplication);
                } else {
                  throw 'Unable open the map.';
                }
              },
              child: const Text(
                "Itinéraire",
                style: TextStyle(color: C.white, fontSize: 18),
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.looks_two_outlined, color: C.primary, size: 30),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      "Une fois les colis récupéré, vous pouvez commencer la tournée :",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: C.ok,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              onPressed: isBtnLoading.value
                  ? null
                  : () async {
                      isBtnLoading.value = true;

                      // If tournee.isProof is true, navigate to ProofScreen
                      safePrint("CHEEEEEEEEEEEEEEEEEEEEEEEECCCCCCCCCCCCCCCCCKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK");
                      safePrint(tournee.deliveryChecking);
                      if(tournee.deliveryChecking == true){
                        safePrint("TOUUUUUUUUUUUUUUUUUUUUUUUUUNRRRRRNNNNEEEEEEEEEEEEEEEEEEEEE TRUUUUUUUUUEEEEEE");
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PackageProcessScreen(tourneeId: tournee.id, isDeliveringPhase:false, tournee: tournee),
                          ),
                        );
                        isBtnLoading.value = false;
                      }else{
                        safePrint("TOUUUUUUUUUUUUUUUUUUUUUUUUUNRRRRRNNNNEEEEEEEEEEEEEEEEEEEEE FAAAAAAAAAAAAAAAAAAAAAAAAAAALSEEEEEE");
                        await ref.read(tourneeProvider(userId).notifier)
                            .updateStatus(Status.IN_PROGRESS, tournee);
                        if (nextColis != null &&
                            nextColis.lastStatus.status == Status.PENDING) {
                          var lastPosition = await ref.read(
                              positionProvider.future);
                          await ref
                              .read(colisProvider(tournee.id).notifier)
                              .updateStatusColis(Status.IN_PROGRESS, nextColis,
                              position: lastPosition);
                        }
                        isBtnLoading.value = false;
                      }

                      safePrint("REEEEBUUIIIIILLLLLDDDDDDDDDDDD PAAAACKAAAAAGGEEEEEE SCREEEEEEEEEN");
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
                  : const Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Spacer(),
                        Icon(Icons.check, color: C.white, size: 30),
                        SizedBox(width: 5),
                        Text(
                          "Commencer la tournée",
                          style: TextStyle(color: C.white, fontSize: 18),
                        ),
                        Spacer(),
                      ],
                    ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      );
    } else if (nextColis != null) {
      /**
       * TOURNEE IN PROGRESS
       */
      var lat = nextColis.latitude;
      var lng = nextColis.longitude;

      final controllerImageMap = StaticMapController(
          googleApiKey: GOOGLE_API_KEY,
          width: wImage.toInt() * scaleImage,
          height: (hImage * 1.2).toInt() * scaleImage, //*1.2 remove logo
          zoom: 15,
          center: GeocodedLocation.latLng(lat, lng),
          styles: Util.retroMapStyle,
          markers: [
            Marker(locations: [Location(lat, lng)], color: C.app[300])
          ]);

      return InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => TourneeMapScreen(tourneeId: nextColis.tournee.id, colisId: nextColis.id)));
        },
        child: Padding(
          padding: const EdgeInsets.only(left: padding, top: padding / 2, right: padding, bottom: padding / 2),
          child: Column(
            children: [
              const SizedBox(height: 5),
              Row(
                children: [
                  Image.asset(width: 15, "assets/images/adresse.png"),
                  const SizedBox(width: 3),
                  const Text("Prochaine adresse :"),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: SizedBox(
                      width: wImage,
                      height: hImage,
                      child: Stack(
                        children: [
                          Container(color: Colors.grey[200]),
                          Image(
                            width: wImage,
                            height: hImage,
                            image: controllerImageMap.image,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }
                              return Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Opacity(
                                    opacity: 0.5,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Opacity(
                                  opacity: 0.1,
                                  child: Image.asset(width: 15, "assets/images/error.png"),
                                ),
                              );
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 3.0),
                              child: Image.asset(width: 15, "assets/images/user.png"),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                nextColis.subscriber?.name ?? "inconnu",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(nextColis.address, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
                        if (nextColis.subscriber?.phone1 != null || nextColis.subscriber?.phone2 != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                                "Tél : ${nextColis.subscriber?.phone1 ?? ""}${nextColis.subscriber?.phone1 != null && nextColis.subscriber?.phone2 != null ? " / " : ""}${nextColis.subscriber?.phone2 ?? ""}"),
                          ),
                        if (nextColis.subscriber?.instructions != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text("Instructions : « ${nextColis.subscriber!.instructions!} »"),
                          )
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: C.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                onPressed: () async {
                  final lat = nextColis.latitude;
                  final lng = nextColis.longitude;
                  String googleUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                  if (await canLaunchUrlString(googleUrl)) {
                    await launchUrlString(googleUrl, mode: LaunchMode.externalApplication);
                  } else {
                    throw 'Unable open the map.';
                  }
                },
                child: const Text(
                  "Itinéraire",
                  style: TextStyle(color: C.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (ref.read(colisProvider(tournee.id).notifier).isMoreColis()) {
      /**
       * LOAD MORE COLIS
       */
      return Padding(
        padding: const EdgeInsets.only(left: padding, top: padding / 2, right: padding, bottom: padding / 2),
        child: Column(
          children: [
            const SizedBox(height: 5),
            Row(
              children: [
                Image.asset(width: 15, "assets/images/adresse.png"),
                const SizedBox(width: 3),
                const Text("Prochaine adresse :"),
              ],
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: C.primary, size: 30),
                  SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Text(
                      "Chargez plus de colis dans la liste pour voir la prochaine adresse de livraison",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: C.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              onPressed: isBtnLoading.value
                  ? null
                  : () async {
                      isBtnLoading.value = true;
                      await ref.read(colisProvider(tournee.id).notifier).loadMoreColis();
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
                  : const Text(
                      "Charger plus",
                      style: TextStyle(color: C.white, fontSize: 18),
                    ),
            ),
          ],
        ),
      );
    } else if (tournee.status != Status.COMPLETED && tournee.status != Status.ISSUE) {
      /**
         * TOURNEE COMPLETE
         */
      var nbColisFail = _nbColisStatus(listColis, [Status.ISSUE]);
      return Padding(
        padding: const EdgeInsets.only(left: padding, top: padding / 2, right: padding, bottom: padding / 2),
        child: Column(
          children: [
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(width: 30, "assets/images/check_on.png"),
                      const SizedBox(
                        width: 10,
                      ),
                      const Expanded(
                        child: Text(
                          "Vous avez livré tous les colis de cette tournée. Voulez vous la terminer ?",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (nbColisFail > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(width: 30, "assets/images/nok.png"),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Text(
                              "Vous avez un incident sur $nbColisFail colis.",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: C.ok,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              onPressed: isBtnLoading.value
                  ? null
                  : () async {
                      isBtnLoading.value = true;
                      var nbColisFail = _nbColisStatus(listColis, [Status.ISSUE]);
                      // For secure tournees the completion report is generated
                      // by the sync service once EVERYTHING is synced (statuses,
                      // tournee, proofs) - never lost offline, never computed on
                      // incomplete data.
                      await ref
                          .read(tourneeProvider(userId).notifier)
                          .updateStatus(
                              nbColisFail == 0 ? Status.COMPLETED : Status.ISSUE,
                              tournee,
                              rapportPending: tournee.deliveryChecking == true);

                      // Always clear confirmed-synced rows (it only deletes
                      // synced=1 entries, pending ones are never dropped), then
                      // warn if statuses or proof uploads are still pending.
                      await LocalColisStatusStore.instance
                          .clearSyncedForTournee(tournee.id);
                      final remainingStatuses = await LocalColisStatusStore
                          .instance
                          .countUnsynced(tourneeId: tournee.id);
                      final remainingUploads = await LocalColisStatusStore
                          .instance
                          .countUnsyncedUploads(tourneeId: tournee.id);
                      final remainingColis = await LocalColisStatusStore
                          .instance
                          .countUnsyncedColis(tourneeId: tournee.id);
                      // Rapport excluded: a report not yet generated is not
                      // "unsynced data" - it is carried by the home badge only.
                      final remainingTournee = await LocalColisStatusStore
                          .instance
                          .countUnsyncedTourneeStatuses(
                              tourneeId: tournee.id,
                              includeRapportPending: false);
                      final remaining =
                          remainingStatuses + remainingUploads + remainingTournee;
                      if (remaining == 0 && tournee.deliveryChecking == true) {
                        // Network is fine and everything is synced: request the
                        // report right now, during the button press (like the
                        // old behaviour). On failure the queue/badge take over.
                        await ColisStatusSyncService.instance
                            .tryGenerateRapportNow(tournee.id);
                      }
                      // Flush whatever is left: offline it is a no-op and
                      // everything (report included) replays later.
                      ColisStatusSyncService.instance.tryFlush(force: true);
                      if (remaining > 0) {
                        if (context.mounted) {
                          await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Synchronisation en attente'),
                              content: Text(remainingColis > 0
                                  ? "$remainingColis colis ne ${remainingColis > 1 ? 'sont' : 'est'} pas encore synchronisé${remainingColis > 1 ? 's' : ''}. Ils seront renvoyés automatiquement dès que la connexion sera rétablie."
                                  : "Des éléments de la tournée (signature, statut) ne sont pas encore synchronisés. Ils seront renvoyés automatiquement dès que la connexion sera rétablie."),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
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
                  : const Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Spacer(),
                        Icon(Icons.check, color: C.white, size: 30),
                        SizedBox(width: 5),
                        Text(
                          "Terminer la tournée",
                          style: TextStyle(color: C.white, fontSize: 18),
                        ),
                        Spacer(),
                      ],
                    ),
            ),
          ],
        ),
      );
    } else {
      /**
         * TOURNEE COMPLETED
         */
      return Padding(
        padding: const EdgeInsets.only(left: padding, top: padding / 2, right: padding, bottom: padding / 2),
        child: Column(
          children: [
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  if (tournee.status == Status.COMPLETED)
                    Row(
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
                  if (tournee.status == Status.ISSUE)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(width: 30, "assets/images/nok.png"),
                        const SizedBox(
                          width: 10,
                        ),
                        const Expanded(
                          child: Text(
                            "Votre tournée est bien terminée, mais marquée avec un incident.",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  GroupedColisResult groupAndOrderedColisBySubscriber(List<Colis> listColis) {
    final Map<String, List<Colis>> groupedColis = {};
    final listNameClients = <String>[];

    for (var colis in listColis) {
      if (!groupedColis.containsKey(colis.subscriberName)) {
      listNameClients.add(colis.subscriberName);
      safePrint("The subscriber ${colis.subscriberName} does not exist yet.");
      }
      groupedColis.putIfAbsent(colis.subscriberName, () => []).add(colis);
    }
    return GroupedColisResult(groupedColis: groupedColis, listNameClients: listNameClients);
  }

  Colis? _nextColisStatus(GroupedColisResult? groupedColisAndSubscriber, List<Status> listStatus) {
    if (groupedColisAndSubscriber != null) {
      // Ensure listNameClients is not null
      final listNameClients = groupedColisAndSubscriber.listNameClients;
      if (listNameClients.isNotEmpty) {
        for (int i = 0; i < listNameClients.length; i++) {
          var name = listNameClients[i];

          // Ensure groupedColis[name] is not null
          var colisList = groupedColisAndSubscriber.groupedColis[name];
          if (colisList != null && colisList.isNotEmpty) {
            for (int j = 0; j < colisList.length; j++) {
              var colis = colisList[j];
              if (listStatus.contains(colis.lastStatus.status)) return colis;
            }
          }
        }
      }
    }
    return null;
  }


  int _nbColisStatus(List<Colis>? listColis, List<Status> listStatus) {
    var nb = 0;
    if (listColis != null) {
      for (var colis in listColis) {
        if (listStatus.contains(colis.lastStatus.status)) nb++;
      }
    }
    return nb;
  }
}
