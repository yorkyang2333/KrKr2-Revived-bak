import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/game_profile.dart';

class GameLibraryRepository {
  static const String profilesKey = 'game_profiles_v2';
  static const String legacyPathsKey = 'game_paths';

  Future<List<GameProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGamesJson = prefs.getStringList(profilesKey);
    final appDir = await getApplicationSupportDirectory();

    if (savedGamesJson != null) {
      return savedGamesJson.map((entry) {
        final profile = GameProfile.fromJson(
          jsonDecode(entry) as Map<String, dynamic>,
        );
        if (profile.coverLocalPath != null &&
            profile.coverLocalPath!.contains('/Application Support/')) {
          final filename = profile.coverLocalPath!.split('/').last;
          profile.coverLocalPath = '${appDir.path}/covers/$filename';
        }
        return profile;
      }).toList();
    }

    final oldGames = prefs.getStringList(legacyPathsKey);
    if (oldGames == null || oldGames.isEmpty) {
      return <GameProfile>[];
    }

    final migrated = oldGames
        .map(
          (path) => GameProfile(
            path: path,
            name: path.split(Platform.pathSeparator).last,
          ),
        )
        .toList();
    await saveProfiles(migrated);
    return migrated;
  }

  Future<void> saveProfiles(List<GameProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = profiles
        .map((profile) => jsonEncode(profile.toJson()))
        .toList();
    await prefs.setStringList(profilesKey, jsonList);
  }

  Future<void> clearLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(profilesKey);
    await prefs.remove(legacyPathsKey);
  }

  Future<int> clearCoverCache() async {
    final profiles = await loadProfiles();
    int updatedProfiles = 0;
    for (final profile in profiles) {
      if (profile.coverLocalPath != null) {
        profile.coverLocalPath = null;
        updatedProfiles += 1;
      }
    }
    if (updatedProfiles > 0) {
      await saveProfiles(profiles);
    }

    final appDir = await getApplicationSupportDirectory();
    final coversDir = Directory('${appDir.path}/covers');
    if (await coversDir.exists()) {
      await coversDir.delete(recursive: true);
    }
    return updatedProfiles;
  }
}
