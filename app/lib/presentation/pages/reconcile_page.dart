import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../domain/reconciliation.dart';
import '../widgets/common.dart';

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
                                  subtitle: Text(_score(conflict.primary)),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<bool>(
                                  value: true,
                                  title: const Text('Device B'),
                                  subtitle: Text(_score(conflict.imported)),
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

  String _score(dynamic rally) => rally == null
      ? 'Missing rally'
      : '${rally.homeScore}-${rally.awayScore} • winner ${rally.winnerTeamId.toString().substring(0, 6)}';

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
