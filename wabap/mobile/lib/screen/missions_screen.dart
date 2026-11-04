import 'package:wabap/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:wabap/colors.dart';
import 'package:wabap/provider/mission_provider.dart';
import 'package:wabap/util.dart';
import 'package:wabap/screen/error_screen.dart';
import 'package:wabap/widgets/item_mission.dart';

class MissionsScreen extends HookConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    safePrint(">>>> BUILD MissionsScreen");
    final missionsAsync = ref.watch(missionProvider);
    final scrollController = ScrollController();
    scrollController.addListener(
      () {
        final p = scrollController.position;
        if (p.pixels == p.maxScrollExtent) {
          ref.read(missionProvider.notifier).loadMoreMission();
        }
      },
    );

    useEffect(() {
      ref.read(missionProvider.notifier).loadMission();
      return () {};
    }, []);

    return Scaffold(
      body: Center(
        child: missionsAsync.when(
          data: (missions) {
            return RefreshIndicator(
              onRefresh: () {
                return ref.read(missionProvider.notifier).loadMission(force: true);
              },
              child: Stack(
                children: [
                  ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                    itemCount: missions.length + (ref.read(missionProvider.notifier).isMoreMission() ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < missions.length) {
                        return MissionItem(mission: missions[index]);
                      }
                      return Util.smallCircularProgressIndicator();
                    },
                    controller: scrollController,
                    separatorBuilder: (context, index) {
                      return const Divider(height: 0.5);
                    },
                  ),
                  if (missions.isEmpty) const Center(child: Text("Aucune mission disponnible pour le moment")),
                ],
              ),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => ErrorScreen('Erreur: $error'),
        ),
      ),
      appBar: AppBar(
        title: const Text(
          "Les missions",
          style: TextStyle(color: C.white),
        ),
      ),
    );
  }
}
