import 'models.dart';

class GameLinkPlayer {
  const GameLinkPlayer({
    required this.sourcePlayer,
    required this.sourceTeam,
    required this.targetTeam,
  });

  final Player sourcePlayer;
  final TournamentTeam sourceTeam;
  final TournamentTeam targetTeam;
}

class GameLinkingService {
  const GameLinkingService();

  Map<String, String> teamIdMap({
    required Tournament sourceTournament,
    required Game sourceGame,
    required Tournament targetTournament,
    required Game targetGame,
    required bool sourceHomeMapsToTargetHome,
  }) => {
    sourceGame.homeTeamId: sourceHomeMapsToTargetHome
        ? targetGame.homeTeamId
        : targetGame.awayTeamId,
    sourceGame.awayTeamId: sourceHomeMapsToTargetHome
        ? targetGame.awayTeamId
        : targetGame.homeTeamId,
  };

  List<GameLinkPlayer> playerLinks({
    required Tournament sourceTournament,
    required Game sourceGame,
    required ScorerLog sourceLog,
    required Tournament targetTournament,
    required Game targetGame,
    required bool sourceHomeMapsToTargetHome,
  }) {
    final teams = teamIdMap(
      sourceTournament: sourceTournament,
      sourceGame: sourceGame,
      targetTournament: targetTournament,
      targetGame: targetGame,
      sourceHomeMapsToTargetHome: sourceHomeMapsToTargetHome,
    );
    final referencedIds = <String>{
      for (final lineup in sourceLog.lineups) ...lineup.playerIds,
      for (final item in sourceLog.substitutions) ...[
        item.playerOutId,
        item.playerInId,
      ],
      for (final action in sourceLog.rallies.expand((rally) => rally.actions))
        if (action.playerId != null) action.playerId!,
    };
    final result = <GameLinkPlayer>[];
    for (final sourceTeam in sourceTournament.teams.where(
      (team) => teams.containsKey(team.id),
    )) {
      final targetTeam = targetTournament.team(teams[sourceTeam.id]!);
      for (final sourcePlayer in sourceTeam.players) {
        if (referencedIds.contains(sourcePlayer.id)) {
          result.add(
            GameLinkPlayer(
              sourcePlayer: sourcePlayer,
              sourceTeam: sourceTeam,
              targetTeam: targetTeam,
            ),
          );
        }
      }
    }
    final knownIds = result.map((item) => item.sourcePlayer.id).toSet();
    final unknownIds = referencedIds.difference(knownIds);
    if (unknownIds.isNotEmpty) {
      throw StateError(
        'The imported log references players missing from its roster: ${unknownIds.join(', ')}.',
      );
    }
    return result;
  }

  Map<String, String?> suggestPlayerMappings(List<GameLinkPlayer> links) => {
    for (final link in links)
      link.sourcePlayer.id: _suggestedTargetPlayerId(link),
  };

  List<String> validatePlayerMappings(
    List<GameLinkPlayer> links,
    Map<String, String?> playerIdMap,
  ) {
    final errors = <String>[];
    final usedByTeam = <String, Set<String>>{};
    for (final link in links) {
      final targetId = playerIdMap[link.sourcePlayer.id];
      if (targetId == null) {
        errors.add(
          'Map #${link.sourcePlayer.number} ${link.sourcePlayer.name} from ${link.sourceTeam.shortCode}.',
        );
        continue;
      }
      if (!link.targetTeam.players.any((player) => player.id == targetId)) {
        errors.add(
          'The selected player for #${link.sourcePlayer.number} is not on ${link.targetTeam.shortCode}.',
        );
        continue;
      }
      final used = usedByTeam.putIfAbsent(link.targetTeam.id, () => {});
      if (!used.add(targetId)) {
        errors.add(
          'A ${link.targetTeam.shortCode} player is mapped more than once.',
        );
      }
    }
    return errors;
  }

  ScorerLog linkLog({
    required Tournament sourceTournament,
    required Game sourceGame,
    required ScorerLog sourceLog,
    required Tournament targetTournament,
    required Game targetGame,
    required bool sourceHomeMapsToTargetHome,
    required Map<String, String?> playerIdMap,
    required String linkedLogId,
  }) {
    final teams = teamIdMap(
      sourceTournament: sourceTournament,
      sourceGame: sourceGame,
      targetTournament: targetTournament,
      targetGame: targetGame,
      sourceHomeMapsToTargetHome: sourceHomeMapsToTargetHome,
    );
    final links = playerLinks(
      sourceTournament: sourceTournament,
      sourceGame: sourceGame,
      sourceLog: sourceLog,
      targetTournament: targetTournament,
      targetGame: targetGame,
      sourceHomeMapsToTargetHome: sourceHomeMapsToTargetHome,
    );
    final errors = validatePlayerMappings(links, playerIdMap);
    if (errors.isNotEmpty) throw StateError(errors.join(' '));

    String team(String sourceId) {
      final targetId = teams[sourceId];
      if (targetId == null) {
        throw StateError('The imported log references an unknown team.');
      }
      return targetId;
    }

    String player(String sourceId) {
      final targetId = playerIdMap[sourceId];
      if (targetId == null) {
        throw StateError('The imported log contains an unmapped player.');
      }
      return targetId;
    }

    final swapSides = !sourceHomeMapsToTargetHome;
    return ScorerLog(
      id: linkedLogId,
      gameId: targetGame.id,
      assignedTeamId: team(sourceLog.assignedTeamId),
      deviceId: sourceLog.deviceId,
      createdAt: sourceLog.createdAt,
      updatedAt: sourceLog.updatedAt,
      initialServingTeamId: team(sourceLog.initialServingTeamId),
      lineups: [
        for (final lineup in sourceLog.lineups)
          LineupSnapshot(
            teamId: team(lineup.teamId),
            playerIds: lineup.playerIds.map(player).toList(),
            setNumber: lineup.setNumber,
            rotation: lineup.rotation,
            recordedAt: lineup.recordedAt,
          ),
      ],
      substitutions: [
        for (final item in sourceLog.substitutions)
          Substitution(
            id: item.id,
            teamId: team(item.teamId),
            setNumber: item.setNumber,
            playerOutId: player(item.playerOutId),
            playerInId: player(item.playerInId),
            homeScore: swapSides ? item.awayScore : item.homeScore,
            awayScore: swapSides ? item.homeScore : item.awayScore,
            recordedAt: item.recordedAt,
            kind: item.kind,
          ),
      ],
      timeouts: [
        for (final item in sourceLog.timeouts)
          TeamTimeout(
            id: item.id,
            teamId: team(item.teamId),
            setNumber: item.setNumber,
            homeScore: swapSides ? item.awayScore : item.homeScore,
            awayScore: swapSides ? item.homeScore : item.awayScore,
            recordedAt: item.recordedAt,
          ),
      ],
      rallies: [
        for (final rally in sourceLog.rallies)
          Rally(
            id: rally.id,
            setNumber: rally.setNumber,
            sequence: rally.sequence,
            winnerTeamId: team(rally.winnerTeamId),
            homeScore: swapSides ? rally.awayScore : rally.homeScore,
            awayScore: swapSides ? rally.homeScore : rally.awayScore,
            homeRotation: swapSides ? rally.awayRotation : rally.homeRotation,
            awayRotation: swapSides ? rally.homeRotation : rally.awayRotation,
            servingTeamId: team(rally.servingTeamId),
            recordedAt: rally.recordedAt,
            actions: [
              for (final action in rally.actions)
                TeamAction(
                  id: action.id,
                  teamId: team(action.teamId),
                  playerId: action.playerId == null
                      ? null
                      : player(action.playerId!),
                  skill: action.skill,
                  grade: action.grade,
                  recordedAt: action.recordedAt,
                  note: action.note,
                  metadata: action.metadata,
                ),
            ],
            overrideReason: rally.overrideReason,
            correctionOf: rally.correctionOf,
          ),
      ],
      corrections: sourceLog.corrections,
    );
  }

  String? _suggestedTargetPlayerId(GameLinkPlayer link) {
    final numberMatches = link.targetTeam.players
        .where((player) => player.number == link.sourcePlayer.number)
        .toList();
    if (numberMatches.length == 1) return numberMatches.single.id;
    final sourceName = link.sourcePlayer.name.trim().toLowerCase();
    final nameMatches = link.targetTeam.players
        .where((player) => player.name.trim().toLowerCase() == sourceName)
        .toList();
    return nameMatches.length == 1 ? nameMatches.single.id : null;
  }
}
