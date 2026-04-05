enum FramePacing {
  displaySync('display_sync', 'Display Sync'),
  fps60('60', '60 FPS'),
  fps45('45', '45 FPS'),
  fps30('30', '30 FPS');

  const FramePacing(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static FramePacing fromStorage(String? value) {
    return FramePacing.values.firstWhere(
      (candidate) => candidate.storageValue == value,
      orElse: () => FramePacing.displaySync,
    );
  }
}

extension FramePacingX on FramePacing {
  Duration? get tickInterval {
    switch (this) {
      case FramePacing.displaySync:
        return null;
      case FramePacing.fps60:
        return const Duration(microseconds: 16667);
      case FramePacing.fps45:
        return const Duration(microseconds: 22222);
      case FramePacing.fps30:
        return const Duration(microseconds: 33333);
    }
  }
}

enum MemoryUsagePreset {
  unlimited('unlimited', 'Unlimited'),
  high('high', 'High'),
  medium('medium', 'Medium'),
  low('low', 'Low');

  const MemoryUsagePreset(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static MemoryUsagePreset fromStorage(String? value) {
    return MemoryUsagePreset.values.firstWhere(
      (candidate) => candidate.storageValue == value,
      orElse: () => MemoryUsagePreset.unlimited,
    );
  }
}

class LauncherSettings {
  const LauncherSettings({
    required this.forwardEngineLogs,
    required this.autoOpenConsole,
    required this.logRetention,
    required this.framePacing,
    required this.rememberLastImportPath,
    required this.lastImportDirectory,
    required this.defaultFontPath,
    required this.forceDefaultFont,
    required this.memoryUsage,
  });

  factory LauncherSettings.defaults() {
    return const LauncherSettings(
      forwardEngineLogs: true,
      autoOpenConsole: true,
      logRetention: 250,
      framePacing: FramePacing.displaySync,
      rememberLastImportPath: true,
      lastImportDirectory: null,
      defaultFontPath: '',
      forceDefaultFont: false,
      memoryUsage: MemoryUsagePreset.unlimited,
    );
  }

  factory LauncherSettings.fromJson(Map<String, dynamic> json) {
    final defaults = LauncherSettings.defaults();
    return LauncherSettings(
      forwardEngineLogs:
          json['forwardEngineLogs'] as bool? ?? defaults.forwardEngineLogs,
      autoOpenConsole:
          json['autoOpenConsole'] as bool? ?? defaults.autoOpenConsole,
      logRetention: _sanitizeLogRetention(
        json['logRetention'] as int? ?? defaults.logRetention,
      ),
      framePacing: FramePacing.fromStorage(json['framePacing'] as String?),
      rememberLastImportPath:
          json['rememberLastImportPath'] as bool? ??
          defaults.rememberLastImportPath,
      lastImportDirectory: json['lastImportDirectory'] as String?,
      defaultFontPath: json['defaultFontPath'] as String? ?? '',
      forceDefaultFont:
          json['forceDefaultFont'] as bool? ?? defaults.forceDefaultFont,
      memoryUsage: MemoryUsagePreset.fromStorage(
        json['memoryUsage'] as String?,
      ),
    );
  }

  final bool forwardEngineLogs;
  final bool autoOpenConsole;
  final int logRetention;
  final FramePacing framePacing;
  final bool rememberLastImportPath;
  final String? lastImportDirectory;
  final String defaultFontPath;
  final bool forceDefaultFont;
  final MemoryUsagePreset memoryUsage;

  LauncherSettings copyWith({
    bool? forwardEngineLogs,
    bool? autoOpenConsole,
    int? logRetention,
    FramePacing? framePacing,
    bool? rememberLastImportPath,
    String? lastImportDirectory,
    bool clearLastImportDirectory = false,
    String? defaultFontPath,
    bool? forceDefaultFont,
    MemoryUsagePreset? memoryUsage,
  }) {
    return LauncherSettings(
      forwardEngineLogs: forwardEngineLogs ?? this.forwardEngineLogs,
      autoOpenConsole: autoOpenConsole ?? this.autoOpenConsole,
      logRetention: _sanitizeLogRetention(logRetention ?? this.logRetention),
      framePacing: framePacing ?? this.framePacing,
      rememberLastImportPath:
          rememberLastImportPath ?? this.rememberLastImportPath,
      lastImportDirectory: clearLastImportDirectory
          ? null
          : (lastImportDirectory ?? this.lastImportDirectory),
      defaultFontPath: defaultFontPath ?? this.defaultFontPath,
      forceDefaultFont: forceDefaultFont ?? this.forceDefaultFont,
      memoryUsage: memoryUsage ?? this.memoryUsage,
    );
  }

  Map<String, dynamic> toJson() => {
    'forwardEngineLogs': forwardEngineLogs,
    'autoOpenConsole': autoOpenConsole,
    'logRetention': _sanitizeLogRetention(logRetention),
    'framePacing': framePacing.storageValue,
    'rememberLastImportPath': rememberLastImportPath,
    'lastImportDirectory': lastImportDirectory,
    'defaultFontPath': defaultFontPath,
    'forceDefaultFont': forceDefaultFont,
    'memoryUsage': memoryUsage.storageValue,
  };

  Map<String, String> toEngineGlobalOptions() {
    final options = <String, String>{
      'outputlog': forwardEngineLogs ? '1' : '0',
      'force_default_font': forceDefaultFont ? '1' : '0',
      'memusage': memoryUsage.storageValue,
    };
    final trimmedFont = defaultFontPath.trim();
    if (trimmedFont.isNotEmpty) {
      options['default_font'] = trimmedFont;
    }
    if (framePacing != FramePacing.displaySync) {
      options['fps_limit'] = framePacing.storageValue;
    }
    return options;
  }

  static int _sanitizeLogRetention(int value) {
    if (value < 50) {
      return 50;
    }
    if (value > 2000) {
      return 2000;
    }
    return value;
  }
}
