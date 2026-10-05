import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import '../../domain/reconciliation.dart';
import '../widgets/common.dart';

String _rallySummary(Rally? rally, Tournament tournament) {
  if (rally == null) return 'Missing rally';
  final actions = rally.actions
      .map((action) => action.notation(tournament.team(action.teamId)))
      .join('  ');
  return '${rally.homeScore}-${rally.awayScore} • ${actions.isEmpty ? 'No actions recorded' : actions}';
}

class ReconcilePage extends ConsumerStatefulWidget {
  const ReconcilePage({
    super.key,
    required this.tournamentId,
    required this.gameId,
  });
  final String tournamentId;
  final String gameId;
  @override
  ConsumerState<ReconcilePage> createState() => _ReconcilePageState();
}

class _ReconcilePageState extends ConsumerState<ReconcilePage> {
  final choices = <String, bool>{};
  bool saving = false;
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appControllerProvider);
    final tournament = data.tournaments.firstWhere(
      (item) => item.id == widget.tournamentId,
    );
    final game = tournament.games.firstWhere(
      (item) => item.id == widget.gameId,
    );
    if (game.status == GameStatus.finalized) {
      final comparison = game.logs.length < 2
          ? null
          : const ReconciliationService().compare(game.logs[0], game.logs[1]);
      return _FinalizedReconciliationSummary(
        tournament: tournament,
        game: game,
        comparison: comparison,
      );
    }
    if (game.logs.length < 2) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Reconcile'),
        ),
        body: const EmptyState(
          icon: Icons.compare_arrows,
          title: 'Second scorer log needed',
          message: 'Import the other team device’s .vcgame package first.',
        ),
      );
    }
    final comparison = const ReconciliationService().compare(
      game.logs[0],
      game.logs[1],
    );
    final home = tournament.team(game.homeTeamId);
    final away = tournament.team(game.awayTeamId);
    final allResolved = comparison.conflicts.every(
      (conflict) => choices.containsKey(conflict.key),
    );
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Reconcile ${home.shortCode} vs ${away.shortCode}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              color: comparison.conflicts.isEmpty
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      comparison.conflicts.isEmpty
                          ? Icons.check_circle
                          : Icons.rule,
                      size: 34,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comparison.conflicts.isEmpty
                                ? 'The independent score streams agree'
                                : '${comparison.conflicts.length} decision(s) required',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Player actions from both assigned teams are combined automatically. Choose the authoritative score wherever the devices differ.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...comparison.conflicts.map(
              (conflict) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conflict.message,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        RadioGroup<bool>(
                          groupValue: choices[conflict.key],
                          onChanged: (value) =>
                              setState(() => choices[conflict.key] = value!),
                          child: Row(
                            children: [
                              Expanded(
                                child: RadioListTile<bool>(
                                  value: false,
                                  title: const Text('Device A'),
                                  subtitle: Text(
                                    _rallySummary(conflict.primary, tournament),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<bool>(
                                  value: true,
                                  title: const Text('Device B'),
                                  subtitle: Text(
                                    _rallySummary(
                                      conflict.imported,
                                      tournament,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: !allResolved || saving
                  ? null
                  : () => _finalize(comparison),
              icon: const Icon(Icons.verified),
              label: Text(saving ? 'Finalizing…' : 'Finalize official match'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Finalization creates a historical revision. Tournament totals and standings use only this official combined record.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finalize(ReconciliationResult result) async {
    setState(() => saving = true);
    try {
      await ref
          .read(appControllerProvider.notifier)
          .finalizeReconciliation(
            widget.tournamentId,
            widget.gameId,
            preferImported: choices.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toSet(),
            reason: 'Initial two-device reconciliation',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match finalized and tournament totals updated.'),
          ),
        );
        context.pop();
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _FinalizedReconciliationSummary extends StatelessWidget {
  const _FinalizedReconciliationSummary({
    required this.tournament,
    required this.game,
    required this.comparison,
  });

  final Tournament tournament;
  final Game game;
  final ReconciliationResult? comparison;

  @override
  Widget build(BuildContext context) {
    final home = tournament.team(game.homeTeamId);
    final away = tournament.team(game.awayTeamId);
    final revision = game.revisions.isEmpty ? null : game.revisions.last;
    final official = revision?.officialLog ?? game.officialLog;
    final setFinals = <int, Rally>{};
    for (final rally in official?.rallies ?? const <Rally>[]) {
      setFinals[rally.setNumber] = rally;
    }
    final orderedSets = setFinals.values.toList()
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    final homeSets = orderedSets
        .where((rally) => rally.homeScore > rally.awayScore)
        .length;
    final awaySets = orderedSets.length - homeSets;
    final officialByKey = {
      for (final rally in official?.rallies ?? const <Rally>[])
        rally.alignmentKey: rally,
    };
    final conflicts = comparison?.conflicts ?? const <ReconciliationConflict>[];
    final sourceActions = game.logs
        .take(2)
        .map(
          (log) => log.rallies.fold<int>(
            0,
            (total, rally) => total + rally.actions.length,
          ),
        )
        .toList();
    final officialActions =
        official?.rallies.fold<int>(
          0,
          (total, rally) => total + rally.actions.length,
        ) ??
        0;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Summary ${home.shortCode} vs ${away.shortCode}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, size: 34),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Final result',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${home.shortCode} $homeSets–$awaySets ${away.shortCode}',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (orderedSets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final rally in orderedSets)
                            Chip(
                              label: Text(
                                'Set ${rally.setNumber}: ${rally.homeScore}-${rally.awayScore}',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reconciliation summary',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${game.logs.length} scorer logs combined • ${conflicts.length} decision(s)',
                    ),
                    if (sourceActions.length >= 2)
                      Text(
                        'Actions: Device A ${sourceActions[0]} • Device B ${sourceActions[1]} • Official $officialActions',
                      ),
                    if (revision != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Finalized ${DateFormat.yMMMd().add_jm().format(revision.finalizedAt.toLocal())}',
                      ),
                      Text('Reason: ${revision.reason}'),
                      if (game.revisions.length > 1)
                        Text('Revision ${game.revisions.length}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (comparison == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'The original two-device comparison is not available for this finalized game.',
                  ),
                ),
              )
            else if (conflicts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'The score streams agreed. Player actions from both devices were combined automatically.',
                  ),
                ),
              )
            else ...[
              Text(
                'Decisions',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final conflict in conflicts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReconciledDecisionCard(
                    tournament: tournament,
                    conflict: conflict,
                    officialRally: officialByKey[conflict.key],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReconciledDecisionCard extends StatelessWidget {
  const _ReconciledDecisionCard({
    required this.tournament,
    required this.conflict,
    required this.officialRally,
  });

  final Tournament tournament;
  final ReconciliationConflict conflict;
  final Rally? officialRally;

  @override
  Widget build(BuildContext context) {
    final selectedDevice = officialRally?.id == conflict.imported?.id
        ? 'Device B'
        : 'Device A';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conflict.message,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Device A: ${_rallySummary(conflict.primary, tournament)}'),
            const SizedBox(height: 4),
            Text('Device B: ${_rallySummary(conflict.imported, tournament)}'),
            const SizedBox(height: 10),
            Chip(
              avatar: const Icon(Icons.check, size: 18),
              label: Text('Official: $selectedDevice'),
            ),
          ],
        ),
      ),
    );
  }
}
