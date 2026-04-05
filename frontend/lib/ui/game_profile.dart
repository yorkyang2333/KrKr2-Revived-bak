import '../models/launcher_settings.dart';

enum TriStateOverride {
  inherit('inherit', 'Inherit'),
  enabled('enabled', 'Enabled'),
  disabled('disabled', 'Disabled');

  const TriStateOverride(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static TriStateOverride fromNullableBool(bool? value) {
    if (value == null) {
      return TriStateOverride.inherit;
    }
    return value ? TriStateOverride.enabled : TriStateOverride.disabled;
  }

  static TriStateOverride fromStorage(String? value) {
    return TriStateOverride.values.firstWhere(
      (candidate) => candidate.storageValue == value,
      orElse: () => TriStateOverride.inherit,
    );
  }
}

extension TriStateOverrideX on TriStateOverride {
  bool? get nullableBool {
    switch (this) {
      case TriStateOverride.inherit:
        return null;
      case TriStateOverride.enabled:
        return true;
      case TriStateOverride.disabled:
        return false;
    }
  }
}

class GameCompatibilityOverrides {
  GameCompatibilityOverrides({
    this.defaultFontPath,
    this.forceDefaultFont,
    this.memoryUsage,
    this.framePacing,
  });

  factory GameCompatibilityOverrides.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return GameCompatibilityOverrides();
    }
    return GameCompatibilityOverrides(
      defaultFontPath: json['defaultFontPath'] as String?,
      forceDefaultFont: json['forceDefaultFont'] as bool?,
      memoryUsage: json['memoryUsage'] == null
          ? null
          : MemoryUsagePreset.fromStorage(json['memoryUsage'] as String?),
      framePacing: json['framePacing'] == null
          ? null
          : FramePacing.fromStorage(json['framePacing'] as String?),
    );
  }

  String? defaultFontPath;
  bool? forceDefaultFont;
  MemoryUsagePreset? memoryUsage;
  FramePacing? framePacing;

  GameCompatibilityOverrides copy() {
    return GameCompatibilityOverrides(
      defaultFontPath: defaultFontPath,
      forceDefaultFont: forceDefaultFont,
      memoryUsage: memoryUsage,
      framePacing: framePacing,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultFontPath': defaultFontPath,
    'forceDefaultFont': forceDefaultFont,
    'memoryUsage': memoryUsage?.storageValue,
    'framePacing': framePacing?.storageValue,
  };

  Map<String, String> toEngineOptionMap() {
    final options = <String, String>{};
    final trimmedFont = defaultFontPath?.trim() ?? '';
    if (trimmedFont.isNotEmpty) {
      options['default_font'] = trimmedFont;
    }
    if (forceDefaultFont != null) {
      options['force_default_font'] = forceDefaultFont! ? '1' : '0';
    }
    if (memoryUsage != null) {
      options['memusage'] = memoryUsage!.storageValue;
    }
    if (framePacing != null && framePacing != FramePacing.displaySync) {
      options['fps_limit'] = framePacing!.storageValue;
    }
    return options;
  }
}

class GameProfile {
  GameProfile({
    required this.path,
    required this.name,
    this.coverUrl,
    this.coverLocalPath,
    GameCompatibilityOverrides? compatibilityOverrides,
    List<String>? launchOptions,
    this.notes,
  }) : compatibilityOverrides =
           compatibilityOverrides ?? GameCompatibilityOverrides(),
       launchOptions = launchOptions ?? <String>[];

  factory GameProfile.fromJson(Map<String, dynamic> json) => GameProfile(
    path: json['path'] as String,
    name: json['name'] as String,
    coverUrl: json['coverUrl'] as String?,
    coverLocalPath: json['coverLocalPath'] as String?,
    compatibilityOverrides: GameCompatibilityOverrides.fromJson(
      json['compatibilityOverrides'] as Map<String, dynamic>?,
    ),
    launchOptions: _parseLaunchOptions(json['launchOptions']),
    notes: json['notes'] as String?,
  );

  String path;
  String name;
  String? coverUrl;
  String? coverLocalPath;
  GameCompatibilityOverrides compatibilityOverrides;
  List<String> launchOptions;
  String? notes;

  GameProfile copy() => GameProfile.fromJson(toJson());

  FramePacing resolveFramePacing(LauncherSettings settings) {
    return compatibilityOverrides.framePacing ?? settings.framePacing;
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'coverUrl': coverUrl,
    'coverLocalPath': coverLocalPath,
    'compatibilityOverrides': compatibilityOverrides.toJson(),
    'launchOptions': launchOptions,
    'notes': notes,
  };

  static List<String> _parseLaunchOptions(dynamic raw) {
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return raw
          .split('\n')
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    return <String>[];
  }
}
