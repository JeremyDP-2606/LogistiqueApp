import 'dart:io';

import 'package:wabap/backend/backend.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:wabap/models/Status.dart';

/// A single colis status change waiting to be confirmed on the backend.
///
/// [clientId] is generated once on the device and reused on every retry. It is
/// also used as the id of the `ColisStatus` row created on the backend, which
/// makes the whole push idempotent: re-pushing the same entry never creates a
/// duplicate.
class PendingColisStatus {
  final String clientId;
  final String colisId;
  final String tourneeId;
  final String? owner;
  final Status status;
  final String? message;
  final double? latitude;
  final double? longitude;

  /// ISO-8601 (UTC) timestamp of when the status change happened on the device.
  final String createdAtIso;
  final bool synced;
  final int attemptCount;

  /// Entry parked for manual review: too old or too many failed attempts. Kept
  /// as a trace but never replayed automatically (it could overwrite a fresher
  /// backend status).
  final bool deadLetter;

  /// Cognito sub of the account that queued this entry, so one driver's pending
  /// statuses are never pushed under another driver's session.
  final String? enqueuedBy;

  const PendingColisStatus({
    required this.clientId,
    required this.colisId,
    required this.tourneeId,
    required this.status,
    required this.createdAtIso,
    this.owner,
    this.message,
    this.latitude,
    this.longitude,
    this.synced = false,
    this.attemptCount = 0,
    this.deadLetter = false,
    this.enqueuedBy,
  });

  DateTime get createdAt => DateTime.parse(createdAtIso);

  Map<String, Object?> toMap() => {
        'clientId': clientId,
        'colisId': colisId,
        'tourneeId': tourneeId,
        'owner': owner,
        'status': status.name,
        'message': message,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': createdAtIso,
        'synced': synced ? 1 : 0,
        'attemptCount': attemptCount,
        'deadLetter': deadLetter ? 1 : 0,
        'enqueuedBy': enqueuedBy,
      };

  factory PendingColisStatus.fromMap(Map<String, Object?> map) {
    return PendingColisStatus(
      clientId: map['clientId'] as String,
      colisId: map['colisId'] as String,
      tourneeId: map['tourneeId'] as String,
      owner: map['owner'] as String?,
      status: Status.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => Status.PENDING,
      ),
      message: map['message'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      createdAtIso: map['createdAt'] as String,
      synced: (map['synced'] as int? ?? 0) == 1,
      attemptCount: map['attemptCount'] as int? ?? 0,
      deadLetter: (map['deadLetter'] as int? ?? 0) == 1,
      enqueuedBy: map['enqueuedBy'] as String?,
    );
  }
}

/// A proof file (signature or damage photo) persisted on disk and waiting to be
/// uploaded to S3. [s3Key] is the primary key: re-uploading the same key simply
/// overwrites the same S3 object, so replays are idempotent.
class PendingUpload {
  final String s3Key;
  final String tourneeId;
  final String? colisId;
  final String filePath;
  final String createdAtIso;
  final bool synced;
  final int attemptCount;
  final bool deadLetter;
  final String? enqueuedBy;

  const PendingUpload({
    required this.s3Key,
    required this.tourneeId,
    required this.filePath,
    required this.createdAtIso,
    this.colisId,
    this.synced = false,
    this.attemptCount = 0,
    this.deadLetter = false,
    this.enqueuedBy,
  });

  DateTime get createdAt => DateTime.parse(createdAtIso);

  Map<String, Object?> toMap() => {
        's3Key': s3Key,
        'tourneeId': tourneeId,
        'colisId': colisId,
        'filePath': filePath,
        'createdAt': createdAtIso,
        'synced': synced ? 1 : 0,
        'attemptCount': attemptCount,
        'deadLetter': deadLetter ? 1 : 0,
        'enqueuedBy': enqueuedBy,
      };

  factory PendingUpload.fromMap(Map<String, Object?> map) {
    return PendingUpload(
      s3Key: map['s3Key'] as String,
      tourneeId: map['tourneeId'] as String,
      colisId: map['colisId'] as String?,
      filePath: map['filePath'] as String,
      createdAtIso: map['createdAt'] as String,
      synced: (map['synced'] as int? ?? 0) == 1,
      attemptCount: map['attemptCount'] as int? ?? 0,
      deadLetter: (map['deadLetter'] as int? ?? 0) == 1,
      enqueuedBy: map['enqueuedBy'] as String?,
    );
  }
}

/// The latest intended status for a tournee (PENDING -> IN_PROGRESS ->
/// COMPLETED/ISSUE), waiting to be confirmed on the backend. One row per
/// tournee: a newer intent simply replaces the previous one.
class PendingTourneeStatus {
  final String tourneeId;
  final Status status;
  final String createdAtIso;
  final bool synced;
  final int attemptCount;
  final bool deadLetter;
  final String? enqueuedBy;

  /// True while the tournee report (Lambda) still has to be generated. Set at
  /// completion of a secure tournee; the sync service invokes the report only
  /// once EVERYTHING for the tournee is synced, then clears this flag.
  final bool rapportPending;

  const PendingTourneeStatus({
    required this.tourneeId,
    required this.status,
    required this.createdAtIso,
    this.synced = false,
    this.attemptCount = 0,
    this.deadLetter = false,
    this.enqueuedBy,
    this.rapportPending = false,
  });

  DateTime get createdAt => DateTime.parse(createdAtIso);

  Map<String, Object?> toMap() => {
        'tourneeId': tourneeId,
        'status': status.name,
        'createdAt': createdAtIso,
        'synced': synced ? 1 : 0,
        'attemptCount': attemptCount,
        'deadLetter': deadLetter ? 1 : 0,
        'enqueuedBy': enqueuedBy,
        'rapportPending': rapportPending ? 1 : 0,
      };

  factory PendingTourneeStatus.fromMap(Map<String, Object?> map) {
    return PendingTourneeStatus(
      tourneeId: map['tourneeId'] as String,
      status: Status.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => Status.PENDING,
      ),
      createdAtIso: map['createdAt'] as String,
      synced: (map['synced'] as int? ?? 0) == 1,
      attemptCount: map['attemptCount'] as int? ?? 0,
      deadLetter: (map['deadLetter'] as int? ?? 0) == 1,
      enqueuedBy: map['enqueuedBy'] as String?,
      rapportPending: (map['rapportPending'] as int? ?? 0) == 1,
    );
  }
}

/// Persistent local store (SQLite) for colis status changes and proof uploads.
///
/// Status writes and proof files are saved here first so that they survive bad
/// connectivity and app restarts, then pushed to the backend by
/// [ColisStatusSyncService].
class LocalColisStatusStore {
  LocalColisStatusStore._();
  static final LocalColisStatusStore instance = LocalColisStatusStore._();

  static const _table = 'pending_colis_status';
  static const _uploadsTable = 'pending_uploads';
  static const _tourneeTable = 'pending_tournee_status';
  Database? _db;

  /// Closes the cached connection so tests can start from a fresh database.
  @visibleForTesting
  Future<void> resetForTesting() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'wabap_pending_status.db');
    final db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            clientId TEXT PRIMARY KEY,
            colisId TEXT NOT NULL,
            tourneeId TEXT NOT NULL,
            owner TEXT,
            status TEXT NOT NULL,
            message TEXT,
            latitude REAL,
            longitude REAL,
            createdAt TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            attemptCount INTEGER NOT NULL DEFAULT 0,
            deadLetter INTEGER NOT NULL DEFAULT 0,
            enqueuedBy TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_${_table}_tournee_synced ON $_table (tourneeId, synced)');
        await db.execute(
            'CREATE INDEX idx_${_table}_colis ON $_table (colisId)');
        await _createUploadsTable(db);
        await _createTourneeTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE $_table ADD COLUMN deadLetter INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE $_table ADD COLUMN enqueuedBy TEXT');
          await _createUploadsTable(db);
        }
        if (oldVersion < 3) {
          await _createTourneeTable(db);
        }
        if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE $_tourneeTable ADD COLUMN rapportPending INTEGER NOT NULL DEFAULT 0');
        }
      },
    );
    _db = db;
    return db;
  }

  Future<void> _createUploadsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_uploadsTable (
        s3Key TEXT PRIMARY KEY,
        tourneeId TEXT NOT NULL,
        colisId TEXT,
        filePath TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        attemptCount INTEGER NOT NULL DEFAULT 0,
        deadLetter INTEGER NOT NULL DEFAULT 0,
        enqueuedBy TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_${_uploadsTable}_tournee_synced ON $_uploadsTable (tourneeId, synced)');
  }

  Future<void> _createTourneeTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_tourneeTable (
        tourneeId TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        attemptCount INTEGER NOT NULL DEFAULT 0,
        deadLetter INTEGER NOT NULL DEFAULT 0,
        enqueuedBy TEXT,
        rapportPending INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // Statuses
  // ---------------------------------------------------------------------------

  /// Insert or replace a pending entry. Called on every status action and every
  /// retry (same [PendingColisStatus.clientId]), so it must be idempotent.
  Future<void> upsertPending(PendingColisStatus entry) async {
    final db = await _database;
    await db.insert(
      _table,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markSynced(String clientId) async {
    final db = await _database;
    await db.update(
      _table,
      {'synced': 1},
      where: 'clientId = ?',
      whereArgs: [clientId],
    );
  }

  Future<void> incrementAttempt(String clientId) async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE $_table SET attemptCount = attemptCount + 1 WHERE clientId = ?',
      [clientId],
    );
  }

  /// Park an entry: kept as a trace but excluded from every future flush.
  Future<void> markDeadLetter(String clientId) async {
    final db = await _database;
    await db.update(
      _table,
      {'deadLetter': 1},
      where: 'clientId = ?',
      whereArgs: [clientId],
    );
  }

  /// All not-yet-synced, non-dead-letter entries, optionally restricted to a
  /// tournee, oldest first (so statuses are replayed in the order they
  /// happened).
  Future<List<PendingColisStatus>> getPending({String? tourneeId}) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: tourneeId == null
          ? 'synced = 0 AND deadLetter = 0'
          : 'synced = 0 AND deadLetter = 0 AND tourneeId = ?',
      whereArgs: tourneeId == null ? null : [tourneeId],
      orderBy: 'createdAt ASC',
    );
    return rows.map(PendingColisStatus.fromMap).toList();
  }

  /// The latest unsynced entry per colis for a tournee, keyed by colisId. Used
  /// to overlay local (not-yet-confirmed) statuses on top of the backend list.
  Future<Map<String, PendingColisStatus>> getLatestUnsyncedByColis(
      String tourneeId) async {
    final pending = await getPending(tourneeId: tourneeId);
    final Map<String, PendingColisStatus> latest = {};
    for (final entry in pending) {
      final existing = latest[entry.colisId];
      if (existing == null ||
          entry.createdAt.isAfter(existing.createdAt)) {
        latest[entry.colisId] = entry;
      }
    }
    return latest;
  }

  Future<int> countUnsynced({String? tourneeId}) async {
    final db = await _database;
    final result = await db.rawQuery(
      tourneeId == null
          ? 'SELECT COUNT(*) AS c FROM $_table WHERE synced = 0 AND deadLetter = 0'
          : 'SELECT COUNT(*) AS c FROM $_table WHERE synced = 0 AND deadLetter = 0 AND tourneeId = ?',
      tourneeId == null ? null : [tourneeId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Uploads (signatures / damage photos)
  // ---------------------------------------------------------------------------

  Future<void> upsertPendingUpload(PendingUpload entry) async {
    final db = await _database;
    await db.insert(
      _uploadsTable,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Marks the upload confirmed and removes its file from disk.
  Future<void> markUploadSynced(String s3Key) async {
    final db = await _database;
    final rows = await db.query(
      _uploadsTable,
      columns: ['filePath'],
      where: 's3Key = ?',
      whereArgs: [s3Key],
    );
    await db.update(
      _uploadsTable,
      {'synced': 1},
      where: 's3Key = ?',
      whereArgs: [s3Key],
    );
    for (final row in rows) {
      await _deleteFileQuietly(row['filePath'] as String?);
    }
  }

  Future<void> incrementUploadAttempt(String s3Key) async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE $_uploadsTable SET attemptCount = attemptCount + 1 WHERE s3Key = ?',
      [s3Key],
    );
  }

  Future<void> markUploadDeadLetter(String s3Key) async {
    final db = await _database;
    await db.update(
      _uploadsTable,
      {'deadLetter': 1},
      where: 's3Key = ?',
      whereArgs: [s3Key],
    );
  }

  Future<List<PendingUpload>> getPendingUploads({String? tourneeId}) async {
    final db = await _database;
    final rows = await db.query(
      _uploadsTable,
      where: tourneeId == null
          ? 'synced = 0 AND deadLetter = 0'
          : 'synced = 0 AND deadLetter = 0 AND tourneeId = ?',
      whereArgs: tourneeId == null ? null : [tourneeId],
      orderBy: 'createdAt ASC',
    );
    return rows.map(PendingUpload.fromMap).toList();
  }

  Future<int> countUnsyncedUploads({String? tourneeId}) async {
    final db = await _database;
    final result = await db.rawQuery(
      tourneeId == null
          ? 'SELECT COUNT(*) AS c FROM $_uploadsTable WHERE synced = 0 AND deadLetter = 0'
          : 'SELECT COUNT(*) AS c FROM $_uploadsTable WHERE synced = 0 AND deadLetter = 0 AND tourneeId = ?',
      tourneeId == null ? null : [tourneeId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Tournee status (latest intended status, one row per tournee)
  // ---------------------------------------------------------------------------

  /// Records the latest intended status for a tournee. Replaces any previous
  /// intent for the same tournee (the progression is monotonic, only the most
  /// recent one matters).
  Future<void> upsertPendingTourneeStatus(PendingTourneeStatus entry) async {
    final db = await _database;
    await db.insert(
      _tourneeTable,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Also resets [attemptCount]: the counter may have been consumed by failed
  /// status pushes, and the report (which reuses it afterwards, with a lower
  /// cap) must start from zero.
  Future<void> markTourneeStatusSynced(String tourneeId) async {
    final db = await _database;
    await db.update(
      _tourneeTable,
      {'synced': 1, 'attemptCount': 0},
      where: 'tourneeId = ?',
      whereArgs: [tourneeId],
    );
  }

  Future<void> incrementTourneeStatusAttempt(String tourneeId) async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE $_tourneeTable SET attemptCount = attemptCount + 1 WHERE tourneeId = ?',
      [tourneeId],
    );
  }

  Future<void> markTourneeStatusDeadLetter(String tourneeId) async {
    final db = await _database;
    await db.update(
      _tourneeTable,
      {'deadLetter': 1},
      where: 'tourneeId = ?',
      whereArgs: [tourneeId],
    );
  }

  Future<List<PendingTourneeStatus>> getPendingTourneeStatuses() async {
    final db = await _database;
    final rows = await db.query(
      _tourneeTable,
      where: 'synced = 0 AND deadLetter = 0',
      orderBy: 'createdAt ASC',
    );
    return rows.map(PendingTourneeStatus.fromMap).toList();
  }

  /// The pending (unsynced) status intent for one tournee, if any. Used to
  /// overlay the local intent on top of the backend list.
  Future<Map<String, PendingTourneeStatus>> getUnsyncedTourneeStatuses() async {
    final pending = await getPendingTourneeStatuses();
    return {for (final entry in pending) entry.tourneeId: entry};
  }

  /// A tournee counts as "not done" while its status is unsynced OR its report
  /// still has to be generated - the driver sees it as "en attente de
  /// validation" either way (badge). Pass [includeRapportPending] = false to
  /// count only real unsynced DATA (used by the completion dialog: a report
  /// that simply hasn't been generated yet is not "unsynced data").
  Future<int> countUnsyncedTourneeStatuses(
      {String? tourneeId, bool includeRapportPending = true}) async {
    final db = await _database;
    final pendingClause = includeRapportPending
        ? '(synced = 0 OR rapportPending = 1)'
        : 'synced = 0';
    final result = await db.rawQuery(
      tourneeId == null
          ? 'SELECT COUNT(*) AS c FROM $_tourneeTable WHERE $pendingClause AND deadLetter = 0'
          : 'SELECT COUNT(*) AS c FROM $_tourneeTable WHERE $pendingClause AND deadLetter = 0 AND tourneeId = ?',
      tourneeId == null ? null : [tourneeId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Tournees whose report still has to be generated (status may already be
  /// synced - that's precisely the normal case before the report).
  Future<List<PendingTourneeStatus>> getRapportPendingTournees() async {
    final db = await _database;
    final rows = await db.query(
      _tourneeTable,
      where: 'rapportPending = 1 AND deadLetter = 0',
      orderBy: 'createdAt ASC',
    );
    return rows.map(PendingTourneeStatus.fromMap).toList();
  }

  Future<void> markRapportDone(String tourneeId) async {
    final db = await _database;
    await db.update(
      _tourneeTable,
      {'rapportPending': 0},
      where: 'tourneeId = ?',
      whereArgs: [tourneeId],
    );
  }

  /// Number of DISTINCT colis with at least one pending element (status,
  /// signature or photo). This is what drivers see: they think in colis, not
  /// in technical records. Tournee-level uploads (colisId NULL, e.g. the
  /// pickup signature) are not counted here.
  Future<int> countUnsyncedColis({String? tourneeId}) async {
    final db = await _database;
    final tourneeFilter = tourneeId == null ? '' : ' AND tourneeId = ?';
    final args = tourneeId == null ? null : [tourneeId, tourneeId];
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ('
      'SELECT colisId FROM $_table WHERE synced = 0 AND deadLetter = 0$tourneeFilter '
      'UNION '
      'SELECT colisId FROM $_uploadsTable WHERE synced = 0 AND deadLetter = 0 AND colisId IS NOT NULL$tourneeFilter'
      ')',
      args,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Number of parked (dead-letter) entries across statuses and uploads, for
  /// the "à vérifier" indicator.
  Future<int> countDeadLetter() async {
    final db = await _database;
    final statuses = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) AS c FROM $_table WHERE deadLetter = 1')) ??
        0;
    final uploads = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) AS c FROM $_uploadsTable WHERE deadLetter = 1')) ??
        0;
    final tournees = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) AS c FROM $_tourneeTable WHERE deadLetter = 1')) ??
        0;
    return statuses + uploads + tournees;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Remove confirmed-synced rows (statuses and uploads) for a tournee, called
  /// when the tournee is completed. Unsynced rows are deliberately kept so
  /// nothing is ever lost.
  Future<void> clearSyncedForTournee(String tourneeId) async {
    final db = await _database;
    final deleted = await db.delete(
      _table,
      where: 'tourneeId = ? AND synced = 1',
      whereArgs: [tourneeId],
    );
    final uploadRows = await db.query(
      _uploadsTable,
      columns: ['filePath'],
      where: 'tourneeId = ? AND synced = 1',
      whereArgs: [tourneeId],
    );
    for (final row in uploadRows) {
      await _deleteFileQuietly(row['filePath'] as String?);
    }
    final deletedUploads = await db.delete(
      _uploadsTable,
      where: 'tourneeId = ? AND synced = 1',
      whereArgs: [tourneeId],
    );
    // Keep the row while the report still has to be generated.
    await db.delete(
      _tourneeTable,
      where: 'tourneeId = ? AND synced = 1 AND rapportPending = 0',
      whereArgs: [tourneeId],
    );
    safePrint(
        '>>>> LocalColisStatusStore: cleared $deleted synced statuses and $deletedUploads synced uploads for tournee $tourneeId');
  }

  /// Safety sweep: drop dead-letter rows (and their files) older than [age].
  /// Keeps the store and the pending-uploads folder from growing forever.
  Future<void> purgeDeadLettersOlderThan(Duration age) async {
    final db = await _database;
    final cutoffIso = DateTime.now().toUtc().subtract(age).toIso8601String();
    final uploadRows = await db.query(
      _uploadsTable,
      columns: ['filePath'],
      where: 'deadLetter = 1 AND createdAt < ?',
      whereArgs: [cutoffIso],
    );
    for (final row in uploadRows) {
      await _deleteFileQuietly(row['filePath'] as String?);
    }
    final purgedUploads = await db.delete(
      _uploadsTable,
      where: 'deadLetter = 1 AND createdAt < ?',
      whereArgs: [cutoffIso],
    );
    final purgedStatuses = await db.delete(
      _table,
      where: 'deadLetter = 1 AND createdAt < ?',
      whereArgs: [cutoffIso],
    );
    if (purgedStatuses > 0 || purgedUploads > 0) {
      safePrint(
          '>>>> LocalColisStatusStore: purged $purgedStatuses dead-letter statuses and $purgedUploads dead-letter uploads older than $age');
    }
  }

  Future<void> _deleteFileQuietly(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      safePrint('>>>> LocalColisStatusStore: could not delete file $path: $e');
    }
  }
}
