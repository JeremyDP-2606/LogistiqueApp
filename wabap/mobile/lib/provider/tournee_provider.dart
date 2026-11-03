import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/models/Status.dart';
import 'package:wabap/models/Tournee.dart';
import 'package:wabap/provider/api_providers.dart';
import 'package:wabap/services/colis_status_sync_service.dart';
import 'package:wabap/services/local_colis_status_store.dart';

class TourneeNotifier extends StateNotifier<AsyncValue<List<Tournee>>> {
  String userId;
  TourneeNotifier({required this.userId}) : super(const AsyncValue.loading());

  String? nextToken;
  List<Tournee> cache = [];

  /// Overlays the locally-persisted (not-yet-synced) status intent on top of a
  /// backend list, so a refetch during an outage doesn't visually revert an
  /// IN_PROGRESS/COMPLETED tournee to its stale backend status. Forward-only:
  /// an intent never makes a tournee go backwards.
  Future<List<Tournee>> _overlayPendingStatus(List<Tournee> list) async {
    if (list.isEmpty) return list;
    final pending =
        await LocalColisStatusStore.instance.getUnsyncedTourneeStatuses();
    if (pending.isEmpty) return list;
    return list.map((tournee) {
      final intent = pending[tournee.id];
      if (intent == null) return tournee;
      Status? backendStatus;
      try {
        backendStatus = tournee.status;
      } catch (_) {}
      if (!ColisStatusSyncService.shouldPushTourneeStatus(
          intent.status, backendStatus)) {
        return tournee;
      }
      return tournee.copyWith(status: intent.status);
    }).toList();
  }

  Future<void> reloadTournee() async {
    loadTournee(force: true);
    state = const AsyncValue.loading();
  }

  Future<void> loadTournee({force = false}) async {
    try {
      safePrint(">>>> tourneeProvider : loadTournee() hasValue=[${state.hasValue}] - force=[$force]");
      if (state.hasValue && !force) {
        state = state.asData!;
      } else {
        PaginationResponse<Tournee> rep = await API.loadTournees(userId);
        nextToken = rep.nextToken;
        cache = await _overlayPendingStatus(rep.list);
        safePrint(">>>> loadTournee : rep=[$rep]");
        state = AsyncValue.data(cache);
      }
    } catch (error, stack) {
      safePrint(">>>> loadTournee ERROR : error=[$error] - stack=[$stack]");
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> loadMoreTournee() async {
    safePrint(">>>> tourneeProvider : loadMoreTournee() nextToken=[$nextToken]");
    if (isMoreTournee()) {
      try {
        PaginationResponse<Tournee> rep = await API.loadTournees(userId, nextToken);
        nextToken = rep.nextToken;
        cache.addAll(rep.list);
        cache = await _overlayPendingStatus(cache);
        safePrint(">>>> loadMoreTournee : rep=[$rep]");
        state = AsyncValue.data(cache);
      } catch (error, stack) {
        safePrint(">>>> loadMoreTournee ERROR : error=[$error] - stack=[$stack]");
        state = AsyncValue.error(error, stack);
      }
    }
  }

  /// Applies a tournee status change with the same local-first strategy as
  /// colis statuses:
  /// 1. persist the intent locally (survives offline / app kill),
  /// 2. update the in-memory list optimistically,
  /// 3. push to the backend, 4. mark synced on success.
  ///
  /// On push failure the intent stays pending and [ColisStatusSyncService]
  /// replays it later (colis first, then tournee). This method never throws
  /// for network errors and never flips the list to an error state - that was
  /// how the tournee status got silently lost during outages.
  /// Set [rapportPending] when completing a secure tournee: the sync service
  /// will generate the report once everything for the tournee is synced.
  Future<void> updateStatus(Status status, Tournee tournee,
      {bool rapportPending = false}) async {
    safePrint(">>>> tourneeProvider : updateStatus() status=[$status] tournee=[${tournee.id}] rapportPending=[$rapportPending]");
    final newTournee = tournee.copyWith(status: status);

    // 1. Local-first persistence, scoped to the signed-in account.
    String? enqueuedBy;
    try {
      enqueuedBy = (await Amplify.Auth.getCurrentUser()).userId;
    } catch (_) {}
    await LocalColisStatusStore.instance
        .upsertPendingTourneeStatus(PendingTourneeStatus(
      tourneeId: tournee.id,
      status: status,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
      enqueuedBy: enqueuedBy,
      rapportPending: rapportPending,
    ));
    ColisStatusSyncService.instance.refreshCount();

    // 2. Optimistic in-memory update.
    final newListTournee = state.asData?.value.map((t) {
      if (t.id == newTournee.id) return newTournee;
      return t;
    }).toList();
    if (newListTournee != null) {
      cache = newListTournee;
      state = AsyncValue.data(newListTournee);
    }

    // 3. Push to backend - unless the device knows it is offline: the intent
    // is already persisted and the sync service replays it.
    if (!await ColisStatusSyncService.hasNetwork()) {
      safePrint(">>>> updateStatus offline: tournee ${tournee.id} kept in local queue");
      return;
    }
    try {
      final updatedTournee = await API.updateTournee(newTournee);
      if (updatedTournee == null) throw Exception("Tournée non mise à jour");
    } catch (error) {
      await LocalColisStatusStore.instance
          .incrementTourneeStatusAttempt(tournee.id);
      safePrint(">>>> updateStatus push failed (kept pending): error=[$error]");
      return;
    }

    // 4. Confirmed.
    await LocalColisStatusStore.instance.markTourneeStatusSynced(tournee.id);
    ColisStatusSyncService.instance.refreshCount();
  }

  bool isMoreTournee() {
    return nextToken != null;
  }

  List<Tournee> getTournees() {
    if (state.hasValue) {
      return state.asData!.value;
    }
    return [];
  }

  Tournee? getTournee(String tourneeId) {
    if (state.hasValue && state.asData != null) {
      try {
        return state.asData!.value.firstWhere((t) => t.id == tourneeId);
      } catch (e) {
        safePrint("Tournee not found: $tourneeId, error: $e");
        return null;
      }
    }
    return null;
  }
}

final tourneeProvider = StateNotifierProvider.family<TourneeNotifier, AsyncValue<List<Tournee>>, String>(
  (ref, userId) => TourneeNotifier(userId: userId),
);
