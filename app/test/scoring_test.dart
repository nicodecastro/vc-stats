import 'package:flutter_test/flutter_test.dart';
import 'package:vc_sets/domain/models.dart';
import 'package:vc_sets/domain/scoring.dart';

import 'test_fixtures.dart';

void main() {
  const engine = ScoringEngine();
  const rules = MatchRules();

  test('set requires target and two-point margin', () {
    expect(engine.isSetComplete(25, 24, 1, rules), isFalse);
    expect(engine.isSetComplete(26, 24, 1, rules), isTrue);
    expect(engine.isSetComplete(14, 16, 5, rules), isTrue);
  });

  test('sideout rotates receiving team and winner serves', () {
    final game = testGame();
    final empty = testLog();
    final first = engine.nextRally(
      id: 'r1',
      game: game,
      log: empty,
      rules: rules,
      winnerTeamId: awayTeam.id,
      recordedAt: DateTime.utc(2026, 10, 2),
    );
    expect(first.awayRotation, 2);
    expect(first.servingTeamId, awayTeam.id);

    final second = engine.nextRally(
      id: 'r2',
      game: game,
      log: empty.copyWith(rallies: [first]),
      rules: rules,
      winnerTeamId: awayTeam.id,
      recordedAt: DateTime.utc(2026, 10, 2),
    );
    expect(
      second.awayRotation,
      2,
      reason: 'Serving team does not rotate after holding serve',
    );
  });

  test('three completed sets complete a match and preserve set count', () {
    final game = testGame();
    var log = testLog();
    var id = 0;
    for (var set = 0; set < 3; set++) {
      for (var point = 0; point < 25; point++) {
        final rally = engine.nextRally(
          id: 'r${id++}',
          game: game,
          log: log,
          rules: rules,
          winnerTeamId: homeTeam.id,
          recordedAt: DateTime.utc(2026, 10, 2),
        );
        log = log.copyWith(rallies: [...log.rallies, rally]);
      }
    }
    final score = engine.score(game, log, rules);
    expect(score.homeSets, 3);
    expect(score.awaySets, 0);
    expect(score.isComplete, isTrue);
    expect(
      () => engine.nextRally(
        id: 'extra',
        game: game,
        log: log,
        rules: rules,
        winnerTeamId: homeTeam.id,
        recordedAt: DateTime.now(),
      ),
      throwsStateError,
    );
  });

  test('starting lineup validation catches count and duplicates', () {
    expect(
      engine.validateStartingLineup(
        homeTeam,
        homeTeam.players.map((p) => p.id).toList(),
      ),
      isEmpty,
    );
    expect(
      engine.validateStartingLineup(homeTeam, ['home-0', 'home-0']),
      hasLength(greaterThanOrEqualTo(2)),
    );
  });

  test('skill actions use the requested compact rally notation', () {
    final now = DateTime.utc(2026, 10, 2);
    String notation(Skill skill, ActionGrade grade, {bool player = true}) =>
        TeamAction(
          id: '${skill.name}-${grade.name}',
          teamId: homeTeam.id,
          playerId: player ? homeTeam.players.first.id : null,
          skill: skill,
          grade: grade,
          recordedAt: now,
        ).notation(homeTeam);

    expect(notation(Skill.serve, ActionGrade.attempt), 'V1');
    expect(notation(Skill.serve, ActionGrade.success), 'V1+');
    expect(notation(Skill.serve, ActionGrade.error), 'V1-');
    expect(notation(Skill.attack, ActionGrade.attempt), 'A1');
    expect(notation(Skill.block, ActionGrade.error), 'B1-');
    expect(notation(Skill.set, ActionGrade.success), 'S1+');
    expect(notation(Skill.reception, ActionGrade.attempt), 'R1');
    expect(notation(Skill.dig, ActionGrade.success), 'D1+');
    expect(
      notation(Skill.opponentError, ActionGrade.success, player: false),
      'OP+',
    );
    expect(notation(Skill.teamFault, ActionGrade.error, player: false), 'T-');
  });
}
