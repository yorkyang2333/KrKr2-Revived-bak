import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/launcher_settings.dart';
import 'package:frontend/ui/game_profile.dart';

void main() {
  group('GameProfile', () {
    test('keeps backward compatibility with old saved JSON', () {
      final GameProfile profile = GameProfile.fromJson(<String, dynamic>{
        'path': '/games/sample',
        'name': 'Sample Game',
        'coverUrl': null,
        'coverLocalPath': null,
      });

      expect(profile.path, '/games/sample');
      expect(profile.compatibilityOverrides.defaultFontPath, isNull);
      expect(profile.compatibilityOverrides.forceDefaultFont, isNull);
      expect(profile.compatibilityOverrides.memoryUsage, isNull);
      expect(profile.compatibilityOverrides.framePacing, isNull);
      expect(profile.launchOptions, isEmpty);
      expect(profile.notes, isNull);
    });

    test('serializes compatibility overrides and resolves frame pacing', () {
      final GameProfile profile = GameProfile(
        path: '/games/sample',
        name: 'Sample Game',
        compatibilityOverrides: GameCompatibilityOverrides(
          defaultFontPath: '/fonts/override.ttf',
          forceDefaultFont: true,
          memoryUsage: MemoryUsagePreset.low,
          framePacing: FramePacing.fps30,
        ),
        launchOptions: const <String>['-debug', '-startup=first.ks'],
        notes: 'Needs fallback font.',
      );

      final Map<String, dynamic> json = profile.toJson();
      final GameProfile restored = GameProfile.fromJson(json);
      final LauncherSettings global = LauncherSettings.defaults().copyWith(
        framePacing: FramePacing.fps60,
      );

      expect(
        restored.compatibilityOverrides.toEngineOptionMap(),
        <String, String>{
          'default_font': '/fonts/override.ttf',
          'force_default_font': '1',
          'memusage': 'low',
          'fps_limit': '30',
        },
      );
      expect(restored.launchOptions, <String>['-debug', '-startup=first.ks']);
      expect(restored.resolveFramePacing(global), FramePacing.fps30);
    });
  });
}
