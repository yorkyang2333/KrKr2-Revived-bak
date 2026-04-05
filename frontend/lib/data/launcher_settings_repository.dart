import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/launcher_settings.dart';

class LauncherSettingsRepository {
  static const String launcherSettingsKey = 'launcher_settings_v1';

  Future<LauncherSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(launcherSettingsKey);
    if (raw == null || raw.isEmpty) {
      return LauncherSettings.defaults();
    }

    try {
      return LauncherSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return LauncherSettings.defaults();
    }
  }

  Future<void> save(LauncherSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(launcherSettingsKey, jsonEncode(settings.toJson()));
  }
}
