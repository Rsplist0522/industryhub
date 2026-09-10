import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static Database? _database;

  static Future<Database> get database async {
    final existingDatabase = _database;
    if (existingDatabase != null) {
      return existingDatabase;
    }

    final databasePath = join(
      await getDatabasesPath(),
      'industryhub.db',
    );

    final database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            text TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );

    _database = database;
    return database;
  }

  static Future<int> addNote(String text) async {
    final database = await LocalDatabase.database;
    return database.insert('notes', {
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, Object?>>> getNotes() async {
    final database = await LocalDatabase.database;
    return database.query('notes', orderBy: 'created_at DESC');
  }

  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}