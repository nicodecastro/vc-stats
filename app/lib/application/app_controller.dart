import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/packages.dart';
import '../domain/reconciliation.dart';
import '../domain/scoring.dart';
import 'providers.dart';

class AppController extends Notifier<AppData> {
  final _uuid = const Uuid();

  @override
  AppData build() => ref.watch(initialAppDataProvider);

  Future<void> _commit(AppData next) async {
    state = next;
    await ref.read(appRepositoryProvider).save(next);
  }

  Future<String> createTournament({
    required String name,
    required String venue,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    final tournament = Tournament(
      id: _uuid.v4(),
      name: name.trim(),
      venue: venue.trim(),
      startsOn: startsOn,
      endsOn: endsOn,
      createdAt: DateTime.now(),
    );
    await _commit(
      state.copyWith(tournaments: [...state.tournaments, tournament]),
    );
    return tournament.id;
  }

  Future<void> addTeam(
    String tournamentId,
    String name,
    String shortCode,
    int colorValue,
  ) async {
    final team = TournamentTeam(
      id: _uuid.v4(),
      name: name.trim(),
      shortCode: shortCode.trim().toUpperCase(),
      colorValue: colorValue,
    );
    await _updateTournament(tournamentId, (tournament) {
      if (tournament.teams.any(
        (item) => item.name.toLowerCase() == team.name.toLowerCase(),
      )) {
        throw StateError('A team with that name already exists.');
      }
      return tournament.copyWith(teams: [...tournament.teams, team]);
    });
  }

  Future<void> addPlayer(
    String tournamentId,
    String teamId, {
    required int number,
    required String name,
    required PlayerPosition position,
    bool isCaptain = false,
  }) async {
    await _updateTournament(tournamentId, (tournament) {
      final teams = tournament.teams.map((team) {
        if (team.id != teamId) return team;
        if (team.players.any((player) => player.number == number)) {
          throw StateError('Jersey number $number is already assigned.');
        }
        final player = Player(
          id: _uuid.v4(),
          number: number,
          name: name.trim(),
          position: position,
          isCaptain: isCaptain,
        );
        return team.copyWith(players: [...team.players, player]);
      }).toList();
      return tournament.copyWith(teams: teams);
    });
  }

  Future<void> generateRoundRobin(
    String tournamentId, {
    DateTime? firstGameAt,
  }) async {
    await _updateTournament(tournamentId, (tournament) {
      if (tournament.teams.length < 2) {
        throw StateError('Add at least two teams first.');
      }
      final existingPairs = tournament.games
          .map((game) => {game.homeTeamId, game.awayTeamId}.toList()..sort())
          .map((pair) => pair.join(':'))
          .toSet();
      final games = [...tournament.games];
      var slot =
          firstGameAt ?? tournament.startsOn.add(const Duration(hours: 9));
      for (var home = 0; home < tournament.teams.length; home++) {
        for (var away = home + 1; away < tournament.teams.length; away++) {
          final pair = [tournament.teams[home].id, tournament.teams[away].id]
            ..sort();
          if (existingPairs.contains(pair.join(':'))) continue;
          games.add(
            Game(
              id: _uuid.v4(),
              tournamentId: tournament.id,
              homeTeamId: tournament.teams[home].id,
              awayTeamId: tournament.teams[away].id,
              scheduledAt: slot,
              venue: tournament.venue,
            ),
          );
          slot = slot.add(const Duration(hours: 2));
        }
      }
      return tournament.copyWith(status: TournamentStatus.active, games: games);
    });
  }

  Future<void> addGame(
    String tournamentId, {
    required String homeTeamId,
    required String awayTeamId,
    required DateTime scheduledAt,
    required String venue,
  }) async {
    if (homeTeamId == awayTeamId) {
      throw StateError('Choose two different teams.');
    }
    await _updateTournament(
      tournamentId,
      (tournament) => tournament.copyWith(
        status: TournamentStatus.active,
        games: [
          ...tournament.games,
          Game(
            id: _uuid.v4(),
            tournamentId: tournamentId,
            homeTeamId: homeTeamId,
            awayTeamId: awayTeamId,
            scheduledAt: scheduledAt,
            venue: venue,
          ),
        ],
      ),
    );
  }

  Future<void> updateRules(String tournamentId, MatchRules rules) async {
    if (rules.setsToWin < 1 ||
        rules.regularSetTarget < 1 ||
        rules.decidingSetTarget < 1 ||
        rules.winBy < 1) {
      throw StateError('Scoring values must be positive.');
    }
    await _updateTournament(
      tournamentId,
      (tournament) => tournament.copyWith(rules: rules),
    );
  }

  Future<void> startScorerLog(
    String tournamentId,
    String gameId, {
    required String assignedTeamId,
    required String initialServingTeamId,
  }) async {
    await _updateGame(tournamentId, gameId, (tournament, game) {
      if (game.logs.any((log) => log.deviceId == state.deviceId)) return game;
      final home = tournament.team(game.homeTeamId);
      final away = tournament.team(game.awayTeamId);
      final now = DateTime.now();
      final log = ScorerLog(
        id: _uuid.v4(),
        gameId: game.id,
        assignedTeamId: assignedTeamId,
        deviceId: state.deviceId,
        createdAt: now,
        updatedAt: now,
        initialServingTeamId: initialServingTeamId,
        lineups: [
          LineupSnapshot(
            teamId: home.id,
            playerIds: home.players.take(6).map((p) => p.id).toList(),
          ),
          LineupSnapshot(
            teamId: away.id,
            playerIds: away.players.take(6).map((p) => p.id).toList(),
          ),
        ],
      );
      return game.copyWith(
        status: GameStatus.inProgress,
        logs: [...game.logs, log],
      );
    });
  }

  Future<void> awardRally(
    String tournamentId,
    String gameId, {
    required String winnerTeamId,
    required List<TeamAction> actions,
    String? overrideReason,
  }) async {
    await _updateGame(tournamentId, gameId, (tournament, game) {
      final index = game.logs.indexWhere(
        (log) => log.deviceId == state.deviceId,
      );
      if (index < 0) {
        throw StateError('Start a scorer log on this device first.');
      }
      final log = game.logs[index];
      if (actions.any((action) => action.teamId != log.assignedTeamId)) {
        throw StateError(
          'This device can record player actions only for its assigned team.',
        );
      }
      final rally = const ScoringEngine().nextRally(
        id: _uuid.v4(),
        game: game,
        log: log,
        rules: tournament.rules,
        winnerTeamId: winnerTeamId,
        recordedAt: DateTime.now(),
        actions: actions,
        overrideReason: overrideReason,
      );
      final logs = [...game.logs];
      logs[index] = log.copyWith(
        updatedAt: DateTime.now(),
        rallies: [...log.rallies, rally],
      );
      final score = const ScoringEngine().score(
        game,
        logs[index],
        tournament.rules,
      );
      return game.copyWith(
        status: score.isComplete
            ? GameStatus.awaitingReconciliation
            : GameStatus.inProgress,
        logs: logs,
      );
    });
  }

  Future<void> undoLastRally(
    String tournamentId,
    String gameId,
    String reason,
  ) async {
    await _updateGame(tournamentId, gameId, (tournament, game) {
      final index = game.logs.indexWhere(
        (log) => log.deviceId == state.deviceId,
      );
      if (index < 0 || game.logs[index].rallies.isEmpty) return game;
      final log = game.logs[index];
      final removed = log.rallies.last;
      final logs = [...game.logs];
      logs[index] = log.copyWith(
        updatedAt: DateTime.now(),
        rallies: log.rallies.sublist(0, log.rallies.length - 1),
        corrections: [
          ...log.corrections,
          Correction(
            id: _uuid.v4(),
            rallyId: removed.id,
            reason: reason,
            correctedAt: DateTime.now(),
            kind: 'undo',
          ),
        ],
      );
      return game.copyWith(status: GameStatus.inProgress, logs: logs);
    });
  }

  Future<void> importGamePackage(GamePackage package) async {
    if (state.importedPackageIds.contains(package.manifest.packageId)) {
      throw StateError('This package has already been imported.');
    }
    final tournaments = [...state.tournaments];
    final tournamentIndex = tournaments.indexWhere(
      (item) => item.id == package.tournament.id,
    );
    if (tournamentIndex < 0) {
      tournaments.add(
        package.tournament.copyWith(
          games: package.tournament.games
              .map(
                (game) => package.log == null
                    ? game
                    : game.copyWith(
                        logs: [package.log!],
                        status: GameStatus.inProgress,
                      ),
              )
              .toList(),
        ),
      );
    } else {
      final local = tournaments[tournamentIndex];
      final incomingGame = package.tournament.games.firstWhere(
        (game) => game.id == package.gameId,
      );
      final games = [...local.games];
      final gameIndex = games.indexWhere((game) => game.id == package.gameId);
      if (gameIndex < 0) {
        games.add(
          package.log == null
              ? incomingGame
              : incomingGame.copyWith(
                  logs: [package.log!],
                  status: GameStatus.inProgress,
                ),
        );
      } else if (package.log != null) {
        final current = games[gameIndex];
        if (current.logs.any((log) => log.id == package.log!.id)) {
          throw StateError('This scorer log is already attached to the game.');
        }
        games[gameIndex] = current.copyWith(
          status: GameStatus.awaitingReconciliation,
          logs: [...current.logs, package.log!],
        );
      }
      tournaments[tournamentIndex] = local.copyWith(games: games);
    }
    await _commit(
      state.copyWith(
        tournaments: tournaments,
        importedPackageIds: [
          ...state.importedPackageIds,
          package.manifest.packageId,
        ],
      ),
    );
  }

  Future<void> finalizeReconciliation(
    String tournamentId,
    String gameId, {
    required Set<String> preferImported,
    required String reason,
  }) async {
    await _updateGame(tournamentId, gameId, (tournament, game) {
      if (game.logs.length < 2) {
        throw StateError('Import the second scorer log first.');
      }
      final result = const ReconciliationService().compare(
        game.logs[0],
        game.logs[1],
      );
      final now = DateTime.now();
      final official = const ReconciliationService().merge(
        result,
        preferImported: preferImported,
        officialLogId: _uuid.v4(),
        now: now,
      );
      final score = const ScoringEngine().score(
        game,
        official,
        tournament.rules,
      );
      if (!score.isComplete) {
        throw StateError(
          'The reconciled score does not contain a complete match.',
        );
      }
      final revision = FinalizationRevision(
        id: _uuid.v4(),
        finalizedAt: now,
        reason: reason,
        officialLog: official,
      );
      return game.copyWith(
        status: GameStatus.finalized,
        officialLog: official,
        revisions: [...game.revisions, revision],
      );
    });
  }

  Future<void> reopenGame(
    String tournamentId,
    String gameId,
    String reason,
  ) async {
    if (reason.trim().isEmpty) {
      throw StateError('A revision reason is required.');
    }
    await _updateGame(
      tournamentId,
      gameId,
      (tournament, game) => game.copyWith(
        status: GameStatus.awaitingReconciliation,
        clearOfficialLog: true,
      ),
    );
  }

  Future<void> restoreBackup(AppData backup) => _commit(
    AppData(
      deviceId: state.deviceId,
      tournaments: backup.tournaments,
      importedPackageIds: backup.importedPackageIds,
      lastBackupAt: DateTime.now(),
    ),
  );

  Future<void> markBackedUp() =>
      _commit(state.copyWith(lastBackupAt: DateTime.now()));

  Future<void> _updateTournament(
    String tournamentId,
    Tournament Function(Tournament tournament) transform,
  ) async {
    final tournaments = [...state.tournaments];
    final index = tournaments.indexWhere((item) => item.id == tournamentId);
    if (index < 0) throw StateError('Tournament not found.');
    tournaments[index] = transform(tournaments[index]);
    await _commit(state.copyWith(tournaments: tournaments));
  }

  Future<void> _updateGame(
    String tournamentId,
    String gameId,
    Game Function(Tournament tournament, Game game) transform,
  ) => _updateTournament(tournamentId, (tournament) {
    final games = [...tournament.games];
    final index = games.indexWhere((item) => item.id == gameId);
    if (index < 0) throw StateError('Game not found.');
    games[index] = transform(tournament, games[index]);
    return tournament.copyWith(games: games);
  });
}
