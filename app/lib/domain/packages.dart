import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'models.dart';

class PackageManifest {
  const PackageManifest({
    required this.schemaVersion,
    required this.packageId,
    required this.type,
    required this.sourceDeviceId,
    required this.exportedAt,
    required this.payloadSha256,
  });
  final int schemaVersion;
  final String packageId;
  final String type;
  final String sourceDeviceId;
  final DateTime exportedAt;
  final String payloadSha256;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'packageId': packageId,
    'type': type,
    'sourceDeviceId': sourceDeviceId,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'payloadSha256': payloadSha256,
  };

  factory PackageManifest.fromJson(Map<String, Object?> json) =>
      PackageManifest(
        schemaVersion: (json['schemaVersion'] as num).toInt(),
        packageId: json['packageId']! as String,
        type: json['type']! as String,
        sourceDeviceId: json['sourceDeviceId']! as String,
        exportedAt: DateTime.parse(json['exportedAt']! as String),
        payloadSha256: json['payloadSha256']! as String,
      );
}

class GamePackage {
  const GamePackage({
    required this.manifest,
    required this.tournament,
    required this.gameId,
    this.log,
  });
  final PackageManifest manifest;
  final Tournament tournament;
  final String gameId;
  final ScorerLog? log;

  Map<String, Object?> get payload => {
    'tournament': tournament.toJson(),
    'gameId': gameId,
    'log': log?.toJson(),
  };
  Map<String, Object?> toJson() => {
    'manifest': manifest.toJson(),
    'payload': payload,
  };
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class PortablePackageService {
  const PortablePackageService();
  static const schemaVersion = 5;

  GamePackage createGamePackage({
    required String packageId,
    required String deviceId,
    required DateTime exportedAt,
    required Tournament tournament,
    required Game game,
    ScorerLog? log,
  }) {
    final snapshot = tournament.copyWith(
      games: [game.copyWith(logs: const [], clearOfficialLog: true)],
    );
    final payload = {
      'tournament': snapshot.toJson(),
      'gameId': game.id,
      'log': log?.toJson(),
    };
    return GamePackage(
      manifest: _manifest(packageId, 'game', deviceId, exportedAt, payload),
      tournament: snapshot,
      gameId: game.id,
      log: log,
    );
  }

  GamePackage decodeGamePackage(String source) {
    final root = (jsonDecode(source) as Map).cast<String, Object?>();
    final manifest = PackageManifest.fromJson(
      (root['manifest']! as Map).cast<String, Object?>(),
    );
    final payload = (root['payload']! as Map).cast<String, Object?>();
    _validate(manifest, payload, 'game');
    return GamePackage(
      manifest: manifest,
      tournament: Tournament.fromJson(
        (payload['tournament']! as Map).cast<String, Object?>(),
      ),
      gameId: payload['gameId']! as String,
      log: payload['log'] == null
          ? null
          : ScorerLog.fromJson(
              (payload['log']! as Map).cast<String, Object?>(),
            ),
    );
  }

  String createBackup({
    required String packageId,
    required AppData data,
    required DateTime exportedAt,
  }) {
    final payload = data.toJson();
    final root = {
      'manifest': _manifest(
        packageId,
        'backup',
        data.deviceId,
        exportedAt,
        payload,
      ).toJson(),
      'payload': payload,
    };
    return const JsonEncoder.withIndent('  ').convert(root);
  }

  AppData decodeBackup(String source) {
    final root = (jsonDecode(source) as Map).cast<String, Object?>();
    final manifest = PackageManifest.fromJson(
      (root['manifest']! as Map).cast<String, Object?>(),
    );
    final payload = (root['payload']! as Map).cast<String, Object?>();
    _validate(manifest, payload, 'backup');
    return AppData.fromJson(payload);
  }

  PackageManifest _manifest(
    String id,
    String type,
    String deviceId,
    DateTime exportedAt,
    Map<String, Object?> payload,
  ) => PackageManifest(
    schemaVersion: schemaVersion,
    packageId: id,
    type: type,
    sourceDeviceId: deviceId,
    exportedAt: exportedAt,
    payloadSha256: sha256.convert(utf8.encode(jsonEncode(payload))).toString(),
  );

  void _validate(
    PackageManifest manifest,
    Map<String, Object?> payload,
    String expectedType,
  ) {
    if (manifest.schemaVersion > schemaVersion) {
      throw const FormatException(
        'This package was created by a newer VC SETS version.',
      );
    }
    if (manifest.type != expectedType) {
      throw const FormatException('Unexpected package type.');
    }
    final digest = sha256.convert(utf8.encode(jsonEncode(payload))).toString();
    if (digest != manifest.payloadSha256) {
      throw const FormatException('Package integrity check failed.');
    }
  }
}
