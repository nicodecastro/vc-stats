import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/file_exchange.dart';
import '../../application/providers.dart';
import '../../domain/models.dart';
import '../widgets/common.dart';

class GamesPage extends ConsumerWidget {
  const GamesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider);
    final entries = [
      for (final tournament in data.tournaments)
        for (final game in tournament.games)
          (tournament: tournament, game: game),
    ]..sort((a, b) => a.game.scheduledAt.compareTo(b.game.scheduledAt));
    return Column(
      children: [
        const PageHeader(
          title: 'Games',
          subtitle: 'Track matches independently on two devices, then reconcile the logs.',
        ),
        Expanded(
          child: entries.isEmpty
              ? const EmptyState(
                  icon: Icons.sports_volleyball_outlined,
                  title: 'No fixtures yet',
                  message: 'Open a tournament and generate its round-robin schedule.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = entries[index];
                    final home = item.tournament.team(item.game.homeTeamId);
                    final away = item.tournament.team(item.game.awayTeamId);
                    final localLogs = item.game.logs.where(
                      (log) => log.deviceId == data.deviceId,
                    );
                    final localLog = localLogs.isEmpty ? null : localLogs.first;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: Icon(
                            item.game.status == GameStatus.finalized
                                ? Icons.check
                                : Icons.sports_volleyball,
                          ),
                        ),
                        title: Text(
                          '${home.shortCode} vs ${away.shortCode}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${item.tournament.name} • ${DateFormat.MMMd().add_jm().format(item.game.scheduledAt)}\n${_gameLabel(item.game)} • best of ${item.tournament.rulesFor(item.game).maxSets} • ${item.game.status.name} • ${item.game.logs.length}/2 scorer logs',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.tonal(
                              onPressed: () => item.game.logs.length >= 2
                                  ? context.push(
                                      '/tournaments/${item.tournament.id}/games/${item.game.id}/reconcile',
                                    )
                                  : context.push(
                                      '/tournaments/${item.tournament.id}/games/${item.game.id}/track',
                                    ),
                              child: Text(
                                item.game.logs.length >= 2
                                    ? 'Reconcile'
                                    : 'Track',
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Game actions',
                              onSelected: (value) async {
                                if (value == 'export') {
                                  await _exportGame(
                                    context,
                                    data,
                                    item.tournament,
                                    item.game,
                                    localLog,
                                  );
                                } else if (value == 'delete') {
                                  await _deleteGame(
                                    context,
                                    ref,
                                    item.tournament,
                                    item.game,
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'export',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.ios_share),
                                    title: Text(
                                      localLog == null
                                          ? 'Export starter package'
                                          : 'Export scorer log',
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.delete_outline,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                    title: Text(
                                      'Delete game',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _gameLabel(Game game) {
    if (game.stage == GameStage.pool) {
      final pool = game.poolNumber;
      return pool == null
          ? 'Round robin'
          : 'Pool ${String.fromCharCode('A'.codeUnitAt(0) + pool - 1)}';
    }
    return switch (game.bracketType) {
      BracketGameType.finalMatch => 'Final',
      BracketGameType.thirdPlace => 'Third-place game',
      BracketGameType.standard => 'Knockout round ${game.bracketRound}',
    };
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

  Future<void> _deleteGame(
    BuildContext context,
    WidgetRef ref,
    Tournament tournament,
    Game game,
  ) async {
    final confirmed = await confirmDeleteGame(
      context,
      tournament: tournament,
      game: game,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref
          .read(appControllerProvider.notifier)
          .deleteGame(tournament.id, game.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Game deleted.')));
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}
