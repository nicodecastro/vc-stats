import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vc_sets/application/providers.dart';
import 'package:vc_sets/data/repository.dart';
import 'package:vc_sets/domain/models.dart';
import 'package:vc_sets/presentation/app.dart';

void main() {
  testWidgets('dashboard renders at phone and desktop widths', (tester) async {
    const data = AppData(deviceId: 'test-device');
    final repository = MemoryAppRepository(data);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRepositoryProvider.overrideWithValue(repository),
          initialAppDataProvider.overrideWithValue(data),
        ],
        child: VcSetsApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Match day, under control'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
