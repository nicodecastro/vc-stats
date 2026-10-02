import 'package:flutter_test/flutter_test.dart';
import 'package:vc_sets/domain/models.dart';
import 'package:vc_sets/domain/scoring.dart';
import 'package:vc_sets/domain/statistics.dart';

import 'test_fixtures.dart';

void main() {
  test('finalized match drives standings and player totals', () {
    const engine = ScoringEngine();
    var log = testLog();
    final game = testGame();
    var id = 0;
    for (var set = 0; set < 3; set++) {
      for (var point = 0; point < 25; point++) {
        final actions = id == 0
            ? [
                TeamAction(
                  id: 'action',
                  teamId: homeTeam.id,
                  playerId: homeTeam.players.first.id,
                  skill: Skill.attack,
                  grade: ActionGrade.success,
                  recordedAt: DateTime.utc(2026, 10, 2),
                ),
              ]
            : const <TeamAction>[];
        final rally = engine.nextRally(
          id: 'r${id++}',
          game: game,
          log: log,
          rules: const MatchRules(),
          winnerTeamId: homeTeam.id,
          recordedAt: DateTime.utc(2026, 10, 2),
          actions: actions,
        );
        log = log.copyWith(rallies: [...log.rallies, rally]);
      }
    }
    final finalized = testGame(officialLog: log);
    final tournament = testTournament(games: [finalized]);
    final standings = const StatisticsService().standings(tournament);
    expect(standings.first.team.id, homeTeam.id);
    expect(standings.first.matchPoints, 3);
    expect(standings.first.setsWon, 3);
    expect(standings.first.pointsWon, 75);
    final players = const StatisticsService().playerSummaries(tournament);
    expect(players.single.bySkill[Skill.attack]?.successes, 1);
  });

  test('bracket games do not change round-robin standings', () {
    ScorerLog sweep(String id, String winner) => ScorerLog(
      id: 'log-$id',
      gameId: id,
      assignedTeamId: 'official',
      deviceId: 'device',
      createdAt: DateTime.utc(2026, 10, 2),
      updatedAt: DateTime.utc(2026, 10, 2),
      initialServingTeamId: homeTeam.id,
      rallies: [
        for (var set = 1; set <= 3; set++)
          Rally(
            id: '$id-$set',
            setNumber: set,
            sequence: 1,
            winnerTeamId: winner,
            homeScore: winner == homeTeam.id ? 25 : 0,
            awayScore: winner == awayTeam.id ? 25 : 0,
            homeRotation: 1,
            awayRotation: 1,
            servingTeamId: winner,
            recordedAt: DateTime.utc(2026, 10, 2),
          ),
      ],
    );

    final poolLog = sweep('pool', homeTeam.id);
    final bracketLog = sweep('final', awayTeam.id);
    final pool = Game(
      id: 'pool',
      tournamentId: 'tournament',
      homeTeamId: homeTeam.id,
      awayTeamId: awayTeam.id,
      scheduledAt: DateTime.utc(2026, 10, 2),
      venue: 'Gym',
      status: GameStatus.finalized,
      officialLog: poolLog,
    );
    final finalGame = Game(
      id: 'final',
      tournamentId: 'tournament',
      homeTeamId: homeTeam.id,
      awayTeamId: awayTeam.id,
      scheduledAt: DateTime.utc(2026, 10, 3),
      venue: 'Gym',
      stage: GameStage.bracket,
      bracketRound: 1,
      bracketOrder: 0,
      status: GameStatus.finalized,
      officialLog: bracketLog,
    );
    final standings = const StatisticsService().standings(
      testTournament(games: [pool, finalGame]),
    );
    expect(standings.first.team.id, homeTeam.id);
    expect(standings.first.wins, 1);
    expect(standings.last.wins, 0);
  });
}
