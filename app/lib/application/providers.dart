import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository.dart';
import '../domain/models.dart';
import 'app_controller.dart';

final appRepositoryProvider = Provider<AppRepository>(
  (ref) => throw StateError('AppRepository must be overridden at startup.'),
);

final initialAppDataProvider = Provider<AppData>(
  (ref) => throw StateError('Initial AppData must be overridden at startup.'),
);

final appControllerProvider = NotifierProvider<AppController, AppData>(
  AppController.new,
);
