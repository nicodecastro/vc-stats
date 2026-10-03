import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vc_sets/application/providers.dart';
import 'package:vc_sets/data/repository.dart';
import 'package:vc_sets/domain/models.dart';
import 'package:vc_sets/presentation/app.dart';
import 'package:vc_sets/presentation/pages/games_page.dart';
import 'package:vc_sets/presentation/pages/reports_page.dart';
import 'package:vc_sets/presentation/pages/tournament_detail_page.dart';
import 'package:vc_sets/presentation/pages/tracker_page.dart';

import 'test_fixtures.dart';

void main() {
  testWidgets('dashboard renders at phone and desktop widths', (tester) async {
    const data = AppData(deviceId: 'test-device');
    final repository = MemoryAppRepository(data);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRepositoryProvider.overrideWithValue(repository),
          initialAppDataProvider.overrideWithValue(data),
        ],
        child: VcSetsApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Match day, under control'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('tracker renders R-5 court player buttons and team controls', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 2);
    final log = ScorerLog(
      id: 'log',
      gameId: 'game',
      assignedTeamId: homeTeam.id,
      deviceId: 'test-device',
      createdAt: now,
      updatedAt: now,
      initialServingTeamId: homeTeam.id,
      lineups: [
        LineupSnapshot(
          teamId: homeTeam.id,
          playerIds: homeTeam.players
              .take(6)
              .map((player) => player.id)
              .toList(),
          recordedAt: now,
        ),
      ],
    );
    final game = Game(
      id: 'game',
      tournamentId: 'tournament',
      homeTeamId: homeTeam.id,
      awayTeamId: awayTeam.id,
      scheduledAt: now,
      venue: 'Gym',
      status: GameStatus.inProgress,
      logs: [log],
    );
    final tournament = Tournament(
      id: 'tournament',
      name: 'League',
      venue: 'Gym',
      startsOn: now,
      endsOn: now,
      createdAt: now,
      teams: [homeTeam, awayTeam],
      games: [game],
    );
    final data = AppData(deviceId: 'test-device', tournaments: [tournament]);
    final repository = MemoryAppRepository(data);
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRepositoryProvider.overrideWithValue(repository),
          initialAppDataProvider.overrideWithValue(data),
        ],
        child: const MaterialApp(
          home: TrackerPage(tournamentId: 'tournament', gameId: 'game'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NET • FRONT ROW'), findsOneWidget);
    expect(find.text('R-5 lineup • Set 1'), findsOneWidget);
    expect(find.text('Substitution (0)'), findsOneWidget);
    expect(find.text('Timeout (0/2)'), findsOneWidget);
    expect(find.text('Libero'), findsOneWidget);
    expect(find.text('Quick swap'), findsOneWidget);
    expect(find.text('#1'), findsWidgets);
    expect(find.text('ATT'), findsNWidgets(6));
    expect(find.text('EXC'), findsNWidgets(6));
    expect(find.text('ERR'), findsNWidgets(6));
    expect(find.text('OPP ERR  •  OP+'), findsOneWidget);
    expect(find.text('TEAM FAULT  •  T-'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpAndSettle();
    final scoreboard = tester.getTopLeft(find.text('SET 1'));
    final timeline = tester.getTopLeft(find.text('Event timeline'));
    final playerActions = tester.getTopLeft(find.text('Player actions'));
    expect(scoreboard.dy, lessThan(timeline.dy));
    expect(playerActions.dy, lessThan(160));

    await tester.tap(find.text('ATT').first);
    await tester.pump();
    expect(find.text('V1'), findsOneWidget);

    await tester.tap(find.text('EXC').first);
    await tester.pump();
    expect(find.text('V1'), findsNothing);
    expect(find.text('V1+'), findsOneWidget);

    await tester.tap(find.text('EXC').first);
    await tester.pump();
    expect(find.text('V1+'), findsNWidgets(2));

    await tester.ensureVisible(find.text('OPP ERR  •  OP+'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPP ERR  •  OP+'));
    await tester.ensureVisible(find.text('TEAM FAULT  •  T-'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TEAM FAULT  •  T-'));
    await tester.pump();
    expect(find.text('V1+'), findsNWidgets(2));
    expect(find.text('OP+'), findsOneWidget);
    expect(find.text('T-'), findsOneWidget);
  });

  testWidgets('reports render the ordered player stats summary matrix', (
    tester,
  ) async {
    final data = AppData(
      deviceId: 'test-device',
      tournaments: [testTournament()],
    );
    final repository = MemoryAppRepository(data);
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRepositoryProvider.overrideWithValue(repository),
          initialAppDataProvider.overrideWithValue(data),
        ],
        child: const MaterialApp(home: Scaffold(body: ReportsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Player stats summary'), findsOneWidget);
    expect(find.text('Team'), findsWidgets);
    expect(find.text('Last name'), findsOneWidget);
    expect(find.text('S+'), findsOneWidget);
    expect(find.text('V-'), findsOneWidget);
    expect(find.text('OP+'), findsOneWidget);
    expect(find.text('T-'), findsOneWidget);
  });

  testWidgets('games tab offers game package export', (tester) async {
    final game = testGame(logs: [testLog(deviceId: 'test-device')]);
    final data = AppData(
      deviceId: 'test-device',
      tournaments: [
        testTournament(games: [game]),
      ],
    );
    final repository = MemoryAppRepository(data);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRepositoryProvider.overrideWithValue(repository),
          initialAppDataProvider.overrideWithValue(data),
        ],
        child: const MaterialApp(home: Scaffold(body: GamesPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Game actions'));
    await tester.pumpAndSettle();

    expect(find.text('Export scorer log'), findsOneWidget);
    expect(find.text('Delete game'), findsOneWidget);
  });

  testWidgets('tournament deletion requires destructive confirmation', (
    tester,
  ) async {
    final tournament = testTournament(games: [testGame()]);
    final data = AppData(deviceId: 'test-device', tournaments: [tournament]);
    final repository = MemoryAppRepository(data);
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRepositoryProvider.overrideWithValue(repository),
          initialAppDataProvider.overrideWithValue(data),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TournamentDetailPage(tournamentId: tournament.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit tournament'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Best of 5'));
    await tester.pumpAndSettle();
    expect(find.text('One set'), findsOneWidget);
    await tester.tap(find.text('One set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete tournament'));
    await tester.pumpAndSettle();

    expect(find.text('Delete tournament?'), findsOneWidget);
    expect(find.textContaining('2 teams and 1 game'), findsOneWidget);
    expect(find.textContaining('This cannot be undone.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete tournament?'), findsNothing);
    expect((await repository.load()).tournaments, hasLength(1));
  });
}
