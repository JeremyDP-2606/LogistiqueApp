import 'dart:async';
import 'dart:io';

import 'package:wabap/backend/backend.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wabap/models/Status.dart';
import 'package:wabap/provider/api_providers.dart';
import 'package:wabap/services/local_colis_status_store.dart';

/// Replays locally-stored colis status changes and proof uploads (signatures,
/// damage photos) to the backend.
///
/// Triggered opportunistically (app start, opening a tournee, after the
/// pickup/delivery validation burst, when connectivity returns, or manually).
/// The scheduler is fully cancellable and guards against concurrent / spammy
/// flushes - it must never leak timers the way the screen auto-load loop did.
class ColisStatusSyncService {
  ColisStatusSyncService._();
  static final ColisStatusSyncService instance = ColisStatusSyncService._();

  /// Number of not-yet-synced STATUS changes, for the HomeScreen badge.
  /// (One per colis action - do not add uploads here, that made the badge show
  /// "8 colis" for 4 delivered colis.)
  final ValueNotifier<int> count = ValueNotifier<int>(0);

  /// Number of not-yet-uploaded proof files (signatures / damage photos).
  final ValueNotifier<int> uploadCount = ValueNotifier<int>(0);

  /// Number of DISTINCT colis with anything pending (status or proof). This is
  /// the number shown to drivers - they think in colis, not records.
  final ValueNotifier<int> pendingColisCount = ValueNotifier<int>(0);

  /// Number of tournees whose status intent (IN_PROGRESS/COMPLETED...) has not
  /// reached the backend yet.
  final ValueNotifier<int> tourneeStatusCount = ValueNotifier<int>(0);

  /// True while a flush is running, so the UI can show live feedback.
  final ValueNotifier<bool> isFlushing = ValueNotifier<bool>(false);

  /// Number of parked (dead-letter) entries that need manual attention.
  final ValueNotifier<int> deadLetterCount = ValueNotifier<int>(0);

  StreamSubscription? _connectivitySub;
  bool _flushing = false;

  /// Set when tryFlush(force) arrives while a flush is already running, so the
  /// tap is never silently swallowed: another pass runs right after.
  bool _rerunRequested = false;
  DateTime? _lastFlush;
  bool _initialized = false;

  static const _debounce = Duration(seconds: 30);

  /// Beyond this many failed attempts an entry is parked (dead-letter) instead
  /// of being retried forever.
  static const _maxAttempts = 20;

  /// A status entry older than this is never replayed automatically: the real
  /// world has moved on (the colis was probably handled again) and pushing it
  /// could overwrite a fresher backend status. It is parked for review instead.
  static const _maxStatusAge = Duration(hours: 12);

  /// The completion report gives up much sooner than statuses: a failing
  /// report Lambda must never keep slowing the sync down. The tournee status
  /// itself is already on the backend by then.
  static const _maxRapportAttempts = 3;

  /// Every network call in the flush path is bounded: one hung request froze
  /// the whole flush (and the "Synchronisation…" spinner) forever.
  static const _readTimeout = Duration(seconds: 15);
  static const _writeTimeout = Duration(seconds: 25);
  static const _rapportTimeout = Duration(seconds: 30);

  /// Pure decision used by [flush]: should this status entry be parked
  /// (dead-letter) instead of replayed? Extracted for unit testing.
  @visibleForTesting
  static bool shouldDeadLetterStatus(PendingColisStatus entry, DateTime nowUtc) {
    if (entry.attemptCount >= _maxAttempts) return true;
    if (nowUtc.difference(entry.createdAt) > _maxStatusAge) return true;
    return false;
  }

  /// Progression rank of a tournee status. The lifecycle is monotonic:
  /// PENDING -> IN_PROGRESS -> COMPLETED/ISSUE, and a replayed intent must
  /// never make a tournee go backwards.
  static int rankOfStatus(Status status) {
    switch (status) {
      case Status.PENDING:
      case Status.NOT_PICKED_UP_NOT_EXIST:
        return 0;
      case Status.PICKED_UP:
      case Status.IN_PROGRESS:
        return 1;
      case Status.ISSUE:
      case Status.COMPLETED:
        return 2;
    }
  }

  /// Forward-only replay guard for tournee statuses: push only if the pending
  /// intent moves the tournee FORWARD compared to the backend.
  static bool shouldPushTourneeStatus(Status pending, Status? backend) {
    if (backend == null) return true;
    return rankOfStatus(pending) > rankOfStatus(backend);
  }

  /// Fast offline check (~ms platform call). When the OS reports no network,
  /// don't even ATTEMPT a push: every attempt costs its full timeout + retries
  /// (an offline pickup burst of 200 colis took >8 minutes for nothing - the
  /// data was already safe in SQLite after the first millisecond).
  static Future<bool> hasNetwork() async {
    try {
      return (await Connectivity().checkConnectivity()) !=
          ConnectivityResult.none;
    } catch (_) {
      return true; // if the check itself fails, fall back to trying
    }
  }

  /// Wire up connectivity-based retries. Safe to call more than once.
  void init() {
    if (_initialized) return;
    _initialized = true;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        safePrint('ColisStatusSyncService: connectivity back ($result), flushing');
        tryFlush();
      }
    });
    // Safety sweep so parked entries and their files don't pile up forever.
    // ignore: discarded_futures
    LocalColisStatusStore.instance
        .purgeDeadLettersOlderThan(const Duration(days: 7))
        .catchError((e) => safePrint('ColisStatusSyncService: purge error: $e'));
    refreshCount();
    tryFlush();
  }

  /// Recompute the unsynced/dead-letter counts for the badges.
  Future<void> refreshCount() async {
    try {
      count.value = await LocalColisStatusStore.instance.countUnsynced();
      uploadCount.value =
          await LocalColisStatusStore.instance.countUnsyncedUploads();
      pendingColisCount.value =
          await LocalColisStatusStore.instance.countUnsyncedColis();
      tourneeStatusCount.value =
          await LocalColisStatusStore.instance.countUnsyncedTourneeStatuses();
      deadLetterCount.value = await LocalColisStatusStore.instance.countDeadLetter();
    } catch (e) {
      safePrint('ColisStatusSyncService: refreshCount error: $e');
    }
  }

  /// Debounced, fire-and-forget flush. Pass [force] to ignore the debounce
  /// (e.g. the manual "Réessayer" button).
  void tryFlush({bool force = false}) {
    if (_flushing) {
      // A flush is already running (e.g. triggered by connectivity coming
      // back). Don't swallow a forced tap: run another pass right after.
      if (force) _rerunRequested = true;
      return;
    }
    final last = _lastFlush;
    if (!force && last != null && DateTime.now().difference(last) < _debounce) {
      return;
    }
    // ignore: discarded_futures
    flush();
  }

  /// Push every pending entry once. Returns the number of entries still pending
  /// afterwards.
  Future<int> flush() async {
    if (_flushing) return count.value + uploadCount.value;
    if (!await hasNetwork()) {
      safePrint('ColisStatusSyncService: offline, skipping flush (the connectivity listener will retrigger it)');
      return count.value + uploadCount.value;
    }
    _flushing = true;
    isFlushing.value = true;
    _lastFlush = DateTime.now();
    try {
      // Never push another account's queued work: entries are scoped to the
      // Cognito user that created them.
      final currentUserId = await _currentUserId();
      if (currentUserId == null) {
        safePrint('ColisStatusSyncService: signed out, skipping flush');
        return count.value + uploadCount.value;
      }

      final pending = await LocalColisStatusStore.instance.getPending();
      if (pending.isNotEmpty) {
        safePrint('ColisStatusSyncService: flushing ${pending.length} pending statuses');
      }

      for (final entry in pending) {
        if (entry.enqueuedBy != null && entry.enqueuedBy != currentUserId) {
          continue; // queued by another account; leave it for that account
        }
        if (shouldDeadLetterStatus(entry, DateTime.now().toUtc())) {
          safePrint('ColisStatusSyncService: ${entry.clientId} parked (dead-letter): too old or too many attempts (${entry.attemptCount}), never replayed to avoid overwriting a fresher status');
          await LocalColisStatusStore.instance.markDeadLetter(entry.clientId);
          continue;
        }
        try {
          await _pushEntry(entry);
          // Live decrement so the badge ticks down while the flush runs.
          await refreshCount();
        } catch (e) {
          await LocalColisStatusStore.instance.incrementAttempt(entry.clientId);
          safePrint('ColisStatusSyncService: failed to push ${entry.clientId}: $e');
        }
      }

      // Colis first, tournee second: the tournee status summarises its colis,
      // so the backend always sees a coherent state. Reports come last, only
      // once everything for their tournee has reached the backend.
      safePrint('ColisStatusSyncService: colis statuses phase done');
      await _flushTourneeStatuses(currentUserId);
      safePrint('ColisStatusSyncService: tournee statuses phase done');
      await _flushUploads(currentUserId);
      safePrint('ColisStatusSyncService: uploads phase done');
      await _flushRapports(currentUserId);
      safePrint('ColisStatusSyncService: rapports phase done');

      await refreshCount();
      final remaining = count.value + uploadCount.value;
      safePrint('ColisStatusSyncService: flush done, $remaining still pending');
      return remaining;
    } finally {
      _flushing = false;
      isFlushing.value = false;
      if (_rerunRequested) {
        // A forced flush was requested while this one was running: honor it.
        _rerunRequested = false;
        safePrint('ColisStatusSyncService: rerun requested during flush, flushing again');
        // ignore: discarded_futures
        flush();
      }
    }
  }

  Future<String?> _currentUserId() async {
    try {
      return (await CognitoAuth.instance.currentSession())?.sub;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pushEntry(PendingColisStatus entry) async {
    final colis = await API.getColis(entry.colisId).timeout(_readTimeout);

    // The colis no longer exists: nothing we can do, stop retrying it.
    if (colis == null) {
      safePrint('ColisStatusSyncService: colis ${entry.colisId} gone, dropping entry');
      await LocalColisStatusStore.instance.markSynced(entry.clientId);
      return;
    }

    // The model getter throws when the backend has no lastStatus pointer yet.
    String backendLastStatusId = "";
    try {
      backendLastStatusId = colis.colisLastStatusId;
    } catch (_) {}

    // Already applied (a previous push succeeded but wasn't marked synced).
    if (backendLastStatusId == entry.clientId) {
      await LocalColisStatusStore.instance.markSynced(entry.clientId);
      return;
    }

    // Reconciliation guard: if the backend already has a newer status (e.g. the
    // driver changed it elsewhere, or another device), do not overwrite it.
    // Fail-safe: when the backend timestamp cannot be established, KEEP the
    // entry pending instead of pushing blindly - a blind push is exactly how a
    // delivered colis reverted to "picked up" the next day.
    if (backendLastStatusId.isNotEmpty) {
      DateTime? backendCreatedAt;
      try {
        backendCreatedAt = colis.lastStatus.createdAt.getDateTimeInUtc();
      } catch (_) {
        // lastStatus incomplete on this read - fetch the status row directly.
        try {
          final statusRow =
              await API.getColisStatus(backendLastStatusId).timeout(_readTimeout);
          if (statusRow != null) {
            backendCreatedAt = statusRow.createdAt.getDateTimeInUtc();
          }
        } catch (e) {
          safePrint('ColisStatusSyncService: could not fetch backend status $backendLastStatusId: $e');
        }
      }
      if (backendCreatedAt == null) {
        throw StateError(
            'backend lastStatus createdAt unknown for colis ${entry.colisId}, keeping entry pending');
      }
      if (backendCreatedAt.isAfter(entry.createdAt)) {
        safePrint('ColisStatusSyncService: ${entry.colisId} superseded by newer backend status, dropping');
        await LocalColisStatusStore.instance.markSynced(entry.clientId);
        return;
      }
    }

    await API
        .pushColisStatus(
          colis: colis,
          statusId: entry.clientId,
          status: entry.status,
          message: entry.message,
          latitude: entry.latitude,
          longitude: entry.longitude,
          createdAt: TemporalDateTime(entry.createdAt),
        )
        .timeout(_writeTimeout);
    await LocalColisStatusStore.instance.markSynced(entry.clientId);
  }

  // ---------------------------------------------------------------------------
  // Tournee statuses
  // ---------------------------------------------------------------------------

  Future<void> _flushTourneeStatuses(String currentUserId) async {
    final pending =
        await LocalColisStatusStore.instance.getPendingTourneeStatuses();
    if (pending.isEmpty) return;
    safePrint('ColisStatusSyncService: flushing ${pending.length} pending tournee statuses');

    for (final entry in pending) {
      if (entry.enqueuedBy != null && entry.enqueuedBy != currentUserId) {
        continue;
      }
      if (entry.attemptCount >= _maxAttempts) {
        safePrint('ColisStatusSyncService: tournee ${entry.tourneeId} status exceeded $_maxAttempts attempts, parking (dead-letter)');
        await LocalColisStatusStore.instance
            .markTourneeStatusDeadLetter(entry.tourneeId);
        continue;
      }
      // NOTE: unlike colis statuses there is deliberately NO age guard here -
      // a completion done offline in the evening must still replay the next
      // morning. The forward-only rank guard makes an old intent harmless.
      try {
        final tournee =
            await API.getTournee(entry.tourneeId).timeout(_readTimeout);
        if (tournee == null) {
          safePrint('ColisStatusSyncService: tournee ${entry.tourneeId} gone, dropping status intent');
          await LocalColisStatusStore.instance
              .markTourneeStatusSynced(entry.tourneeId);
          continue;
        }
        Status? backendStatus;
        try {
          backendStatus = tournee.status;
        } catch (_) {}
        if (!shouldPushTourneeStatus(entry.status, backendStatus)) {
          safePrint('ColisStatusSyncService: tournee ${entry.tourneeId} already at/past ${entry.status} on backend, dropping');
          await LocalColisStatusStore.instance
              .markTourneeStatusSynced(entry.tourneeId);
          continue;
        }
        final updated = await API
            .updateTournee(tournee.copyWith(status: entry.status))
            .timeout(_writeTimeout);
        if (updated == null) throw Exception('Tournée non mise à jour');
        await LocalColisStatusStore.instance
            .markTourneeStatusSynced(entry.tourneeId);
        await refreshCount();
      } catch (e) {
        await LocalColisStatusStore.instance
            .incrementTourneeStatusAttempt(entry.tourneeId);
        safePrint('ColisStatusSyncService: failed to push tournee status ${entry.tourneeId}: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Completion reports (secure tournees)
  // ---------------------------------------------------------------------------

  /// Generates the completion report of secure tournees, but ONLY once
  /// everything for the tournee is on the backend (statuses, tournee status,
  /// proofs). Before this, the report was invoked directly at completion: lost
  /// forever when offline, and computed on incomplete data when statuses were
  /// still in the local queue.
  Future<void> _flushRapports(String currentUserId) async {
    final pending =
        await LocalColisStatusStore.instance.getRapportPendingTournees();
    if (pending.isEmpty) return;

    for (final entry in pending) {
      if (entry.enqueuedBy != null && entry.enqueuedBy != currentUserId) {
        continue;
      }
      await _generateRapport(entry);
    }
  }

  /// Attempts the report of one tournee right away - used by the "Terminer la
  /// tournée" button so that with network the report is requested during the
  /// button press (like before), the queue being only the offline fallback.
  /// Returns true on success.
  Future<bool> tryGenerateRapportNow(String tourneeId) async {
    try {
      final pending =
          await LocalColisStatusStore.instance.getRapportPendingTournees();
      PendingTourneeStatus? entry;
      for (final e in pending) {
        if (e.tourneeId == tourneeId) {
          entry = e;
          break;
        }
      }
      if (entry == null) return false;
      return await _generateRapport(entry);
    } catch (e) {
      safePrint('ColisStatusSyncService: tryGenerateRapportNow error: $e');
      return false;
    }
  }

  /// Shared report generation (button press and flush): checks preconditions,
  /// invokes the Lambda, and keeps the attempt bookkeeping consistent.
  Future<bool> _generateRapport(PendingTourneeStatus entry) async {
    // Dedicated LOW cap: a failing report Lambda must never keep slowing the
    // sync down (the tournee status itself is already on the backend).
    if (entry.attemptCount >= _maxRapportAttempts) {
      safePrint('ColisStatusSyncService: rapport for ${entry.tourneeId} exceeded $_maxRapportAttempts attempts, parking (dead-letter)');
      await LocalColisStatusStore.instance
          .markTourneeStatusDeadLetter(entry.tourneeId);
      await refreshCount();
      return false;
    }
    // Everything about the tournee must be synced first; otherwise wait for
    // the next flush (the report would be computed on incomplete data).
    final statusSynced = entry.synced;
    final colisLeft = await LocalColisStatusStore.instance
        .countUnsynced(tourneeId: entry.tourneeId);
    final uploadsLeft = await LocalColisStatusStore.instance
        .countUnsyncedUploads(tourneeId: entry.tourneeId);
    if (!statusSynced || colisLeft > 0 || uploadsLeft > 0) {
      safePrint('ColisStatusSyncService: rapport for ${entry.tourneeId} waiting (statusSynced=$statusSynced, colisLeft=$colisLeft, uploadsLeft=$uploadsLeft)');
      return false;
    }
    try {
      final response = await API
          .invokeLambdaRapportTournee(
              RapportInput(tourneeId: entry.tourneeId, message: ""))
          .timeout(_rapportTimeout);
      if (response.statusCode != 200) {
        throw Exception('Rapport Lambda returned ${response.statusCode}: ${response.message}');
      }
      safePrint('ColisStatusSyncService: rapport generated for tournee ${entry.tourneeId}');
      await LocalColisStatusStore.instance.markRapportDone(entry.tourneeId);
      // The tournee is fully done: drop its confirmed rows (and files).
      await LocalColisStatusStore.instance
          .clearSyncedForTournee(entry.tourneeId);
      await refreshCount();
      return true;
    } catch (e) {
      await LocalColisStatusStore.instance
          .incrementTourneeStatusAttempt(entry.tourneeId);
      safePrint('ColisStatusSyncService: rapport failed for ${entry.tourneeId}: $e');
      await refreshCount();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Proof uploads (signatures / damage photos)
  // ---------------------------------------------------------------------------

  /// Directory owned by the app where proof files wait for their upload.
  Future<Directory> _pendingUploadsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'pending_uploads'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _fileNameForKey(String s3Key) =>
      s3Key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  /// Persists a proof file to disk, queues it, then attempts the upload
  /// immediately. On upload failure the entry stays queued and is replayed by
  /// [flush]. Throws only if the file cannot be persisted locally.
  ///
  /// Provide either [bytes] (signature PNG) or [sourceFile] (damage photo).
  Future<void> saveAndUpload({
    required String s3Key,
    required String tourneeId,
    String? colisId,
    Uint8List? bytes,
    File? sourceFile,
    Duration uploadTimeout = const Duration(seconds: 15),
  }) async {
    assert(bytes != null || sourceFile != null);

    // 1. Persist to a directory we own (the image_picker temp dir can be wiped
    // by the OS at any time).
    final dir = await _pendingUploadsDir();
    final target = File(p.join(dir.path, _fileNameForKey(s3Key)));
    if (bytes != null) {
      await target.writeAsBytes(bytes, flush: true);
    } else {
      await sourceFile!.copy(target.path);
    }

    // 2. Queue it (idempotent on s3Key).
    final entry = PendingUpload(
      s3Key: s3Key,
      tourneeId: tourneeId,
      colisId: colisId,
      filePath: target.path,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
      enqueuedBy: await _currentUserId(),
    );
    await LocalColisStatusStore.instance.upsertPendingUpload(entry);
    refreshCount();

    // 3. Try now (unless offline - the attempt would just burn its timeout);
    // on failure the flush replays it later.
    if (!await hasNetwork()) {
      safePrint('ColisStatusSyncService: offline, $s3Key kept in local queue');
      refreshCount();
      return;
    }
    try {
      await _uploadFile(entry).timeout(uploadTimeout);
      await LocalColisStatusStore.instance.markUploadSynced(s3Key);
    } catch (e) {
      await LocalColisStatusStore.instance.incrementUploadAttempt(s3Key);
      safePrint('ColisStatusSyncService: upload of $s3Key failed (kept in local queue): $e');
    }
    refreshCount();
  }

  Future<void> _flushUploads(String currentUserId) async {
    final uploads = await LocalColisStatusStore.instance.getPendingUploads();
    if (uploads.isEmpty) return;
    safePrint('ColisStatusSyncService: flushing ${uploads.length} pending uploads');

    for (final entry in uploads) {
      if (entry.enqueuedBy != null && entry.enqueuedBy != currentUserId) {
        continue;
      }
      if (entry.attemptCount >= _maxAttempts) {
        safePrint('ColisStatusSyncService: upload ${entry.s3Key} exceeded $_maxAttempts attempts, parking (dead-letter)');
        await LocalColisStatusStore.instance.markUploadDeadLetter(entry.s3Key);
        continue;
      }
      if (!await File(entry.filePath).exists()) {
        safePrint('ColisStatusSyncService: file for ${entry.s3Key} is gone, parking (dead-letter)');
        await LocalColisStatusStore.instance.markUploadDeadLetter(entry.s3Key);
        continue;
      }
      try {
        await _uploadFile(entry).timeout(const Duration(seconds: 30));
        await LocalColisStatusStore.instance.markUploadSynced(entry.s3Key);
        // Live decrement so the badge ticks down while the flush runs.
        await refreshCount();
      } catch (e) {
        await LocalColisStatusStore.instance.incrementUploadAttempt(entry.s3Key);
        safePrint('ColisStatusSyncService: failed to upload ${entry.s3Key}: $e');
      }
    }
  }

  Future<void> _uploadFile(PendingUpload entry) async {
    // Même emplacement qu'avant (public/<clé>) : lien d'envoi temporaire demandé à l'API
    final bytes = await File(entry.filePath).readAsBytes();
    await Api.upload(bytes, kind: 'preuve', contentType: 'image/jpeg', key: entry.s3Key);
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _initialized = false;
  }
}
