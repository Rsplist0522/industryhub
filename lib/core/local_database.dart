import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static Database? _database;

  static const String _databaseName = 'industryhub.db';
  static const int _databaseVersion = 3;

  static const String _notesTable = 'notes';
  static const String _preferencesTable = 'preferences';

  // ============================================================
  // DATABASE
  // ============================================================

  static Future<Database> get database async {
    final existingDatabase = _database;

    if (existingDatabase != null) {
      return existingDatabase;
    }

    final databasePath = join(
      await getDatabasesPath(),
      _databaseName,
    );

    final database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (database, version) async {
        await _createTables(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        await _upgradeDatabase(
          database,
          oldVersion,
          newVersion,
        );
      },
    );

    _database = database;
    return database;
  }

  // ============================================================
  // TABLE CREATION
  // ============================================================

  static Future<void> _createTables(Database database) async {
    await database.execute('''
      CREATE TABLE $_notesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE $_preferencesTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS idx_notes_created_at
      ON $_notesTable(created_at)
    ''');
  }

  // ============================================================
  // DATABASE MIGRATION
  // ============================================================

  static Future<void> _upgradeDatabase(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 3) {
      await database.execute('''
        CREATE TABLE IF NOT EXISTS $_preferencesTable (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await database.execute('''
        CREATE INDEX IF NOT EXISTS idx_notes_created_at
        ON $_notesTable(created_at)
      ''');

      await _migrateLegacyPreferences(database);
    }
  }

  /// Moves preferences previously stored as:
  ///
  /// preference:key=value
  ///
  /// from the notes table into the new preferences table.
  static Future<void> _migrateLegacyPreferences(
    Database database,
  ) async {
    final legacyRows = await database.query(
      _notesTable,
      columns: [
        'id',
        'text',
        'created_at',
      ],
      where: 'text LIKE ?',
      whereArgs: ['preference:%=%'],
    );

    for (final row in legacyRows) {
      final rawText = row['text'];

      if (rawText is! String) {
        continue;
      }

      const prefix = 'preference:';

      if (!rawText.startsWith(prefix)) {
        continue;
      }

      final preferenceText = rawText.substring(prefix.length);

      final separatorIndex = preferenceText.indexOf('=');

      if (separatorIndex <= 0) {
        continue;
      }

      final key = preferenceText.substring(
        0,
        separatorIndex,
      );

      final value = preferenceText.substring(
        separatorIndex + 1,
      );

      final createdAt =
          row['created_at'] as String? ??
          DateTime.now().toIso8601String();

      await database.insert(
        _preferencesTable,
        {
          'key': key,
          'value': value,
          'updated_at': createdAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await database.delete(
      _notesTable,
      where: 'text LIKE ?',
      whereArgs: ['preference:%=%'],
    );
  }

  // ============================================================
  // NOTES
  // ============================================================

  static Future<int> addNote(String text) async {
    final database = await LocalDatabase.database;

    final cleanedText = text.trim();

    if (cleanedText.isEmpty) {
      throw ArgumentError(
        'Note text cannot be empty.',
      );
    }

    return database.insert(
      _notesTable,
      {
        'text': cleanedText,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  static Future<List<Map<String, Object?>>> getNotes() async {
    final database = await LocalDatabase.database;

    return database.query(
      _notesTable,
      orderBy: 'created_at DESC',
    );
  }

  static Future<Map<String, Object?>?> getNoteById(
    int id,
  ) async {
    final database = await LocalDatabase.database;

    final rows = await database.query(
      _notesTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first;
  }

  static Future<int> updateNote(
    int id,
    String text,
  ) async {
    final database = await LocalDatabase.database;

    final cleanedText = text.trim();

    if (cleanedText.isEmpty) {
      throw ArgumentError(
        'Note text cannot be empty.',
      );
    }

    return database.update(
      _notesTable,
      {
        'text': cleanedText,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> deleteNote(int id) async {
    final database = await LocalDatabase.database;

    return database.delete(
      _notesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> clearNotes() async {
    final database = await LocalDatabase.database;

    return database.delete(_notesTable);
  }

  static Future<int> getNoteCount() async {
    final database = await LocalDatabase.database;

    final result = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM $_notesTable',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ============================================================
  // PREFERENCES
  // ============================================================

  static Future<void> savePreference(
    String key,
    String value,
  ) async {
    final database = await LocalDatabase.database;

    final cleanedKey = key.trim();

    if (cleanedKey.isEmpty) {
      throw ArgumentError(
        'Preference key cannot be empty.',
      );
    }

    await database.insert(
      _preferencesTable,
      {
        'key': cleanedKey,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getPreference(
    String key,
  ) async {
    final database = await LocalDatabase.database;

    final rows = await database.query(
      _preferencesTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['value'] as String?;
  }

  static Future<Map<String, String>> getAllPreferences() async {
    final database = await LocalDatabase.database;

    final rows = await database.query(
      _preferencesTable,
      orderBy: 'key ASC',
    );

    final preferences = <String, String>{};

    for (final row in rows) {
      final key = row['key'];
      final value = row['value'];

      if (key is String && value is String) {
        preferences[key] = value;
      }
    }

    return preferences;
  }

  static Future<int> deletePreference(
    String key,
  ) async {
    final database = await LocalDatabase.database;

    return database.delete(
      _preferencesTable,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  static Future<int> clearPreferences() async {
    final database = await LocalDatabase.database;

    return database.delete(_preferencesTable);
  }

  // ============================================================
  // CONNECTION
  // ============================================================

  static Future<void> close() async {
    final database = _database;

    if (database != null) {
      await database.close();
    }

    _database = null;
  }
}