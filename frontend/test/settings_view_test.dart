import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/data/app_metadata_repository.dart';
import 'package:frontend/models/launcher_settings.dart';
import 'package:frontend/ui/settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SettingsDashboardData buildData() {
    return SettingsDashboardData(
      settings: LauncherSettings.defaults(),
      metadata: const AppMetadata(version: '1.0.0', buildNumber: '1'),
      libraryCount: 3,
      appSupportPath: '/tmp/support',
      coversPath: '/tmp/support/covers',
    );
  }

  Future<void> pumpDashboard(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsDashboard(
            data: buildData(),
            selectedSectionIndex: 4,
            onBack: () {},
            onSectionSelected: (_) {},
            onUpdateSettings: (_) async {},
            onPickGlobalFont: () async {},
            onClearLibrary: () async {},
            onClearCoverCache: () async {},
            busy: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders wide navigation shell on desktop width', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, size: const Size(1440, 900));

    expect(
      find.byKey(const ValueKey<String>('settings-wide-shell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('capability-plugin-loading')),
      findsOneWidget,
    );
    expect(find.text('Pending'), findsWidgets);
  });

  testWidgets('renders all sections in compact mobile layout', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, size: const Size(390, 10000));

    expect(
      find.byKey(const ValueKey<String>('settings-mobile-shell')),
      findsOneWidget,
    );
    expect(find.text('Launcher & Library'), findsOneWidget);
    expect(find.text('Runtime & Console'), findsOneWidget);
    expect(find.text('Compatibility Defaults'), findsOneWidget);
    expect(find.text('Storage & Data'), findsOneWidget);
    expect(find.text('About & Capability'), findsOneWidget);
  });
}
