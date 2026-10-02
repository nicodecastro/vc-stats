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
}
