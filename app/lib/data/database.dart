import 'package:drift/drift.dart';

import 'connection/connection.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);

  static Future<AppDatabase> open() async =>
      AppDatabase(await openConnection());

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''
        CREATE TABLE app_state (
          key TEXT NOT NULL PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<String?> readState() async {
    final row = await customSelect(
      'SELECT value FROM app_state WHERE key = ?',
      variables: [Variable.withString('current')],
    ).getSingleOrNull();
    return row?.read<String>('value');
  }

  Future<void> writeState(String value) async {
    await transaction(() async {
      await customStatement(
        '''INSERT INTO app_state (key, value, updated_at) VALUES (?, ?, ?)
           ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at''',
        ['current', value, DateTime.now().toUtc().toIso8601String()],
      );
    });
  }
}
