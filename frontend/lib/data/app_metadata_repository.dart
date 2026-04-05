import 'package:flutter/services.dart';

class AppMetadata {
  const AppMetadata({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  String get displayVersion =>
      buildNumber.isEmpty ? version : '$version+$buildNumber';
}

class AppMetadataRepository {
  Future<AppMetadata> load() async {
    try {
      final raw = await rootBundle.loadString('pubspec.yaml');
      final match = RegExp(
        r'^version:\s*([0-9A-Za-z.\-_]+)(?:\+([0-9A-Za-z.\-_]+))?$',
        multiLine: true,
      ).firstMatch(raw);
      if (match != null) {
        return AppMetadata(
          version: match.group(1) ?? '0.0.0',
          buildNumber: match.group(2) ?? '',
        );
      }
    } catch (_) {
      // Fall through to defaults.
    }

    return const AppMetadata(version: '0.0.0', buildNumber: '');
  }
}
