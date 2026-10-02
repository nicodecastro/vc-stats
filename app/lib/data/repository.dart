import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'database.dart';

abstract interface class AppRepository {
  Future<AppData> load();
  Future<void> save(AppData data);
}

class DriftAppRepository implements AppRepository {
  DriftAppRepository(this.database);
  final AppDatabase database;

  @override
  Future<AppData> load() async {
    final source = await database.readState();
    if (source == null) {
      final data = AppData(deviceId: const Uuid().v4());
      await save(data);
      return data;
    }
    return AppData.decode(source);
  }

  @override
  Future<void> save(AppData data) => database.writeState(data.encode());
}

class MemoryAppRepository implements AppRepository {
  MemoryAppRepository([AppData? initial])
    : _data = initial ?? AppData(deviceId: const Uuid().v4());
  AppData _data;

  @override
  Future<AppData> load() async => _data;

  @override
  Future<void> save(AppData data) async => _data = data;
}
