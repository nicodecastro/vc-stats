import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/file_exchange.dart';
import '../../application/providers.dart';
import '../../domain/models.dart';
import '../widgets/common.dart';

class TournamentDetailPage extends ConsumerWidget {
  const TournamentDetailPage({super.key, required this.tournamentId});
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider);
    final tournament = data.tournaments
        .where((item) => item.id == tournamentId)
        .firstOrNull;
    if (tournament == null) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Tournament not found',
        message: 'It may have been replaced by a restored backup.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        PageHeader(
          title: tournament.name,
          subtitle:
              '${DateFormat.yMMMd().format(tournament.startsOn)} • ${tournament.venue} • Best of ${tournament.rules.maxSets}',
          actions: [
            OutlinedButton.icon(
              onPressed: () => _editRules(context, ref, tournament),
              icon: const Icon(Icons.tune),
              label: const Text('Rules'),
            ),
            OutlinedButton.icon(
              onPressed: () => _addTeam(context, ref),
              icon: const Icon(Icons.group_add),
              label: const Text('Add team'),
            ),
            OutlinedButton.icon(
              onPressed: tournament.teams.length < 2
                  ? null
                  : () => _addGame(context, ref, tournament),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add game'),
            ),
            FilledButton.icon(
              onPressed: tournament.teams.length < 2
                  ? null
                  : () => _generate(context, ref),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Round robin'),
            ),
          ],
        ),
        _Section(
          title: 'Teams & tournament rosters',
          child: tournament.teams.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Add at least two teams, then enter each tournament roster.',
                  ),
                )
              : Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: tournament.teams
                      .map(
                        (team) => SizedBox(
                          width: 340,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Color(team.colorValue),
                                        child: Text(
                                          team.shortCode,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          team.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _addPlayer(context, ref, team),
                                        tooltip: 'Add player',
                                        icon: const Icon(Icons.person_add_alt),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  if (team.players.isEmpty)
                                    const Text('No players yet')
                                  else
                                    ...team.players.map(
                                      (player) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 3,
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 34,
                                              child: Text(
                                                '#${player.number}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Expanded(child: Text(player.name)),
                                            Text(
                                              player.position.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        _Section(
          title: 'Fixtures',
          child: tournament.games.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Generate a round robin or add teams first.'),
                )
              : Column(
                  children: tournament.games.map((game) {
                    final home = tournament.team(game.homeTeamId);
                    final away = tournament.team(game.awayTeamId);
                    final localLog = game.logs
                        .where((log) => log.deviceId == data.deviceId)
                        .firstOrNull;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        leading: Icon(
                          _statusIcon(game.status),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          '${home.name}  vs  ${away.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${DateFormat.MMMd().add_jm().format(game.scheduledAt)} • ${game.status.name} • ${game.logs.length} scorer log(s)',
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: localLog == null
                                  ? 'Export starter package'
                                  : 'Export my scorer log',
                              onPressed: () => _exportGame(
                                context,
                                data,
                                tournament,
                                game,
                                localLog,
                              ),
                              icon: const Icon(Icons.ios_share),
                            ),
                            if (game.logs.length >= 2)
                              IconButton(
                                tooltip: 'Reconcile',
                                onPressed: () => context.push(
                                  '/tournaments/$tournamentId/games/${game.id}/reconcile',
                                ),
                                icon: const Icon(Icons.compare_arrows),
                              ),
                            IconButton(
                              tooltip: 'Track match',
                              onPressed: () => context.push(
                                '/tournaments/$tournamentId/games/${game.id}/track',
                              ),
                              icon: const Icon(Icons.sports_volleyball),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Future<void> _addTeam(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final code = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add tournament team'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Team name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Short code'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (accepted != true || name.text.trim().isEmpty) return;
    try {
      await ref
          .read(appControllerProvider.notifier)
          .addTeam(
            tournamentId,
            name.text,
            code.text.isEmpty
                ? name.text.substring(0, name.text.length.clamp(1, 3))
                : code.text,
            Colors
                .primaries[ref
                        .read(appControllerProvider)
                        .tournaments
                        .firstWhere((t) => t.id == tournamentId)
                        .teams
                        .length %
                    Colors.primaries.length]
                .toARGB32(),
          );
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _addPlayer(
    BuildContext context,
    WidgetRef ref,
    TournamentTeam team,
  ) async {
    final name = TextEditingController();
    final number = TextEditingController();
    var position = PlayerPosition.UT;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add player to ${team.name}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: number,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jersey number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Player name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PlayerPosition>(
                  initialValue: position,
                  decoration: const InputDecoration(labelText: 'Position'),
                  items: PlayerPosition.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => position = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add player'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true ||
        name.text.trim().isEmpty ||
        int.tryParse(number.text) == null) {
      return;
    }
    try {
      await ref
          .read(appControllerProvider.notifier)
          .addPlayer(
            tournamentId,
            team.id,
            number: int.parse(number.text),
            name: name.text,
            position: position,
          );
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(appControllerProvider.notifier)
          .generateRoundRobin(tournamentId);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _addGame(
    BuildContext context,
    WidgetRef ref,
    Tournament tournament,
  ) async {
    var homeId = tournament.teams.first.id;
    var awayId = tournament.teams[1].id;
    var scheduledAt = tournament.startsOn.add(const Duration(hours: 9));
    final venue = TextEditingController(text: tournament.venue);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add game'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: homeId,
                  decoration: const InputDecoration(labelText: 'Home team'),
                  items: tournament.teams
                      .map(
                        (team) => DropdownMenuItem(
                          value: team.id,
                          child: Text(team.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => homeId = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: awayId,
                  decoration: const InputDecoration(labelText: 'Away team'),
                  items: tournament.teams
                      .map(
                        (team) => DropdownMenuItem(
                          value: team.id,
                          child: Text(team.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => awayId = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: venue,
                  decoration: const InputDecoration(labelText: 'Venue'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Scheduled date'),
                  subtitle: Text(
                    DateFormat.yMMMd().add_jm().format(scheduledAt),
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2040),
                      initialDate: scheduledAt,
                    );
                    if (date != null) {
                      setState(
                        () => scheduledAt = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          scheduledAt.hour,
                          scheduledAt.minute,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add game'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    try {
      await ref
          .read(appControllerProvider.notifier)
          .addGame(
            tournament.id,
            homeTeamId: homeId,
            awayTeamId: awayId,
            scheduledAt: scheduledAt,
            venue: venue.text,
          );
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _editRules(
    BuildContext context,
    WidgetRef ref,
    Tournament tournament,
  ) async {
    final sets = TextEditingController(text: '${tournament.rules.setsToWin}');
    final regular = TextEditingController(
      text: '${tournament.rules.regularSetTarget}',
    );
    final deciding = TextEditingController(
      text: '${tournament.rules.decidingSetTarget}',
    );
    final winBy = TextEditingController(text: '${tournament.rules.winBy}');
    final clearWin = TextEditingController(
      text: '${tournament.rules.standings.clearWinPoints}',
    );
    final decidingWin = TextEditingController(
      text: '${tournament.rules.standings.decidingWinPoints}',
    );
    final decidingLoss = TextEditingController(
      text: '${tournament.rules.standings.decidingLossPoints}',
    );
    final clearLoss = TextEditingController(
      text: '${tournament.rules.standings.clearLossPoints}',
    );
    final tieBreakers = [...tournament.rules.standings.tieBreakers];
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Scoring & standings rules'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _NumberField(controller: sets, label: 'Sets to win'),
                      _NumberField(
                        controller: regular,
                        label: 'Regular target',
                      ),
                      _NumberField(
                        controller: deciding,
                        label: 'Deciding target',
                      ),
                      _NumberField(controller: winBy, label: 'Win by'),
                      _NumberField(
                        controller: clearWin,
                        label: 'Clear win pts',
                      ),
                      _NumberField(
                        controller: decidingWin,
                        label: 'Deciding win pts',
                      ),
                      _NumberField(
                        controller: decidingLoss,
                        label: 'Deciding loss pts',
                      ),
                      _NumberField(
                        controller: clearLoss,
                        label: 'Clear loss pts',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Tie-break priority (drag to reorder)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 230,
                    child: ReorderableListView(
                      shrinkWrap: true,
                      onReorderItem: (oldIndex, newIndex) => setState(() {
                        tieBreakers.insert(
                          newIndex,
                          tieBreakers.removeAt(oldIndex),
                        );
                      }),
                      children: [
                        for (final item in tieBreakers)
                          ListTile(
                            key: ValueKey(item),
                            title: Text(item),
                            trailing: const Icon(Icons.drag_handle),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save rules'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    try {
      final setsToWin = int.parse(sets.text);
      await ref
          .read(appControllerProvider.notifier)
          .updateRules(
            tournament.id,
            MatchRules(
              setsToWin: setsToWin,
              maxSets: setsToWin * 2 - 1,
              regularSetTarget: int.parse(regular.text),
              decidingSetTarget: int.parse(deciding.text),
              winBy: int.parse(winBy.text),
              standings: StandingsPolicy(
                clearWinPoints: int.parse(clearWin.text),
                decidingWinPoints: int.parse(decidingWin.text),
                decidingLossPoints: int.parse(decidingLoss.text),
                clearLossPoints: int.parse(clearLoss.text),
                tieBreakers: tieBreakers,
              ),
            ),
          );
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _exportGame(
    BuildContext context,
    AppData data,
    Tournament tournament,
    Game game,
    ScorerLog? log,
  ) async {
    try {
      await const FileExchangeService().exportGame(data, tournament, game, log);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Game package exported.')));
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  IconData _statusIcon(GameStatus status) => switch (status) {
    GameStatus.scheduled => Icons.schedule,
    GameStatus.inProgress => Icons.play_circle_outline,
    GameStatus.awaitingReconciliation => Icons.compare_arrows,
    GameStatus.finalized => Icons.verified,
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 118,
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
