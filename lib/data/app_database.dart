import 'dart:math' as math;

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/memory_item.dart';
import '../models/notification.dart';

class AppDatabase {
  AppDatabase._(this._database);

  final Database _database;

  static Future<AppDatabase> open() async {
    final path = join(await getDatabasesPath(), 'nottler.db');
    final database = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE notification_logs ADD COLUMN embedding TEXT');
          await db.execute(
              'ALTER TABLE notification_logs ADD COLUMN ai_model_version TEXT NOT NULL DEFAULT "unknown"');
          await db.execute(
              'ALTER TABLE notification_logs ADD COLUMN ai_processing_error TEXT');
        }
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE notification_logs ADD COLUMN content_fingerprint TEXT');
        }
        if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE memory_items ADD COLUMN source_package TEXT');
          await db.execute(
              'ALTER TABLE memory_items ADD COLUMN content_fingerprint TEXT');
        }
        await _createIndexes(db);
      },
    );
    return AppDatabase._(database);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE memory_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        importance INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        date TEXT,
        time TEXT,
        location TEXT,
        responsible_party TEXT,
        source_app TEXT,
        source_package TEXT,
        source_text TEXT,
        content_fingerprint TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE notification_logs (
        id TEXT PRIMARY KEY,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        title TEXT NOT NULL,
        text TEXT NOT NULL,
        sub_text TEXT,
        sender_name TEXT,
        timestamp INTEGER NOT NULL,
        processed INTEGER NOT NULL DEFAULT 0,
        action_taken TEXT NOT NULL,
        category TEXT NOT NULL,
        category_confidence REAL NOT NULL,
        importance INTEGER NOT NULL,
        embedding TEXT,
        ai_processed INTEGER NOT NULL DEFAULT 0,
        ai_model_version TEXT NOT NULL DEFAULT 'unknown',
        summary TEXT,
        ai_processing_error TEXT,
        memory_item_id TEXT,
        content_fingerprint TEXT
      )
    ''');
    await _createIndexes(db);
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS notification_timestamp ON notification_logs(timestamp DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS memory_status_date ON memory_items(status, date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS notification_fingerprint_timestamp ON notification_logs(content_fingerprint, timestamp DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS memory_fingerprint_status ON memory_items(content_fingerprint, status)');
  }

  Future<List<MemoryItem>> getItems() async {
    final rows = await _database.query('memory_items',
        orderBy: 'date IS NULL, date ASC, importance DESC, created_at DESC');
    return rows.map(MemoryItem.fromMap).toList();
  }

  Future<void> upsertItem(MemoryItem item) async {
    await _database.insert('memory_items', item.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateItemStatus(String id, String status) async {
    await _database.update(
      'memory_items',
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItem(String id) =>
      _database.delete('memory_items', where: 'id = ?', whereArgs: [id]);

  Future<void> updateItemSchedule(
    String id, {
    required String status,
    required String date,
    required String time,
  }) =>
      _database.update(
        'memory_items',
        {
          'status': status,
          'date': date,
          'time': time,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> updateItemCategory(String id, String category) async {
    await _database.transaction((transaction) async {
      await transaction.update(
        'memory_items',
        {'category': category, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await transaction.update(
        'notification_logs',
        {'category': category.toLowerCase()},
        where: 'memory_item_id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<bool> hasRecentNotification(
    String fingerprint, {
    required int since,
  }) async {
    final result = await _database.query(
      'notification_logs',
      columns: const ['id'],
      where: 'content_fingerprint = ? AND timestamp >= ?',
      whereArgs: [fingerprint, since],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<MemoryItem?> findOpenItemByFingerprint(String fingerprint) async {
    final result = await _database.query(
      'memory_items',
      where: 'content_fingerprint = ? AND status IN (?, ?)',
      whereArgs: [fingerprint, 'active', 'snoozed'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return result.isEmpty ? null : MemoryItem.fromMap(result.first);
  }

  Future<void> touchItem(String id, int importance) => _database.update(
        'memory_items',
        {
          'importance': importance,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> clearAllData() async {
    await _database.transaction((transaction) async {
      await transaction.delete('memory_items');
      await transaction.delete('notification_logs');
    });
  }

  Future<void> clearDataForApp({
    required String packageName,
    required String appName,
  }) async {
    await _database.transaction((transaction) async {
      await transaction.delete('notification_logs',
          where: 'package_name = ?', whereArgs: [packageName]);
      await transaction.delete('memory_items',
          where:
              'source_package = ? OR (source_package IS NULL AND source_app = ?)',
          whereArgs: [packageName, appName]);
    });
  }

  Future<List<MemoryItem>> searchItems(String query) async {
    final pattern = '%${query.trim()}%';
    final rows = await _database.query(
      'memory_items',
      where:
          'title LIKE ? OR description LIKE ? OR category LIKE ? OR source_text LIKE ?',
      whereArgs: [pattern, pattern, pattern, pattern],
      orderBy: 'updated_at DESC',
    );
    return rows.map(MemoryItem.fromMap).toList();
  }

  Future<void> upsertNotification(NotificationRecord record) async {
    await _database.insert('notification_logs', record.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<NotificationRecord>> getLogs() async {
    final rows =
        await _database.query('notification_logs', orderBy: 'timestamp DESC');
    return rows.map(NotificationRecord.fromMap).toList();
  }

  Future<List<NotificationRecord>> semanticSearch(List<double> queryVector,
      {int limit = 30}) async {
    final records = await getLogs();
    final scored = <({NotificationRecord record, double score})>[];
    for (final record in records) {
      final vector = record.embedding;
      if (vector == null || vector.isEmpty) continue;
      final length = math.min(vector.length, queryVector.length);
      var dot = 0.0;
      var left = 0.0;
      var right = 0.0;
      for (var i = 0; i < length; i++) {
        dot += vector[i] * queryVector[i];
        left += vector[i] * vector[i];
        right += queryVector[i] * queryVector[i];
      }
      final score = left == 0 || right == 0
          ? 0.0
          : dot / (math.sqrt(left) * math.sqrt(right));
      scored.add((record: record, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((entry) => entry.record).toList();
  }

  Future<void> close() => _database.close();
}
