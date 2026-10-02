import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vc_sets/domain/models.dart';
import 'package:vc_sets/domain/packages.dart';

import 'test_fixtures.dart';

void main() {
  const service = PortablePackageService();

  test('game package round trips with integrity metadata', () {
    final game = testGame(logs: [testLog()]);
    final tournament = testTournament(games: [game]);
    final package = service.createGamePackage(
      packageId: 'package-1',
      deviceId: 'device-a',
      exportedAt: DateTime.utc(2026, 10, 2),
      tournament: tournament,
      game: game,
      log: game.logs.single,
    );
    final decoded = service.decodeGamePackage(package.encode());
    expect(decoded.manifest.packageId, 'package-1');
    expect(decoded.log?.id, 'log-a');
    expect(decoded.tournament.teams, hasLength(2));
  });

  test('tampered payload is rejected', () {
    final data = AppData(deviceId: 'device-a', tournaments: [testTournament()]);
    final source = service.createBackup(
      packageId: 'backup',
      data: data,
      exportedAt: DateTime.utc(2026, 10, 2),
    );
    final root = jsonDecode(source) as Map<String, dynamic>;
    root['payload']['deviceId'] = 'tampered';
    expect(() => service.decodeBackup(jsonEncode(root)), throwsFormatException);
  });

  test('full backup round trips tournament data', () {
    final data = AppData(
      deviceId: 'device-a',
      tournaments: [testTournament()],
      importedPackageIds: const ['one'],
    );
    final source = service.createBackup(
      packageId: 'backup',
      data: data,
      exportedAt: DateTime.utc(2026, 10, 2),
    );
    final restored = service.decodeBackup(source);
    expect(restored.tournaments.single.name, 'Club Cup');
    expect(restored.importedPackageIds, ['one']);
  });
}
