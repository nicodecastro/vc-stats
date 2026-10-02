import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/packages.dart';
import '../domain/statistics.dart';

class FileExchangeService {
  const FileExchangeService();

  Future<void> exportGame(
    AppData data,
    Tournament tournament,
    Game game,
    ScorerLog? log,
  ) async {
    final package = const PortablePackageService().createGamePackage(
      packageId: const Uuid().v4(),
      deviceId: data.deviceId,
      exportedAt: DateTime.now(),
      tournament: tournament,
      game: game,
      log: log,
    );
    await _save(
      '${_safe(tournament.name)}-${game.id.substring(0, 8)}.vcgame',
      package.encode(),
    );
  }

  Future<GamePackage?> pickGamePackage() async {
    // iOS Files disables unknown custom extensions when an accept filter is
    // present. Allow selection first; package decoding validates type/hash.
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import VC SETS game package',
      type: FileType.any,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return const PortablePackageService().decodeGamePackage(utf8.decode(bytes));
  }

  Future<void> exportBackup(AppData data) async {
    final now = DateTime.now();
    final content = const PortablePackageService().createBackup(
      packageId: const Uuid().v4(),
      data: data,
      exportedAt: now,
    );
    await _save(
      'vc-sets-backup-${DateFormat('yyyy-MM-dd-HHmm').format(now)}.vcbackup',
      content,
    );
  }

  Future<AppData?> pickBackup() async {
    // See pickGamePackage: content validation is more portable than an OS
    // extension filter for .vcbackup files.
    final file = await FilePicker.pickFile(
      dialogTitle: 'Restore VC SETS backup',
      type: FileType.any,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return const PortablePackageService().decodeBackup(utf8.decode(bytes));
  }

  Future<void> exportStandingsCsv(Tournament tournament) async {
    final buffer = StringBuffer(
      'Pool,Rank,Team,Played,Wins,Losses,Match points,Sets won,Sets lost,Points won,Points lost\r\n',
    );
    final pools = tournament.format == TournamentFormat.poolsThenKnockout
        ? List.generate(tournament.poolCount, (index) => index + 1)
        : const <int?>[null];
    for (final pool in pools) {
      final rows = const StatisticsService().standings(
        tournament,
        poolNumber: pool,
      );
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        buffer.writeln(
          '${pool == null ? '' : _poolLabel(pool)},${index + 1},${_csv(row.team.name)},${row.played},${row.wins},${row.losses},${row.matchPoints},${row.setsWon},${row.setsLost},${row.pointsWon},${row.pointsLost}',
        );
      }
    }
    await _save(
      '${_safe(tournament.name)}-standings.csv',
      buffer.toString(),
      mime: 'text/csv',
    );
  }

  Future<void> exportPlayersCsv(Tournament tournament) async {
    await _save(
      '${_safe(tournament.name)}-player-stats.csv',
      playerStatsCsv(tournament),
      mime: 'text/csv',
    );
  }

  String playerStatsCsv(Tournament tournament) {
    final rows = const StatisticsService().playerStatsSummary(tournament);
    final buffer = StringBuffer(
      'Team,Last name,Number,${playerStatColumns.join(',')}\r\n',
    );
    for (final row in rows) {
      buffer.writeln(
        '${_csv(row.team.name)},${_csv(row.lastName)},${row.player.number},${playerStatColumns.map((column) => row.counts[column] ?? 0).join(',')}',
      );
    }
    return buffer.toString();
  }

  Future<void> exportPrintableHtml(Tournament tournament) async {
    final pools = tournament.format == TournamentFormat.poolsThenKnockout
        ? List.generate(tournament.poolCount, (index) => index + 1)
        : const <int?>[null];
    final standingsHtml = pools.map((pool) {
      final standings = const StatisticsService().standings(
        tournament,
        poolNumber: pool,
      );
      final heading = pool == null ? 'Standings' : 'Pool ${_poolLabel(pool)}';
      return '''<h2>$heading</h2><table><thead><tr><th>#</th><th>Team</th><th>P</th><th>W</th><th>L</th><th>Pts</th><th>Sets</th><th>Points</th></tr></thead><tbody>
${[for (var i = 0; i < standings.length; i++) '<tr><td>${i + 1}</td><td>${_html(standings[i].team.name)}</td><td>${standings[i].played}</td><td>${standings[i].wins}</td><td>${standings[i].losses}</td><td>${standings[i].matchPoints}</td><td>${standings[i].setsWon}-${standings[i].setsLost}</td><td>${standings[i].pointsWon}-${standings[i].pointsLost}</td></tr>'].join()}
</tbody></table>''';
    }).join();
    final playerStats = const StatisticsService().playerStatsSummary(
      tournament,
    );
    final playerHeader = [
      'Team',
      'Last name',
      '#',
      ...playerStatColumns,
    ].map((column) => '<th>${_html(column)}</th>').join();
    final playerRows = playerStats
        .map(
          (row) =>
              '<tr><td>${_html(row.team.name)}</td><td>${_html(row.lastName)}</td><td>${row.player.number}</td>${playerStatColumns.map((column) => '<td>${row.counts[column] ?? 0}</td>').join()}</tr>',
        )
        .join();
    final html =
        '''<!doctype html>
<html><head><meta charset="utf-8"><title>${_html(tournament.name)} report</title>
<style>
body{font-family:system-ui,sans-serif;margin:32px;color:#17332f}h1{margin-bottom:4px}h2{margin-top:32px}
table{width:100%;border-collapse:collapse;margin-top:12px}th,td{padding:8px;border-bottom:1px solid #ccd8d4;text-align:left}
th{background:#e5f1ed}.player-stats{font-size:9px}.player-stats th,.player-stats td{padding:4px}@media print{body{margin:8mm}.no-print{display:none}@page{size:landscape}}
</style></head><body>
<button class="no-print" onclick="window.print()">Print report</button>
<h1>${_html(tournament.name)}</h1><div>${_html(tournament.venue)} • Generated ${DateFormat.yMMMd().add_jm().format(DateTime.now())}</div>
$standingsHtml<h2>Player stats summary</h2><table class="player-stats"><thead><tr>$playerHeader</tr></thead><tbody>
$playerRows
</tbody></table></body></html>''';
    await _save(
      '${_safe(tournament.name)}-print-report.html',
      html,
      mime: 'text/html',
    );
  }

  Future<void> _save(
    String fileName,
    String source, {
    String mime = 'application/json',
  }) async {
    await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(source)),
      mimeType: mime,
    );
  }

  String _safe(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  String _csv(String value) => '"${value.replaceAll('"', '""')}"';
  String _poolLabel(int pool) =>
      String.fromCharCode('A'.codeUnitAt(0) + pool - 1);
  String _html(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
