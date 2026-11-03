import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wabap/models/Status.dart';
import 'package:wabap/services/colis_status_sync_service.dart';
import 'package:wabap/services/local_colis_status_store.dart';

PendingColisStatus entry({
  String clientId = 'c1',
  String colisId = 'colis1',
  String tourneeId = 't1',
  Status status = Status.PICKED_UP,
  DateTime? createdAt,
  int attemptCount = 0,
  String? enqueuedBy,
}) {
  return PendingColisStatus(
    clientId: clientId,
    colisId: colisId,
    tourneeId: tourneeId,
    status: status,
    createdAtIso:
        (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
    attemptCount: attemptCount,
    enqueuedBy: enqueuedBy,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Run SQLite on the Dart VM instead of a device.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final store = LocalColisStatusStore.instance;

  setUp(() async {
    // Fresh DB per test.
    await store.resetForTesting();
    final dir = await getDatabasesPath();
    await databaseFactory.deleteDatabase('$dir/wabap_pending_status.db');
  });

  group('PendingColisStatus (de)serialization', () {
    test('round-trips every field', () {
      final original = entry(
        clientId: 'abc',
        attemptCount: 3,
        enqueuedBy: 'user-1',
        createdAt: DateTime.utc(2026, 7, 11, 8, 30),
      );
      final copy = PendingColisStatus.fromMap(original.toMap());
      expect(copy.clientId, original.clientId);
      expect(copy.colisId, original.colisId);
      expect(copy.tourneeId, original.tourneeId);
      expect(copy.status, original.status);
      expect(copy.createdAt, original.createdAt);
      expect(copy.attemptCount, original.attemptCount);
      expect(copy.enqueuedBy, original.enqueuedBy);
      expect(copy.synced, isFalse);
      expect(copy.deadLetter, isFalse);
    });
  });

  group('pending queue', () {
    test('upsert is idempotent on clientId', () async {
      await store.upsertPending(entry());
      await store.upsertPending(entry());
      expect(await store.countUnsynced(), 1);
    });

    test('markSynced removes the entry from the pending set', () async {
      await store.upsertPending(entry());
      await store.markSynced('c1');
      expect(await store.countUnsynced(), 0);
      expect(await store.getPending(), isEmpty);
    });

    test('dead-letter entries are excluded from replay and counted separately',
        () async {
      await store.upsertPending(entry(clientId: 'c1'));
      await store.upsertPending(entry(clientId: 'c2', colisId: 'colis2'));
      await store.markDeadLetter('c1');

      final pending = await store.getPending();
      expect(pending.map((e) => e.clientId), ['c2']);
      expect(await store.countUnsynced(), 1);
      expect(await store.countDeadLetter(), 1);
    });

    test('getPending replays oldest first', () async {
      final now = DateTime.now().toUtc();
      await store.upsertPending(entry(
          clientId: 'newer', createdAt: now));
      await store.upsertPending(entry(
          clientId: 'older',
          colisId: 'colis2',
          createdAt: now.subtract(const Duration(minutes: 5))));
      final pending = await store.getPending();
      expect(pending.map((e) => e.clientId), ['older', 'newer']);
    });

    test('getLatestUnsyncedByColis keeps the newest entry per colis', () async {
      final now = DateTime.now().toUtc();
      await store.upsertPending(entry(
          clientId: 'old',
          status: Status.PICKED_UP,
          createdAt: now.subtract(const Duration(minutes: 5))));
      await store.upsertPending(entry(
          clientId: 'new', status: Status.COMPLETED, createdAt: now));
      final latest = await store.getLatestUnsyncedByColis('t1');
      expect(latest['colis1']!.clientId, 'new');
      expect(latest['colis1']!.status, Status.COMPLETED);
    });

    test('clearSyncedForTournee deletes only synced rows of that tournee',
        () async {
      await store.upsertPending(entry(clientId: 'synced1'));
      await store.upsertPending(entry(clientId: 'pending1', colisId: 'colis2'));
      await store.upsertPending(
          entry(clientId: 'other', tourneeId: 't2', colisId: 'colis3'));
      await store.markSynced('synced1');

      await store.clearSyncedForTournee('t1');

      // The pending row of t1 and everything of t2 survive.
      expect(await store.countUnsynced(tourneeId: 't1'), 1);
      expect(await store.countUnsynced(tourneeId: 't2'), 1);
    });
  });

  group('upload queue', () {
    PendingUpload upload({String s3Key = 'tournee_t1/sig.jpg'}) => PendingUpload(
          s3Key: s3Key,
          tourneeId: 't1',
          colisId: 'colis1',
          filePath: '/nonexistent/sig.jpg',
          createdAtIso: DateTime.now().toUtc().toIso8601String(),
        );

    test('upsert is idempotent on s3Key', () async {
      await store.upsertPendingUpload(upload());
      await store.upsertPendingUpload(upload());
      expect(await store.countUnsyncedUploads(), 1);
    });

    test('markUploadSynced removes it from the pending set', () async {
      await store.upsertPendingUpload(upload());
      await store.markUploadSynced('tournee_t1/sig.jpg');
      expect(await store.countUnsyncedUploads(), 0);
    });

    test('dead-letter uploads are excluded and counted', () async {
      await store.upsertPendingUpload(upload());
      await store.markUploadDeadLetter('tournee_t1/sig.jpg');
      expect(await store.countUnsyncedUploads(), 0);
      expect(await store.getPendingUploads(), isEmpty);
      expect(await store.countDeadLetter(), 1);
    });
  });

  group('countUnsyncedColis (what the driver sees)', () {
    PendingUpload upload({required String s3Key, String? colisId}) =>
        PendingUpload(
          s3Key: s3Key,
          tourneeId: 't1',
          colisId: colisId,
          filePath: '/nonexistent/$s3Key',
          createdAtIso: DateTime.now().toUtc().toIso8601String(),
        );

    test('one colis with a status + several proofs counts as ONE colis',
        () async {
      await store.upsertPending(entry(clientId: 'c1', colisId: 'colis1'));
      await store
          .upsertPendingUpload(upload(s3Key: 'sig.jpg', colisId: 'colis1'));
      await store
          .upsertPendingUpload(upload(s3Key: 'photo.jpg', colisId: 'colis1'));
      expect(await store.countUnsyncedColis(), 1);
    });

    test('4 colis with statuses + 6 proofs counts as 4 colis (field scenario)',
        () async {
      for (var i = 1; i <= 4; i++) {
        await store.upsertPending(entry(clientId: 'c$i', colisId: 'colis$i'));
        await store.upsertPendingUpload(
            upload(s3Key: 'sig$i.jpg', colisId: 'colis$i'));
      }
      await store.upsertPendingUpload(
          upload(s3Key: 'photo1.jpg', colisId: 'colis1'));
      await store.upsertPendingUpload(
          upload(s3Key: 'photo2.jpg', colisId: 'colis2'));
      expect(await store.countUnsyncedColis(), 4);
    });

    test('synced and dead-letter entries are excluded', () async {
      await store.upsertPending(entry(clientId: 'c1', colisId: 'colis1'));
      await store.upsertPending(entry(clientId: 'c2', colisId: 'colis2'));
      await store.markSynced('c1');
      await store.markDeadLetter('c2');
      expect(await store.countUnsyncedColis(), 0);
    });

    test('tournee-level uploads (colisId NULL) are not counted as colis',
        () async {
      await store.upsertPendingUpload(
          upload(s3Key: 'signature_picking.jpg', colisId: null));
      expect(await store.countUnsyncedColis(), 0);
      // ...but the item itself is still pending (UI shows the generic message).
      expect(await store.countUnsyncedUploads(), 1);
    });

    test('filters by tournee when tourneeId is given', () async {
      await store.upsertPending(entry(clientId: 'c1', colisId: 'colis1'));
      await store.upsertPending(
          entry(clientId: 'c2', colisId: 'colis2', tourneeId: 't2'));
      expect(await store.countUnsyncedColis(tourneeId: 't1'), 1);
      expect(await store.countUnsyncedColis(tourneeId: 't2'), 1);
      expect(await store.countUnsyncedColis(), 2);
    });
  });

  group('pending tournee status (latest intent per tournee)', () {
    PendingTourneeStatus intent(
            {String tourneeId = 't1',
            Status status = Status.IN_PROGRESS}) =>
        PendingTourneeStatus(
          tourneeId: tourneeId,
          status: status,
          createdAtIso: DateTime.now().toUtc().toIso8601String(),
        );

    test('upsert is latest-wins: one row per tournee', () async {
      await store.upsertPendingTourneeStatus(
          intent(status: Status.IN_PROGRESS));
      await store
          .upsertPendingTourneeStatus(intent(status: Status.COMPLETED));
      final pending = await store.getPendingTourneeStatuses();
      expect(pending.length, 1);
      expect(pending.single.status, Status.COMPLETED);
      expect(await store.countUnsyncedTourneeStatuses(), 1);
    });

    test('synced and dead-letter intents are excluded', () async {
      await store.upsertPendingTourneeStatus(intent(tourneeId: 't1'));
      await store.upsertPendingTourneeStatus(intent(tourneeId: 't2'));
      await store.markTourneeStatusSynced('t1');
      await store.markTourneeStatusDeadLetter('t2');
      expect(await store.countUnsyncedTourneeStatuses(), 0);
      expect(await store.getPendingTourneeStatuses(), isEmpty);
      expect(await store.countDeadLetter(), 1);
    });

    test('clearSyncedForTournee removes the synced tournee intent', () async {
      await store.upsertPendingTourneeStatus(intent(tourneeId: 't1'));
      await store.markTourneeStatusSynced('t1');
      await store.clearSyncedForTournee('t1');
      // Re-upsert unsynced: must be a fresh row, not blocked by leftovers.
      await store.upsertPendingTourneeStatus(intent(tourneeId: 't1'));
      expect(await store.countUnsyncedTourneeStatuses(tourneeId: 't1'), 1);
    });

    test('rapportPending keeps the tournee "not done" even once synced',
        () async {
      await store.upsertPendingTourneeStatus(PendingTourneeStatus(
        tourneeId: 't1',
        status: Status.COMPLETED,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
        rapportPending: true,
      ));
      await store.markTourneeStatusSynced('t1');
      // Still counted: the report has not been generated yet.
      expect(await store.countUnsyncedTourneeStatuses(tourneeId: 't1'), 1);
      expect((await store.getRapportPendingTournees()).length, 1);
      // clearSyncedForTournee must NOT drop the row while the report waits.
      await store.clearSyncedForTournee('t1');
      expect((await store.getRapportPendingTournees()).length, 1);

      await store.markRapportDone('t1');
      expect(await store.countUnsyncedTourneeStatuses(tourneeId: 't1'), 0);
      expect(await store.getRapportPendingTournees(), isEmpty);
      // Now the fully-done row can be cleared.
      await store.clearSyncedForTournee('t1');
      expect(await store.getPendingTourneeStatuses(), isEmpty);
    });

    test('includeRapportPending: false counts only real unsynced data',
        () async {
      // Synced status but report still to generate: badge counts it, the
      // completion dialog must NOT.
      await store.upsertPendingTourneeStatus(PendingTourneeStatus(
        tourneeId: 't1',
        status: Status.COMPLETED,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
        rapportPending: true,
      ));
      await store.markTourneeStatusSynced('t1');
      expect(await store.countUnsyncedTourneeStatuses(tourneeId: 't1'), 1);
      expect(
          await store.countUnsyncedTourneeStatuses(
              tourneeId: 't1', includeRapportPending: false),
          0);

      // Truly unsynced status: counted in both modes.
      await store.upsertPendingTourneeStatus(PendingTourneeStatus(
        tourneeId: 't2',
        status: Status.COMPLETED,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
      ));
      expect(await store.countUnsyncedTourneeStatuses(tourneeId: 't2'), 1);
      expect(
          await store.countUnsyncedTourneeStatuses(
              tourneeId: 't2', includeRapportPending: false),
          1);
    });

    test('markTourneeStatusSynced resets attemptCount (fresh counter for the report)',
        () async {
      await store.upsertPendingTourneeStatus(PendingTourneeStatus(
        tourneeId: 't1',
        status: Status.COMPLETED,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
        rapportPending: true,
      ));
      // Simulate failed status pushes consuming the counter.
      await store.incrementTourneeStatusAttempt('t1');
      await store.incrementTourneeStatusAttempt('t1');
      await store.incrementTourneeStatusAttempt('t1');
      await store.markTourneeStatusSynced('t1');
      final row = (await store.getRapportPendingTournees()).single;
      expect(row.synced, isTrue);
      expect(row.attemptCount, 0);
    });

    test('dead-letter rapport rows are excluded from generation', () async {
      await store.upsertPendingTourneeStatus(PendingTourneeStatus(
        tourneeId: 't1',
        status: Status.COMPLETED,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
        rapportPending: true,
      ));
      await store.markTourneeStatusDeadLetter('t1');
      expect(await store.getRapportPendingTournees(), isEmpty);
      expect(await store.countDeadLetter(), 1);
    });
  });

  group('ColisStatusSyncService.shouldPushTourneeStatus (forward-only)', () {
    test('IN_PROGRESS over PENDING is pushed', () {
      expect(
          ColisStatusSyncService.shouldPushTourneeStatus(
              Status.IN_PROGRESS, Status.PENDING),
          isTrue);
    });

    test('IN_PROGRESS over COMPLETED is dropped (never go backwards)', () {
      expect(
          ColisStatusSyncService.shouldPushTourneeStatus(
              Status.IN_PROGRESS, Status.COMPLETED),
          isFalse);
    });

    test('COMPLETED over IN_PROGRESS is pushed', () {
      expect(
          ColisStatusSyncService.shouldPushTourneeStatus(
              Status.COMPLETED, Status.IN_PROGRESS),
          isTrue);
    });

    test('COMPLETED over COMPLETED is dropped (already applied)', () {
      expect(
          ColisStatusSyncService.shouldPushTourneeStatus(
              Status.COMPLETED, Status.COMPLETED),
          isFalse);
    });

    test('unknown backend status defaults to push', () {
      expect(
          ColisStatusSyncService.shouldPushTourneeStatus(
              Status.IN_PROGRESS, null),
          isTrue);
    });
  });

  group('ColisStatusSyncService.shouldDeadLetterStatus', () {
    final now = DateTime.utc(2026, 7, 11, 12, 0);

    test('fresh entry with few attempts is replayed', () {
      final e = entry(createdAt: now.subtract(const Duration(minutes: 3)));
      expect(ColisStatusSyncService.shouldDeadLetterStatus(e, now), isFalse);
    });

    test('entry older than 12h is parked (next-day revert scenario)', () {
      final e = entry(createdAt: now.subtract(const Duration(hours: 20)));
      expect(ColisStatusSyncService.shouldDeadLetterStatus(e, now), isTrue);
    });

    test('entry just under the age limit is still replayed', () {
      final e = entry(createdAt: now.subtract(const Duration(hours: 11)));
      expect(ColisStatusSyncService.shouldDeadLetterStatus(e, now), isFalse);
    });

    test('entry with too many attempts is parked', () {
      final e = entry(createdAt: now, attemptCount: 20);
      expect(ColisStatusSyncService.shouldDeadLetterStatus(e, now), isTrue);
    });
  });
}
