import 'package:flutter_test/flutter_test.dart';
import 'package:vc_sets/domain/game_linking.dart';
import 'package:vc_sets/domain/models.dart';

void main() {
  test('linking remaps teams, players, and reversed home-away state', () {
    const sourceHomePlayer = Player(
      id: 'source-home-1',
      number: 1,
      name: 'Ana Cruz',
      position: PlayerPosition.S,
    );
    const sourceHomeBench = Player(
      id: 'source-home-2',
      number: 2,
      name: 'Bea Santos',
      position: PlayerPosition.OH,
    );
    const sourceAwayPlayer = Player(
      id: 'source-away-7',
      number: 7,
      name: 'Cara Reyes',
      position: PlayerPosition.MB,
    );
    const targetHomePlayer = Player(
      id: 'target-home-7',
      number: 7,
      name: 'Cara Reyes',
      position: PlayerPosition.MB,
    );
    const targetAwayPlayer = Player(
      id: 'target-away-1',
      number: 1,
      name: 'Ana Cruz',
      position: PlayerPosition.S,
    );
    const targetAwayBench = Player(
      id: 'target-away-2',
      number: 2,
      name: 'Bea Santos',
      position: PlayerPosition.OH,
    );
    const sourceHome = TournamentTeam(
      id: 'source-home',
      name: 'Alpha',
      shortCode: 'ALP',
      colorValue: 0xFF000001,
      players: [sourceHomePlayer, sourceHomeBench],
    );
    const sourceAway = TournamentTeam(
      id: 'source-away',
      name: 'Beta',
      shortCode: 'BET',
      colorValue: 0xFF000002,
      players: [sourceAwayPlayer],
    );
    const targetHome = TournamentTeam(
      id: 'target-home',
      name: 'Beta',
      shortCode: 'BET',
      colorValue: 0xFF000002,
      players: [targetHomePlayer],
    );
    const targetAway = TournamentTeam(
      id: 'target-away',
      name: 'Alpha',
      shortCode: 'ALP',
      colorValue: 0xFF000001,
      players: [targetAwayPlayer, targetAwayBench],
    );
    final now = DateTime.utc(2026, 10, 3);
    final sourceGame = Game(
      id: 'source-game',
      tournamentId: 'source-tournament',
      homeTeamId: sourceHome.id,
      awayTeamId: sourceAway.id,
      scheduledAt: now,
      venue: 'Gym',
    );
    final targetGame = Game(
      id: 'target-game',
      tournamentId: 'target-tournament',
      homeTeamId: targetHome.id,
      awayTeamId: targetAway.id,
      scheduledAt: now,
      venue: 'Gym',
    );
    final sourceTournament = Tournament(
      id: 'source-tournament',
      name: 'Source',
      venue: 'Gym',
      startsOn: now,
      endsOn: now,
      createdAt: now,
      teams: const [sourceHome, sourceAway],
      games: [sourceGame],
    );
    final targetTournament = Tournament(
      id: 'target-tournament',
      name: 'Target',
      venue: 'Gym',
      startsOn: now,
      endsOn: now,
      createdAt: now,
      teams: const [targetHome, targetAway],
      games: [targetGame],
    );
    final sourceLog = ScorerLog(
      id: 'source-log',
      gameId: sourceGame.id,
      assignedTeamId: sourceHome.id,
      deviceId: 'source-device',
      createdAt: now,
      updatedAt: now,
      initialServingTeamId: sourceAway.id,
      lineups: const [
        LineupSnapshot(teamId: 'source-home', playerIds: ['source-home-1']),
        LineupSnapshot(teamId: 'source-away', playerIds: ['source-away-7']),
      ],
      substitutions: [
        Substitution(
          id: 'sub',
          teamId: sourceHome.id,
          setNumber: 1,
          playerOutId: sourceHomePlayer.id,
          playerInId: sourceHomeBench.id,
          homeScore: 4,
          awayScore: 2,
          recordedAt: now,
        ),
      ],
      timeouts: [
        TeamTimeout(
          id: 'timeout',
          teamId: sourceHome.id,
          setNumber: 1,
          homeScore: 8,
          awayScore: 5,
          recordedAt: now,
        ),
      ],
      rallies: [
        Rally(
          id: 'rally',
          setNumber: 1,
          sequence: 10,
          winnerTeamId: sourceHome.id,
          homeScore: 10,
          awayScore: 5,
          homeRotation: 2,
          awayRotation: 3,
          servingTeamId: sourceAway.id,
          recordedAt: now,
          actions: [
            TeamAction(
              id: 'action',
              teamId: sourceHome.id,
              playerId: sourceHomePlayer.id,
              skill: Skill.attack,
              grade: ActionGrade.success,
              recordedAt: now,
            ),
          ],
        ),
      ],
    );
    const linker = GameLinkingService();
    final links = linker.playerLinks(
      sourceTournament: sourceTournament,
      sourceGame: sourceGame,
      sourceLog: sourceLog,
      targetTournament: targetTournament,
      targetGame: targetGame,
      sourceHomeMapsToTargetHome: false,
    );
    final mappings = linker.suggestPlayerMappings(links);

    final linked = linker.linkLog(
      sourceTournament: sourceTournament,
      sourceGame: sourceGame,
      sourceLog: sourceLog,
      targetTournament: targetTournament,
      targetGame: targetGame,
      sourceHomeMapsToTargetHome: false,
      playerIdMap: mappings,
      linkedLogId: 'linked-log',
    );

    expect(linked.id, 'linked-log');
    expect(linked.gameId, targetGame.id);
    expect(linked.assignedTeamId, targetAway.id);
    expect(linked.initialServingTeamId, targetHome.id);
    expect(linked.rallies.single.winnerTeamId, targetAway.id);
    expect(linked.rallies.single.homeScore, 5);
    expect(linked.rallies.single.awayScore, 10);
    expect(linked.rallies.single.homeRotation, 3);
    expect(linked.rallies.single.awayRotation, 2);
    expect(linked.rallies.single.actions.single.teamId, targetAway.id);
    expect(linked.rallies.single.actions.single.playerId, targetAwayPlayer.id);
    expect(linked.substitutions.single.playerInId, targetAwayBench.id);
    expect(linked.substitutions.single.homeScore, 2);
    expect(linked.timeouts.single.homeScore, 5);
  });
}
