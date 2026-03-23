import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class ConsumerLocalCacheDatabase {
  ConsumerLocalCacheDatabase({this.databaseName = 'res_consumer_cache.db'});

  final String databaseName;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    final opened = await _openDatabase();
    _database = opened;
    return opened;
  }

  Future<String?> readPayload(String cacheKey) async {
    final db = await database;
    final rows = await db.query(
      'cache_entries',
      columns: const ['payload'],
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['payload']?.toString();
  }

  Future<void> writePayload(String cacheKey, String payload) async {
    final db = await database;
    await db.insert('cache_entries', {
      'cache_key': cacheKey,
      'payload': payload,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePayload(String cacheKey) async {
    final db = await database;
    await db.delete(
      'cache_entries',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
    );
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('cache_entries');
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, databaseName);
    return openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache_entries (
            cache_key TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }
}
