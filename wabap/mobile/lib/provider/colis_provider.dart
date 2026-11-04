import 'dart:async';

import 'package:wabap/backend/backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:wabap/models/Colis.dart';
import 'package:wabap/models/ColisStatus.dart';
import 'package:wabap/models/Status.dart';
import 'package:wabap/provider/api_providers.dart';
import 'package:wabap/provider/auth_provider.dart';
import 'package:wabap/provider/colis_tournee_provider.dart';
import 'package:wabap/services/colis_status_sync_service.dart';
import 'package:wabap/services/local_colis_status_store.dart';

const _uuid = Uuid();

class ColisNotifier extends StateNotifier<AsyncValue<List<Colis>>> {
  String tourneeId;
  final Ref ref;
  ColisNotifier({required this.tourneeId, required this.ref}) : super(const AsyncValue.loading());

  /// Overlays not-yet-synced local statuses on top of a backend list so the UI
  /// reflects the driver's latest action even before it reaches the server.
  Future<List<Colis>> _overlayPending(List<Colis> list) async {
    if (list.isEmpty) return list;
    final pendingByColis =
        await LocalColisStatusStore.instance.getLatestUnsyncedByColis(tourneeId);
    if (pendingByColis.isEmpty) return list;
    return list.map((c) {
      final pending = pendingByColis[c.id];
      if (pending == null) return c;
      // Recency guard (same rule as the sync service): if the backend already
      // has a NEWER status than the local pending entry, trust the backend -
      // otherwise a stale stuck entry would mask fresher data indefinitely.
      try {
        final backendCreatedAt = c.lastStatus.createdAt.getDateTimeInUtc();
        if (backendCreatedAt.isAfter(pending.createdAt)) return c;
      } catch (_) {
        // Backend timestamp unavailable on this read: keep the overlay, the
        // driver's local action is the best information we have.
      }
      final overlay = ColisStatus(
        id: pending.clientId,
        owner: pending.owner,
        status: pending.status,
        message: pending.message,
        createdAt: TemporalDateTime(pending.createdAt),
        latitude: pending.latitude,
        longitude: pending.longitude,
      );
      return c.copyWith(lastStatus: overlay, colisLastStatusId: pending.clientId);
    }).toList();
  }

  // Merge two colis lists by id, keeping for each id the copy whose lastStatus
  // is the most recent. DynamoDB pagination can return the same colis on two
  // pages (every status write rewrites the row and moves it in the index): a
  // "keep first seen" dedupe would let a stale PENDING copy mask a fresher
  // NOT_PICKED_UP_NOT_EXIST, which is exactly how a non-picked colis ended up
  // shown (and delivered) during delivery. Insertion order (by position, first
  // seen) is preserved because replacing a value keeps the key's position.
  List<Colis> _mergeByFreshest(List<Colis> current, List<Colis> incoming) {
    final byId = <String, Colis>{};
    for (final c in [...current, ...incoming]) {
      final existing = byId[c.id];
      if (existing == null || _isFresher(c, existing)) {
        byId[c.id] = c;
      }
    }
    return byId.values.toList();
  }

  bool _isFresher(Colis candidate, Colis existing) {
    final tc = _lastStatusTime(candidate);
    final te = _lastStatusTime(existing);
    if (tc == null) return false;
    if (te == null) return true;
    return tc.isAfter(te);
  }

  DateTime? _lastStatusTime(Colis c) {
    try {
      return c.lastStatus.createdAt.getDateTimeInUtc();
    } catch (_) {
      return null;
    }
  }

  String? nextToken;
  bool isLoadingMore = false;

  Future<void> loadColis({force = false}) async {
    try {
      safePrint(">>>> colisProvider : loadColis() hasValue=[${state.hasValue}] - force=[$force]");
      if (state.hasValue && !force) {
        state = state.asData!;
      } else {
        PaginationResponse<Colis> rep = await API.loadColis(tourneeId);
        nextToken = rep.nextToken;
        safePrint(">>>> loadColis : rep=[$rep]");
        state = AsyncValue.data(await _overlayPending(rep.list));
      }
    } catch (error, stack) {
      safePrint(">>>> loadColis ERROR : error=[$error]");
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> loadMoreColis() async {
    // Prevent concurrent calls
    if (isLoadingMore) {
      safePrint(">>>> colisProvider : loadMoreColis() already loading, skipping");
      return;
    }

    safePrint(">>>> colisProvider : loadMoreColis() nextToken=[$nextToken]");
    if (!isMoreColis()) {
      return;
    }

    // Save the current nextToken locally to prevent race conditions
    final currentNextToken = nextToken;
    if (currentNextToken == null) {
      return;
    }

    isLoadingMore = true;
    try {
      PaginationResponse<Colis> rep = await API.loadColis(tourneeId, currentNextToken);
      nextToken = rep.nextToken;
      safePrint(">>>> loadMoreColis : rep=[$rep]");
      
      if (state.asData != null) {
        // Dedupe by id, keeping the freshest lastStatus (see _mergeByFreshest).
        final merged = _mergeByFreshest(state.asData!.value, rep.list);
        state = AsyncValue.data(await _overlayPending(merged));
      } else {
        state = AsyncValue.data(await _overlayPending(rep.list));
      }
    } catch (error, stack) {
      safePrint(">>>> loadMoreColis ERROR : error=[$error]");
      // Don't wipe out existing data on error - keep what we have
      // The error will be handled by the UI, but we preserve loaded colis
      if (state.asData != null) {
        // Keep existing data, just stop loading
        safePrint(">>>> loadMoreColis : Preserving ${state.asData!.value.length} already loaded colis despite error");
      } else {
        // Only set error if we have no data at all
        state = AsyncValue.error(error, stack);
      }
    } finally {
      isLoadingMore = false;
    }
  }

  bool isMoreColis() {
    return nextToken != null;
  }

  bool get isLoading {
    return isLoadingMore;
  }

  Colis? getColisById(String colisId) {
    if (state.hasValue && state.asData != null) {
      try {
        return state.asData!.value.firstWhere((colis) => colis.id == colisId);
      } catch (e) {
        safePrint("Colis not found by ID: $colisId, error: $e");
        return null;
      }
    }
    return null;
  }

  List<Colis> getAllColis() {
    return state.asData?.value ?? [];
  }

  Colis? getColis(String colisId) {
    if (state.hasValue && state.asData != null) {
      try {
        return state.asData!.value.firstWhere((c) => c.id == colisId);
      } catch (e) {
        safePrint("Colis not found: $colisId, error: $e");
        return null;
      }
    }
    return null;
  }

  Colis? getNextColis(String colisId) {
    if (state.hasValue) {
      int currentIndex = state.asData!.value.indexWhere((colis) => colis.id == colisId);
      if (currentIndex != -1 && currentIndex < state.asData!.value.length - 1) {
        return state.asData!.value[currentIndex + 1];
      }
    }
    return null;
  }

  Colis? getPreviousColis(String colisId) {
    if (state.hasValue) {
      int currentIndex = state.asData!.value.indexWhere((colis) => colis.id == colisId);
      if (currentIndex > 0) {
        return state.asData!.value[currentIndex - 1];
      }
    }
    return null;
  }

  /// Applies a status change with a local-first, idempotent strategy:
  /// 1. persist the intended status locally (survives crashes / offline),
  /// 2. update the in-memory list optimistically,
  /// 3. push to the backend (idempotent via [clientId]),
  /// 4. mark the local entry synced on success.
  ///
  /// On failure the entry stays pending and the error is rethrown so the
  /// caller's retry runs and the sync service can replay it later. The whole
  /// list is NOT flipped to an error state (that was the silent-loss bug).
  ///
  /// Pass the same [clientId] across retries of the same colis so the backend
  /// never gets duplicate `ColisStatus` rows.
  Future<void> updateStatusColis(Status status, Colis colis,
      {String? message, Position? position, String? clientId}) async {
    final statusId = clientId ?? _uuid.v4();
    final now = DateTime.now().toUtc();
    final createdAt = TemporalDateTime(now);
    final lat = position?.latitude;
    final lng = position?.longitude;
    safePrint(
        ">>>> colisProvider : updateStatusColis() status=[$status] colis=[${colis.id}] statusId=[$statusId]");

    // 1. Local-first persistence, scoped to the signed-in account so another
    // driver's session never replays this entry.
    String? enqueuedBy;
    try {
      enqueuedBy = ref.read(authProvider).myTrueId;
    } catch (_) {}
    await LocalColisStatusStore.instance.upsertPending(PendingColisStatus(
      clientId: statusId,
      colisId: colis.id,
      tourneeId: colis.tournee.id,
      owner: colis.owner,
      status: status,
      message: message,
      latitude: lat,
      longitude: lng,
      createdAtIso: now.toIso8601String(),
      enqueuedBy: enqueuedBy,
    ));
    ColisStatusSyncService.instance.refreshCount();

    // 2. Optimistic in-memory update.
    final optimisticStatus = ColisStatus(
      id: statusId,
      owner: colis.owner,
      status: status,
      message: message,
      createdAt: createdAt,
      latitude: lat,
      longitude: lng,
    );
    _applyStatusToState(colis.id, optimisticStatus, statusId);

    // 3. Push to backend - unless the device knows it is offline: every doomed
    // attempt costs its full timeout + retries (an offline pickup burst of 200
    // colis took >8 min for nothing). The entry is already safe in SQLite and
    // the sync service replays it when connectivity returns.
    if (!await ColisStatusSyncService.hasNetwork()) {
      safePrint(">>>> updateStatusColis offline: ${colis.id} kept in local queue");
      return;
    }
    try {
      await API.pushColisStatus(
        colis: colis,
        statusId: statusId,
        status: status,
        message: message,
        latitude: lat,
        longitude: lng,
        createdAt: createdAt,
      );
    } catch (error) {
      await LocalColisStatusStore.instance.incrementAttempt(statusId);
      safePrint(">>>> updateStatusColis push failed (kept pending): error=[$error]");
      rethrow;
    }

    // 4. Confirmed.
    await LocalColisStatusStore.instance.markSynced(statusId);
    ColisStatusSyncService.instance.refreshCount();
  }

  void _applyStatusToState(String colisId, ColisStatus newStatus, String statusId) {
    final current = state.asData?.value;
    if (current == null) return;
    final newList = current.map((c) {
      if (c.id == colisId) {
        return c.copyWith(lastStatus: newStatus, colisLastStatusId: statusId);
      }
      return c;
    }).toList();
    state = AsyncValue.data(newList);
  }

  // NOTE: the old `updateFirstPending` (optimistic, in-memory-only flip of the
  // next PENDING colis to IN_PROGRESS) was removed: it was never persisted (it
  // even carried a "//TODO : probleme ICI"), so every backend refetch reverted
  // it. The backend `triggerColisStatus` Lambda already creates the IN_PROGRESS
  // status server-side after each COMPLETED/ISSUE.

  Future<void> loadAllColisInTournee() async {
    try {
      safePrint(">>>> colisProvider : loadAllColisInTournee() started");

      List<Colis> allColis = [];
      // DynamoDB pagination can return overlapping pages when the underlying
      // index moves between requests (every status write rewrites the Colis
      // row). Dedupe by id keeping the freshest lastStatus (see _mergeByFreshest),
      // like loadMoreColis does.
      String? currentNextToken;

      do {
        PaginationResponse<Colis> rep = await API.loadColis(tourneeId, currentNextToken);
        currentNextToken = rep.nextToken;

        allColis = _mergeByFreshest(allColis, rep.list);
        safePrint(">>>> loadAllColisInTournee : loaded batch, total ${allColis.length} colis");
      } while (currentNextToken != null); // Continue while there's a nextToken

      safePrint(">>>> loadAllColisInTournee : finished loading all ${allColis.length} colis");

      allColis = await _overlayPending(allColis);
      state = AsyncValue.data(allColis);

      // Convert to ColisInTournee and update provider
      List<ColisInTournee> colisInTourneeList = allColis.map((colis) {
        return ColisInTournee(colis: colis);
      }).toList();

      ref.read(colisInTourneeProvider.notifier).setColisInTourneeList(colisInTourneeList);

    } catch (error, stack) {
      safePrint(">>>> loadAllColisInTournee ERROR : error=[$error]");
      state = AsyncValue.error(error, stack);
    }
  }
  /*
  void reset() {
    state = const AsyncValue.data([]);
  }*/


  Future<void> loadColisInTournee({force = false}) async {
    try {
      safePrint(">>>> colisProvider : loadColis() hasValue=[${state.hasValue}] - force=[$force]");
      if (state.hasValue && !force) {
        state = state.asData!;
        // Map the existing list of Colis from the state to ColisInTournee
        if (state.value != null) {
          List<ColisInTournee> colisInTourneeList = state.value!.map((colis) {
            return ColisInTournee(colis: colis);
          }).toList();
          ref.read(colisInTourneeProvider.notifier).setColisInTourneeList(colisInTourneeList);
        }

      } else {
        PaginationResponse<Colis> rep = await API.loadColis(tourneeId);
        nextToken = rep.nextToken;
        safePrint(">>>> loadColis : rep=[$rep]");
        state = AsyncValue.data(rep.list);
        List<ColisInTournee> colisInTourneeList = rep.list.map((colis){
          return ColisInTournee(colis:colis);
        }).toList();
        ref.read(colisInTourneeProvider.notifier).setColisInTourneeList(colisInTourneeList);

      }

    } catch (error, stack) {
      safePrint(">>>> loadColis ERROR : error=[$error]");
      state = AsyncValue.error(error, stack);
    }
  }
}

final colisProvider =
    StateNotifierProvider.autoDispose.family<ColisNotifier, AsyncValue<List<Colis>>, String>(
  (ref, tourneeId) {
    // Keep the colis list alive briefly after the last listener leaves so quick
    // navigation transitions don't throw away (and refetch) the whole list.
    final link = ref.keepAlive();
    Timer? timer;
    ref.onCancel(() {
      timer = Timer(const Duration(seconds: 30), link.close);
    });
    ref.onResume(() => timer?.cancel());
    ref.onDispose(() => timer?.cancel());
    return ColisNotifier(tourneeId: tourneeId, ref: ref);
  },
);
