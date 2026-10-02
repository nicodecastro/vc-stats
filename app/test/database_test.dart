import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vc_sets/data/database.dart';
import 'package:vc_sets/data/repository.dart';
import 'package:vc_sets/domain/models.dart';

import 'test_fixtures.dart';

void main() {
  test('SQLite repository persists and reloads versioned app state', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAppRepository(database);
    final data = AppData(
      deviceId: 'device-a',
      tournaments: [testTournament()],
      importedPackageIds: const ['package-a'],
    );
    await repository.save(data);
    final loaded = await repository.load();
    expect(loaded.deviceId, 'device-a');
    expect(loaded.tournaments.single.name, 'Club Cup');
    expect(loaded.importedPackageIds, ['package-a']);
  });
}
