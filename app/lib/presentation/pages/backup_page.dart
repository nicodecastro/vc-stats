import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/file_exchange.dart';
import '../../application/providers.dart';
import '../widgets/common.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appControllerProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        const PageHeader(
          title: 'Data & exchange',
          subtitle: 'Your data is local. Export it deliberately, and store copies somewhere safe.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Full backup',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.lastBackupAt == null
                        ? 'No backup recorded on this device.'
                        : 'Last backup: ${DateFormat.yMMMd().add_jm().format(data.lastBackupAt!)}',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _backup(context, ref),
                        icon: const Icon(Icons.download),
                        label: const Text('Export full backup'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _restore(context, ref),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Preview & restore'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Backups are plain JSON and may contain player information. Keep exported files in an appropriately protected location.',
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import a game package',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use this to initialize the second scorer device or bring its completed scorer log back to the tournament device.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => _importGame(context, ref),
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Import .vcgame'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.offline_bolt_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Offline guarantee: scoring, reports, exports, and imports do not require an account or network connection. The hosted PWA contains only application code.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    try {
      await const FileExchangeService().exportBackup(
        ref.read(appControllerProvider),
      );
      await ref.read(appControllerProvider.notifier).markBackedUp();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Backup exported.')));
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    try {
      final backup = await const FileExchangeService().pickBackup();
      if (backup == null || !context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore this backup?'),
          content: Text(
            'The package contains ${backup.tournaments.length} tournament(s). It will replace the current local dataset after confirmation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Replace local data'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(appControllerProvider.notifier).restoreBackup(backup);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup restored successfully.')),
          );
        }
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _importGame(BuildContext context, WidgetRef ref) async {
    try {
      final package = await const FileExchangeService().pickGamePackage();
      if (package == null || !context.mounted) return;
      final game = package.tournament.games.firstWhere(
        (item) => item.id == package.gameId,
      );
      final home = package.tournament.team(game.homeTeamId);
      final away = package.tournament.team(game.awayTeamId);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import game package?'),
          content: Text(
            '${package.tournament.name}\n${home.name} vs ${away.name}\n${package.log == null ? 'Starter package' : 'Includes a scorer log with ${package.log!.rallies.length} rallies'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref
            .read(appControllerProvider.notifier)
            .importGamePackage(package);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Game package imported.')),
          );
        }
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}
