import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
                          '${item.tournament.name} • ${DateFormat.MMMd().add_jm().format(item.game.scheduledAt)}\n${item.game.status.name} • ${item.game.logs.length}/2 scorer logs',
                        ),
                        isThreeLine: true,
                        trailing: FilledButton.tonal(
                          onPressed: () => item.game.logs.length >= 2
                              ? context.push(
                                  '/tournaments/${item.tournament.id}/games/${item.game.id}/reconcile',
                                )
                              : context.push(
                                  '/tournaments/${item.tournament.id}/games/${item.game.id}/track',
                                ),
                          child: Text(
                            item.game.logs.length >= 2 ? 'Reconcile' : 'Track',
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
