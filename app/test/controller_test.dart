import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vc_sets/application/providers.dart';
import 'package:vc_sets/data/repository.dart';
import 'package:vc_sets/domain/models.dart';

void main() {
  test(
    'controller persists tournament, roster, and generated fixtures',
    () async {
      final initial = const AppData(deviceId: 'device');
      final repository = MemoryAppRepository(initial);
      final container = ProviderContainer(
        overrides: [
          appRepositoryProvider.overrideWithValue(repository),
          initialAppDataProvider.overrideWithValue(initial),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(appControllerProvider.notifier);
      final tournamentId = await controller.createTournament(
        name: 'League',
        venue: 'Gym',
        startsOn: DateTime.utc(2026, 10, 2),
        endsOn: DateTime.utc(2026, 10, 2),
      );
      await controller.addTeam(tournamentId, 'Alpha', 'ALP', 0xFF000000);
      await controller.addTeam(tournamentId, 'Beta', 'BET', 0xFFFFFFFF);
      final team = container
          .read(appControllerProvider)
          .tournaments
          .single
          .teams
          .first;
      await controller.addPlayer(
        tournamentId,
        team.id,
        number: 1,
        name: 'Setter',
        position: PlayerPosition.S,
      );
      await controller.generateRoundRobin(tournamentId);

      final persisted = await repository.load();
      expect(
        persisted.tournaments.single.teams.first.players.single.name,
        'Setter',
      );
      expect(persisted.tournaments.single.games, hasLength(1));
    },
  );
}
