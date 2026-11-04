import 'package:wabap/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:wabap/colors.dart';
import 'package:wabap/util.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/provider/tournee_provider.dart';
import 'package:wabap/screen/error_screen.dart';
import 'package:wabap/widgets/item_tournee.dart';

class TourneesScreen extends HookConsumerWidget {
  const TourneesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    safePrint(">>>> BUILD TourneesScreen");
    final userId = ref.watch(authProvider).myId ?? "";
    final tourneesAsync = ref.watch(tourneeProvider(userId));
    final scrollController = ScrollController();
    scrollController.addListener(
      () {
        final p = scrollController.position;
        if (p.pixels == p.maxScrollExtent) {
          ref.read(tourneeProvider(userId).notifier).loadMoreTournee();
        }
      },
    );

    useEffect(() {
      ref.read(tourneeProvider(userId).notifier).loadTournee();
      return () {};
    }, [userId]);

    return Scaffold(
      body: Center(
        child: tourneesAsync.when(
          data: (tournees) {
            return RefreshIndicator(
              onRefresh: () {
                return ref.read(tourneeProvider(userId).notifier).loadTournee(force: true);
              },
              child: Stack(
                children: [
                  ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                    itemCount: tournees.length + (ref.read(tourneeProvider(userId).notifier).isMoreTournee() ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < tournees.length) {
                        return TourneeItem(tournee: tournees[index]);
                      }
                      return Util.smallCircularProgressIndicator();
                    },
                    controller: scrollController,
                    separatorBuilder: (context, index) {
                      return const Divider(height: 0.5);
                    },
                  ),
                  if (tournees.isEmpty) const Center(child: Text("Vous n'avez aucune tournée à effectuer")),
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
          "Mes tournées",
          style: TextStyle(color: C.white),
        ),
      ),
    );
  }
}
