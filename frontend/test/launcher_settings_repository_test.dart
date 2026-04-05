import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/data/launcher_settings_repository.dart';
import 'package:frontend/models/launcher_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LauncherSettingsRepository', () {
    test('loads defaults when no persisted payload exists', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final LauncherSettingsRepository repository =
          LauncherSettingsRepository();
      final LauncherSettings settings = await repository.load();

      expect(settings.forwardEngineLogs, isTrue);
      expect(settings.autoOpenConsole, isTrue);
      expect(settings.framePacing, FramePacing.displaySync);
      expect(settings.memoryUsage, MemoryUsagePreset.unlimited);
    });

    test('round-trips launcher_settings_v1', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final LauncherSettingsRepository repository =
          LauncherSettingsRepository();
      final LauncherSettings original = LauncherSettings.defaults().copyWith(
        forwardEngineLogs: false,
        autoOpenConsole: false,
        logRetention: 500,
        framePacing: FramePacing.fps45,
        rememberLastImportPath: true,
        lastImportDirectory: '/games/krkr2',
        defaultFontPath: '/fonts/fallback.ttf',
        forceDefaultFont: true,
        memoryUsage: MemoryUsagePreset.medium,
      );

      await repository.save(original);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> raw =
          jsonDecode(
                prefs.getString(
                  LauncherSettingsRepository.launcherSettingsKey,
                )!,
              )
              as Map<String, dynamic>;
      final LauncherSettings loaded = await repository.load();

      expect(raw['framePacing'], '45');
      expect(raw['defaultFontPath'], '/fonts/fallback.ttf');
      expect(loaded.forwardEngineLogs, isFalse);
      expect(loaded.logRetention, 500);
      expect(loaded.framePacing, FramePacing.fps45);
      expect(loaded.lastImportDirectory, '/games/krkr2');
      expect(loaded.forceDefaultFont, isTrue);
      expect(loaded.memoryUsage, MemoryUsagePreset.medium);
    });
  });
}
