import 'models.dart';
import 'scoring.dart';

class SkillSummary {
  const SkillSummary({
    required this.attempts,
    required this.successes,
    required this.errors,
    required this.positive,
  });

  final int attempts;
  final int successes;
  final int errors;
  final int positive;

  double get successRate => attempts == 0 ? 0 : successes / attempts;
}

class PlayerSummary {
  PlayerSummary(this.player, this.bySkill);
  final Player player;
  final Map<Skill, SkillSummary> bySkill;

  int get totalSuccesses =>
      bySkill.values.fold(0, (total, item) => total + item.successes);
}

class StandingRow {
  const StandingRow({
    required this.team,
    required this.played,
    required this.wins,
    required this.losses,
    required this.matchPoints,
    required this.setsWon,
    required this.setsLost,
    required this.pointsWon,
    required this.pointsLost,
  });

  final TournamentTeam team;
  final int played;
  final int wins;
  final int losses;
  final int matchPoints;
  final int setsWon;
  final int setsLost;
  final int pointsWon;
  final int pointsLost;

  double get setRatio =>
      setsLost == 0 ? setsWon.toDouble() : setsWon / setsLost;
  double get pointRatio =>
      pointsLost == 0 ? pointsWon.toDouble() : pointsWon / pointsLost;
}

class StatisticsService {
  const StatisticsService();

  List<PlayerSummary> playerSummaries(Tournament tournament) {
    final actions = tournament.games
        .where(
          (game) =>
              game.status == GameStatus.finalized && game.officialLog != null,
        )
        .expand((game) => game.officialLog!.rallies)
        .expand((rally) => rally.actions);
    final byPlayer = <String, List<TeamAction>>{};
    for (final action in actions) {
      if (action.playerId != null) {
        byPlayer.putIfAbsent(action.playerId!, () => []).add(action);
      }
    }
    final players = tournament.teams.expand((team) => team.players);
    return players
        .map((player) {
          final playerActions = byPlayer[player.id] ?? const <TeamAction>[];
          final skills = <Skill, SkillSummary>{};
          for (final skill in Skill.values.where(
            (item) => item != Skill.timeout && item != Skill.substitution,
          )) {
            final relevant = playerActions
                .where((action) => action.skill == skill)
                .toList();
            skills[skill] = SkillSummary(
              attempts: relevant.length,
              successes: relevant
                  .where((action) => action.grade == ActionGrade.success)
                  .length,
              errors: relevant
                  .where((action) => action.grade == ActionGrade.error)
                  .length,
              positive: relevant
                  .where((action) => action.grade == ActionGrade.positive)
                  .length,
            );
          }
          return PlayerSummary(player, skills);
        })
        .where(
          (summary) =>
              summary.bySkill.values.any((skill) => skill.attempts > 0),
        )
        .toList()
      ..sort((a, b) => b.totalSuccesses.compareTo(a.totalSuccesses));
  }

  List<StandingRow> standings(Tournament tournament) {
    final mutable = <String, _MutableStanding>{
      for (final team in tournament.teams) team.id: _MutableStanding(team),
    };
    for (final game in tournament.games.where(
      (game) => game.status == GameStatus.finalized && game.officialLog != null,
    )) {
      final home = mutable[game.homeTeamId]!;
      final away = mutable[game.awayTeamId]!;
      final sets = _setResults(game.officialLog!, tournament.rules);
      home.played++;
      away.played++;
      home.setsWon += sets.homeSets;
      home.setsLost += sets.awaySets;
      away.setsWon += sets.awaySets;
      away.setsLost += sets.homeSets;
      for (final rally in game.officialLog!.rallies) {
        if (rally.winnerTeamId == game.homeTeamId) {
          home.pointsWon++;
          away.pointsLost++;
        } else {
          away.pointsWon++;
          home.pointsLost++;
        }
      }
      final homeWon = sets.homeSets > sets.awaySets;
      (homeWon ? home : away).wins++;
      (homeWon ? away : home).losses++;
      final deciding =
          sets.homeSets == tournament.rules.setsToWin &&
              sets.awaySets == tournament.rules.setsToWin - 1 ||
          sets.awaySets == tournament.rules.setsToWin &&
              sets.homeSets == tournament.rules.setsToWin - 1;
      final policy = tournament.rules.standings;
      if (deciding) {
        (homeWon ? home : away).matchPoints += policy.decidingWinPoints;
        (homeWon ? away : home).matchPoints += policy.decidingLossPoints;
      } else {
        (homeWon ? home : away).matchPoints += policy.clearWinPoints;
        (homeWon ? away : home).matchPoints += policy.clearLossPoints;
      }
    }
    final rows = mutable.values.map((item) => item.freeze()).toList();
    rows.sort((a, b) {
      for (final rule in tournament.rules.standings.tieBreakers) {
        final comparison = switch (rule) {
          'wins' => b.wins.compareTo(a.wins),
          'setRatio' => b.setRatio.compareTo(a.setRatio),
          'pointRatio' => b.pointRatio.compareTo(a.pointRatio),
          _ => b.matchPoints.compareTo(a.matchPoints),
        };
        if (comparison != 0) return comparison;
      }
      return a.team.name.compareTo(b.team.name);
    });
    return rows;
  }

  ({int homeSets, int awaySets}) _setResults(ScorerLog log, MatchRules rules) {
    var homeSets = 0;
    var awaySets = 0;
    for (final set in <int>{...log.rallies.map((rally) => rally.setNumber)}) {
      final last = log.rallies.where((rally) => rally.setNumber == set).last;
      if (const ScoringEngine().isSetComplete(
        last.homeScore,
        last.awayScore,
        set,
        rules,
      )) {
        last.homeScore > last.awayScore ? homeSets++ : awaySets++;
      }
    }
    return (homeSets: homeSets, awaySets: awaySets);
  }
}

class _MutableStanding {
  _MutableStanding(this.team);
  final TournamentTeam team;
  int played = 0;
  int wins = 0;
  int losses = 0;
  int matchPoints = 0;
  int setsWon = 0;
  int setsLost = 0;
  int pointsWon = 0;
  int pointsLost = 0;

  StandingRow freeze() => StandingRow(
    team: team,
    played: played,
    wins: wins,
    losses: losses,
    matchPoints: matchPoints,
    setsWon: setsWon,
    setsLost: setsLost,
    pointsWon: pointsWon,
    pointsLost: pointsLost,
  );
}
