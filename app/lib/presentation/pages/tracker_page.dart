import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import '../../domain/scoring.dart';
import '../widgets/common.dart';

class TrackerPage extends ConsumerStatefulWidget {
  const TrackerPage({
    super.key,
    required this.tournamentId,
    required this.gameId,
  });
  final String tournamentId;
  final String gameId;
  @override
  ConsumerState<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends ConsumerState<TrackerPage> {
  final pending = <TeamAction>[];
  String? selectedPlayerId;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider);
    final tournament = data.tournaments.firstWhere(
      (item) => item.id == widget.tournamentId,
    );
    final game = tournament.games.firstWhere(
      (item) => item.id == widget.gameId,
    );
    final home = tournament.team(game.homeTeamId);
    final away = tournament.team(game.awayTeamId);
    final localLogs = game.logs.where((log) => log.deviceId == data.deviceId);
    if (localLogs.isEmpty) {
      return _AssignmentPage(
        tournament: tournament,
        game: game,
        home: home,
        away: away,
        onStart: (assigned, server) => ref
            .read(appControllerProvider.notifier)
            .startScorerLog(
              tournament.id,
              game.id,
              assignedTeamId: assigned,
              initialServingTeamId: server,
            ),
      );
    }
    final log = localLogs.first;
    final assigned = tournament.team(log.assignedTeamId);
    selectedPlayerId ??= assigned.players.firstOrNull?.id;
    final score = const ScoringEngine().score(game, log, tournament.rules);
    return Scaffold(
      appBar: AppBar(
        title: Text('${home.shortCode} vs ${away.shortCode}'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: const Icon(Icons.edit, size: 17),
              label: Text('Tracking ${assigned.shortCode}'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final scorePanel = _ScorePanel(
              home: home,
              away: away,
              score: score,
              disabled: score.isComplete,
              onHome: () => _award(home.id),
              onAway: () => _award(away.id),
            );
            final entryPanel = _EntryPanel(
              team: assigned,
              selectedPlayerId: selectedPlayerId,
              pending: pending,
              onPlayerChanged: (value) =>
                  setState(() => selectedPlayerId = value),
              onAdd: _addAction,
              onRemove: (action) => setState(() => pending.remove(action)),
              onUndo: log.rallies.isEmpty ? null : _undo,
            );
            final timeline = _Timeline(log: log, home: home, away: away);
            if (wide) {
              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        scorePanel,
                        const SizedBox(height: 16),
                        entryPanel,
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 3, child: timeline),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                scorePanel,
                const SizedBox(height: 14),
                entryPanel,
                const SizedBox(height: 14),
                SizedBox(height: 420, child: timeline),
              ],
            );
          },
        ),
      ),
    );
  }

  void _addAction(Skill skill, ActionGrade grade, TournamentTeam team) {
    if (skill != Skill.timeout &&
        skill != Skill.substitution &&
        selectedPlayerId == null) {
      return;
    }
    setState(
      () => pending.add(
        TeamAction(
          id: const Uuid().v4(),
          teamId: team.id,
          playerId: skill == Skill.timeout ? null : selectedPlayerId,
          skill: skill,
          grade: grade,
          recordedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _award(String teamId) async {
    try {
      await ref
          .read(appControllerProvider.notifier)
          .awardRally(
            widget.tournamentId,
            widget.gameId,
            winnerTeamId: teamId,
            actions: [...pending],
          );
      if (mounted) setState(pending.clear);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _undo() async {
    final reason = TextEditingController(text: 'Scoring correction');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Undo last rally'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Correction reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await ref
          .read(appControllerProvider.notifier)
          .undoLastRally(widget.tournamentId, widget.gameId, reason.text);
    }
  }
}

class _AssignmentPage extends StatefulWidget {
  const _AssignmentPage({
    required this.tournament,
    required this.game,
    required this.home,
    required this.away,
    required this.onStart,
  });
  final Tournament tournament;
  final Game game;
  final TournamentTeam home;
  final TournamentTeam away;
  final Future<void> Function(String assigned, String server) onStart;
  @override
  State<_AssignmentPage> createState() => _AssignmentPageState();
}

class _AssignmentPageState extends State<_AssignmentPage> {
  late String assigned = widget.home.id;
  late String server = widget.home.id;
  bool working = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Set up scorer device'),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.devices, size: 48),
                  const SizedBox(height: 14),
                  Text(
                    'Which team is this device tracking?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Both devices score every rally. Player actions are limited to the selected team.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: widget.home.id,
                        label: Text(widget.home.name),
                      ),
                      ButtonSegment(
                        value: widget.away.id,
                        label: Text(widget.away.name),
                      ),
                    ],
                    selected: {assigned},
                    onSelectionChanged: (value) =>
                        setState(() => assigned = value.first),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'First serving team',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: widget.home.id,
                        label: Text(widget.home.shortCode),
                      ),
                      ButtonSegment(
                        value: widget.away.id,
                        label: Text(widget.away.shortCode),
                      ),
                    ],
                    selected: {server},
                    onSelectionChanged: (value) =>
                        setState(() => server = value.first),
                  ),
                  if (widget.tournament.team(assigned).players.length < 6) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Warning: this roster has fewer than six players. Tracking is allowed as an explicit operational override.',
                      style: TextStyle(color: Colors.deepOrange),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: working
                        ? null
                        : () async {
                            setState(() => working = true);
                            try {
                              await widget.onStart(assigned, server);
                            } finally {
                              if (mounted) setState(() => working = false);
                            }
                          },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start scorer log'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    required this.home,
    required this.away,
    required this.score,
    required this.disabled,
    required this.onHome,
    required this.onAway,
  });
  final TournamentTeam home;
  final TournamentTeam away;
  final MatchScore score;
  final bool disabled;
  final VoidCallback onHome;
  final VoidCallback onAway;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                disabled ? 'MATCH COMPLETE' : 'SET ${score.setNumber}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Text('Sets ${score.homeSets} – ${score.awaySets}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TeamScore(
                  team: home,
                  points: score.homePoints,
                  rotation: score.homeRotation,
                  serving: score.servingTeamId == home.id,
                  onTap: disabled ? null : onHome,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '–',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              Expanded(
                child: _TeamScore(
                  team: away,
                  points: score.awayPoints,
                  rotation: score.awayRotation,
                  serving: score.servingTeamId == away.id,
                  onTap: disabled ? null : onAway,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap a team panel to award the next rally',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.team,
    required this.points,
    required this.rotation,
    required this.serving,
    required this.onTap,
  });
  final TournamentTeam team;
  final int points;
  final int rotation;
  final bool serving;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Color(team.colorValue).withValues(alpha: .12),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (serving) const Icon(Icons.sports_volleyball, size: 18),
                if (serving) const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    team.shortCode,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Text(
              '$points',
              style: Theme.of(context).textTheme.displayLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text('Rotation $rotation'),
          ],
        ),
      ),
    ),
  );
}

class _EntryPanel extends StatelessWidget {
  const _EntryPanel({
    required this.team,
    required this.selectedPlayerId,
    required this.pending,
    required this.onPlayerChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onUndo,
  });
  final TournamentTeam team;
  final String? selectedPlayerId;
  final List<TeamAction> pending;
  final ValueChanged<String?> onPlayerChanged;
  final void Function(Skill, ActionGrade, TournamentTeam) onAdd;
  final ValueChanged<TeamAction> onRemove;
  final VoidCallback? onUndo;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Player actions',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: onUndo,
                tooltip: 'Undo last rally',
                icon: const Icon(Icons.undo),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue:
                team.players.any((player) => player.id == selectedPlayerId)
                ? selectedPlayerId
                : null,
            decoration: const InputDecoration(labelText: 'Active player'),
            items: team.players
                .map(
                  (player) => DropdownMenuItem(
                    value: player.id,
                    child: Text('#${player.number} ${player.name}'),
                  ),
                )
                .toList(),
            onChanged: onPlayerChanged,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in [
                Skill.serve,
                Skill.reception,
                Skill.set,
                Skill.attack,
                Skill.block,
                Skill.dig,
              ])
                FilledButton.tonal(
                  onPressed: selectedPlayerId == null
                      ? null
                      : () => onAdd(skill, ActionGrade.success, team),
                  child: Text('${skill.name} +'),
                ),
              OutlinedButton(
                onPressed: selectedPlayerId == null
                    ? null
                    : () => onAdd(Skill.error, ActionGrade.error, team),
                child: const Text('Error'),
              ),
              OutlinedButton(
                onPressed: () =>
                    onAdd(Skill.timeout, ActionGrade.neutral, team),
                child: const Text('Timeout'),
              ),
              OutlinedButton(
                onPressed: selectedPlayerId == null
                    ? null
                    : () =>
                          onAdd(Skill.substitution, ActionGrade.neutral, team),
                child: const Text('Substitution'),
              ),
            ],
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('This rally', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 6,
              children: pending
                  .map(
                    (action) => InputChip(
                      label: Text(
                        '${action.skill.name} ${action.grade == ActionGrade.success ? '+' : ''}',
                      ),
                      onDeleted: () => onRemove(action),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.log, required this.home, required this.away});
  final ScorerLog log;
  final TournamentTeam home;
  final TournamentTeam away;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Text(
          'Event timeline',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      Expanded(
        child: log.rallies.isEmpty
            ? const Center(child: Text('The first rally will appear here.'))
            : ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: log.rallies.length,
                itemBuilder: (context, reverseIndex) {
                  final rally =
                      log.rallies[log.rallies.length - 1 - reverseIndex];
                  final winner = rally.winnerTeamId == home.id ? home : away;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 17,
                      child: Text(
                        '${rally.sequence}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    title: Text(
                      '${winner.shortCode} point  •  ${rally.homeScore}-${rally.awayScore}',
                    ),
                    subtitle: Text(
                      'Set ${rally.setNumber}${rally.actions.isEmpty ? '' : ' • ${rally.actions.map((a) => a.skill.name).join(', ')}'}',
                    ),
                  );
                },
              ),
      ),
    ],
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
