import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_metadata_repository.dart';
import '../data/game_library_repository.dart';
import '../data/launcher_settings_repository.dart';
import '../models/launcher_settings.dart';
import 'theme.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.libraryCount,
    this.onLibraryChanged,
  });

  final int libraryCount;
  final Future<void> Function()? onLibraryChanged;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final LauncherSettingsRepository _settingsRepository =
      LauncherSettingsRepository();
  final GameLibraryRepository _libraryRepository = GameLibraryRepository();
  final AppMetadataRepository _metadataRepository = AppMetadataRepository();

  LauncherSettings? _settings;
  AppMetadata? _metadata;
  int _libraryCount = 0;
  int _selectedSectionIndex = 0;
  String _appSupportPath = '';
  String _coversPath = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _libraryCount = widget.libraryCount;
    _load();
  }

  Future<void> _load() async {
    final LauncherSettings settings = await _settingsRepository.load();
    final AppMetadata metadata = await _metadataRepository.load();
    final Directory appSupportDir = await getApplicationSupportDirectory();

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = settings;
      _metadata = metadata;
      _appSupportPath = appSupportDir.path;
      _coversPath = '${appSupportDir.path}/covers';
    });
  }

  Future<void> _saveSettings(LauncherSettings next) async {
    setState(() {
      _settings = next;
    });
    await _settingsRepository.save(next);
  }

  Future<void> _pickGlobalFont() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: 'Select Global Default Font',
      type: FileType.custom,
      allowedExtensions: const <String>['ttf', 'ttc', 'otf', 'otc'],
    );
    final String? path = result?.files.single.path;
    if (path == null || _settings == null) {
      return;
    }
    await _saveSettings(_settings!.copyWith(defaultFontPath: path));
  }

  Future<void> _clearLibrary() async {
    final bool confirmed = await _confirmAction(
      title: 'Clear Game Library?',
      message:
          'This removes all imported game entries from the launcher. Local game files will not be deleted.',
      actionLabel: 'Clear Library',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }

    setState(() {
      _busy = true;
    });
    await _libraryRepository.clearLibrary();
    await widget.onLibraryChanged?.call();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _libraryCount = 0;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Game library cleared.')));
  }

  Future<void> _clearCoverCache() async {
    final bool confirmed = await _confirmAction(
      title: 'Clear Cover Cache?',
      message:
          'This removes locally cached cover art and resets saved local cover paths.',
      actionLabel: 'Clear Cache',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }

    setState(() {
      _busy = true;
    });
    final int affectedProfiles = await _libraryRepository.clearCoverCache();
    await widget.onLibraryChanged?.call();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cover cache cleared for $affectedProfiles game(s).'),
      ),
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final LauncherSettings? settings = _settings;
    final AppMetadata? metadata = _metadata;

    if (settings == null || metadata == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SettingsDashboard(
          data: SettingsDashboardData(
            settings: settings,
            metadata: metadata,
            libraryCount: _libraryCount,
            appSupportPath: _appSupportPath,
            coversPath: _coversPath,
          ),
          selectedSectionIndex: _selectedSectionIndex,
          onBack: () => Navigator.pop(context),
          onSectionSelected: (int index) {
            setState(() {
              _selectedSectionIndex = index;
            });
          },
          onUpdateSettings: _saveSettings,
          onPickGlobalFont: _pickGlobalFont,
          onClearLibrary: _clearLibrary,
          onClearCoverCache: _clearCoverCache,
          busy: _busy,
        ),
      ),
    );
  }
}

class SettingsDashboardData {
  const SettingsDashboardData({
    required this.settings,
    required this.metadata,
    required this.libraryCount,
    required this.appSupportPath,
    required this.coversPath,
  });

  final LauncherSettings settings;
  final AppMetadata metadata;
  final int libraryCount;
  final String appSupportPath;
  final String coversPath;
}

class CapabilityStatus {
  const CapabilityStatus({
    required this.keyName,
    required this.title,
    required this.summary,
    required this.available,
    required this.icon,
  });

  final String keyName;
  final String title;
  final String summary;
  final bool available;
  final IconData icon;
}

class SettingsDashboard extends StatelessWidget {
  const SettingsDashboard({
    super.key,
    required this.data,
    required this.selectedSectionIndex,
    required this.onBack,
    required this.onSectionSelected,
    required this.onUpdateSettings,
    required this.onPickGlobalFont,
    required this.onClearLibrary,
    required this.onClearCoverCache,
    required this.busy,
  });

  final SettingsDashboardData data;
  final int selectedSectionIndex;
  final VoidCallback onBack;
  final ValueChanged<int> onSectionSelected;
  final Future<void> Function(LauncherSettings settings) onUpdateSettings;
  final Future<void> Function() onPickGlobalFont;
  final Future<void> Function() onClearLibrary;
  final Future<void> Function() onClearCoverCache;
  final bool busy;

  static const List<int> _retentionOptions = <int>[100, 250, 500, 1000];

  List<_SectionConfig> get _sections => const <_SectionConfig>[
    _SectionConfig(
      title: 'Launcher & Library',
      subtitle: 'Import history, library management, and cached media.',
      icon: Icons.library_books_outlined,
    ),
    _SectionConfig(
      title: 'Runtime & Console',
      subtitle: 'Log forwarding, console behavior, and frame pacing.',
      icon: Icons.terminal_outlined,
    ),
    _SectionConfig(
      title: 'Compatibility Defaults',
      subtitle: 'Default font and memory tuning for KrKr2 compatibility.',
      icon: Icons.tune_outlined,
    ),
    _SectionConfig(
      title: 'Storage & Data',
      subtitle: 'Where launcher metadata and engine-side data land.',
      icon: Icons.storage_outlined,
    ),
    _SectionConfig(
      title: 'About & Capability',
      subtitle: 'Build info and what the current bridge can actually do.',
      icon: Icons.info_outline,
    ),
  ];

  List<CapabilityStatus> get _capabilities => const <CapabilityStatus>[
    CapabilityStatus(
      keyName: 'capability-headless-option-bridge',
      title: 'Per-game option bridge',
      summary:
          'Global settings and game overrides are injected before engine startup.',
      available: true,
      icon: Icons.check_circle_outline,
    ),
    CapabilityStatus(
      keyName: 'capability-log-forwarding',
      title: 'Headless log forwarding',
      summary:
          'Native log callbacks stream into Flutter and obey retention limits.',
      available: true,
      icon: Icons.receipt_long_outlined,
    ),
    CapabilityStatus(
      keyName: 'capability-plugin-loading',
      title: 'Plugin loading',
      summary:
          'Unavailable for now. Headless bridge still stubs plugin loading.',
      available: false,
      icon: Icons.extension_off_outlined,
    ),
    CapabilityStatus(
      keyName: 'capability-input-injection',
      title: 'Input bridge',
      summary:
          'Pending. Mouse, key, and touch forwarding stubs still need engine routing.',
      available: false,
      icon: Icons.input_outlined,
    ),
    CapabilityStatus(
      keyName: 'capability-registry',
      title: 'Registry editing',
      summary:
          'Read and write emulation is not wired up as a user-facing editor yet.',
      available: false,
      icon: Icons.inventory_2_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 1080;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerLowest,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: wide
              ? _buildWideLayout(context)
              : _buildCompactLayout(context),
        );
      },
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      key: const ValueKey<String>('settings-wide-shell'),
      children: <Widget>[
        Container(
          width: 296,
          padding: const EdgeInsets.fromLTRB(24, 24, 20, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest.withValues(
              alpha: 0.92,
            ),
            border: Border(
              right: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton.filledTonal(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(height: 24),
              Text(
                'Simulator Settings',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'KrKr2 runtime defaults, launcher storage, and bridge diagnostics.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              for (int index = 0; index < _sections.length; index += 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _NavigationButton(
                    config: _sections[index],
                    selected: selectedSectionIndex == index,
                    onTap: () => onSectionSelected(index),
                  ),
                ),
              const Spacer(),
              _HeaderSignal(
                label: 'Library',
                value: '${data.libraryCount} game(s)',
              ),
              const SizedBox(height: 12),
              _HeaderSignal(
                label: 'Frame Pacing',
                value: data.settings.framePacing.label,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 32, 36, 32),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildSectionContent(
                context,
                selectedSectionIndex,
                key: ValueKey<int>(selectedSectionIndex),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      key: const ValueKey<String>('settings-mobile-shell'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton.filledTonal(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Simulator Settings',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Global launcher state and KrKr2 compatibility defaults.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (int index = 0; index < _sections.length; index += 1) ...<Widget>[
          _buildSectionContent(context, index),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildSectionContent(
    BuildContext context,
    int sectionIndex, {
    Key? key,
  }) {
    final _SectionConfig section = _sections[sectionIndex];
    switch (sectionIndex) {
      case 0:
        return _SectionShell(
          key: key,
          config: section,
          children: <Widget>[
            _SettingSurface(
              title: 'Import behavior',
              subtitle:
                  'Keep launcher-side memory of the last imported game directory.',
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Remember last import directory'),
                subtitle: Text(
                  data.settings.rememberLastImportPath
                      ? 'New imports reopen from the most recent game path.'
                      : 'The picker opens without a stored starting directory.',
                ),
                value: data.settings.rememberLastImportPath,
                onChanged: (bool enabled) {
                  final LauncherSettings next = enabled
                      ? data.settings.copyWith(rememberLastImportPath: true)
                      : data.settings.copyWith(
                          rememberLastImportPath: false,
                          clearLastImportDirectory: true,
                        );
                  onUpdateSettings(next);
                },
              ),
            ),
            _MonoInfoCard(
              title: 'Last imported directory',
              value: data.settings.lastImportDirectory ?? 'Not recorded yet',
            ),
            _adaptivePair(
              context,
              first: _StatCard(
                label: 'Library Size',
                value: '${data.libraryCount}',
                helper: 'tracked game(s)',
              ),
              second: _StatCard(
                label: 'Cover Cache',
                value: data.coversPath.split(Platform.pathSeparator).last,
                helper: 'support folder',
              ),
            ),
            _ActionSurface(
              title: 'Game library maintenance',
              subtitle: 'Library removal only affects launcher metadata.',
              primaryLabel: busy ? 'Working…' : 'Clear Game Library',
              secondaryLabel: busy ? 'Working…' : 'Clear Cover Cache',
              onPrimaryPressed: busy ? null : onClearLibrary,
              onSecondaryPressed: busy ? null : onClearCoverCache,
              destructivePrimary: true,
            ),
          ],
        );
      case 1:
        return _SectionShell(
          key: key,
          config: section,
          children: <Widget>[
            _SettingSurface(
              title: 'Console bridge',
              subtitle:
                  'Decide whether native headless logs are forwarded into Flutter.',
              child: Column(
                children: <Widget>[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Forward engine logs to Flutter'),
                    subtitle: const Text(
                      'Disabling this keeps the console viewport silent even if the engine emits logs.',
                    ),
                    value: data.settings.forwardEngineLogs,
                    onChanged: (bool enabled) {
                      onUpdateSettings(
                        data.settings.copyWith(forwardEngineLogs: enabled),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Auto-open console when launching a game',
                    ),
                    subtitle: const Text(
                      'Useful while compatibility work is still in progress.',
                    ),
                    value: data.settings.autoOpenConsole,
                    onChanged: (bool enabled) {
                      onUpdateSettings(
                        data.settings.copyWith(autoOpenConsole: enabled),
                      );
                    },
                  ),
                ],
              ),
            ),
            _adaptivePair(
              context,
              first: _SettingSurface(
                title: 'Frame pacing',
                subtitle: 'Display Sync uses Flutter display refresh directly.',
                child: DropdownButtonFormField<FramePacing>(
                  initialValue: data.settings.framePacing,
                  isExpanded: true,
                  items: FramePacing.values
                      .map(
                        (FramePacing pacing) => DropdownMenuItem<FramePacing>(
                          value: pacing,
                          child: Text(
                            pacing.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (FramePacing? pacing) {
                    if (pacing == null) {
                      return;
                    }
                    onUpdateSettings(
                      data.settings.copyWith(framePacing: pacing),
                    );
                  },
                ),
              ),
              second: _SettingSurface(
                title: 'Log retention',
                subtitle:
                    'Older lines are trimmed when the console exceeds this cap.',
                child: DropdownButtonFormField<int>(
                  initialValue: data.settings.logRetention,
                  isExpanded: true,
                  items: _retentionOptions
                      .map(
                        (int value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(
                            '$value lines',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) {
                    if (value == null) {
                      return;
                    }
                    onUpdateSettings(
                      data.settings.copyWith(logRetention: value),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      case 2:
        return _SectionShell(
          key: key,
          config: section,
          children: <Widget>[
            _SettingSurface(
              title: 'Default font fallback',
              subtitle:
                  'Applied before a game-specific override, then passed into the headless option bridge.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _MonoInfoCard(
                    title: 'Font path',
                    value: data.settings.defaultFontPath.isEmpty
                        ? 'Use engine default'
                        : data.settings.defaultFontPath,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: onPickGlobalFont,
                        icon: const Icon(Icons.font_download_outlined),
                        label: const Text('Pick Font'),
                      ),
                      OutlinedButton.icon(
                        onPressed: data.settings.defaultFontPath.isEmpty
                            ? null
                            : () {
                                onUpdateSettings(
                                  data.settings.copyWith(defaultFontPath: ''),
                                );
                              },
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Use Engine Default'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _adaptivePair(
              context,
              first: _SettingSurface(
                title: 'Force default font',
                subtitle:
                    'When enabled, KrKr2 skips original in-script font fallback and uses the configured default font first.',
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable forced default font'),
                  value: data.settings.forceDefaultFont,
                  onChanged: (bool enabled) {
                    onUpdateSettings(
                      data.settings.copyWith(forceDefaultFont: enabled),
                    );
                  },
                ),
              ),
              second: _SettingSurface(
                title: 'Memory usage preset',
                subtitle:
                    'Matches the old Kirikiroid-style low/high/unlimited presets.',
                child: DropdownButtonFormField<MemoryUsagePreset>(
                  initialValue: data.settings.memoryUsage,
                  isExpanded: true,
                  items: MemoryUsagePreset.values
                      .map(
                        (MemoryUsagePreset preset) =>
                            DropdownMenuItem<MemoryUsagePreset>(
                              value: preset,
                              child: Text(
                                preset.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      )
                      .toList(),
                  onChanged: (MemoryUsagePreset? preset) {
                    if (preset == null) {
                      return;
                    }
                    onUpdateSettings(
                      data.settings.copyWith(memoryUsage: preset),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      case 3:
        return _SectionShell(
          key: key,
          config: section,
          children: <Widget>[
            _MonoInfoCard(
              title: 'Application Support',
              value: data.appSupportPath,
            ),
            _MonoInfoCard(title: 'Cover cache folder', value: data.coversPath),
            const _MonoInfoCard(
              title: 'Launcher settings storage',
              value: 'SharedPreferences / launcher_settings_v1',
            ),
            const _MonoInfoCard(
              title: 'KrKr2 savedata rule',
              value: '<game directory>/savedata/',
            ),
            _StatusSurface(
              title: 'Registry emulation',
              summary:
                  'Engine-side registry emulation exists internally, but reading, writing, and editing it are not exposed in the launcher yet.',
              available: false,
            ),
          ],
        );
      case 4:
        return _SectionShell(
          key: key,
          config: section,
          children: <Widget>[
            _adaptivePair(
              context,
              first: _StatCard(
                label: 'Version',
                value: data.metadata.version,
                helper:
                    'pubspec build ${data.metadata.buildNumber.isEmpty ? 'n/a' : data.metadata.buildNumber}',
              ),
              second: _StatCard(
                label: 'Platform',
                value: Platform.operatingSystem,
                helper: Platform.operatingSystemVersion,
              ),
            ),
            for (final CapabilityStatus capability in _capabilities)
              _CapabilityCard(capability: capability),
          ],
        );
      default:
        return const SizedBox.shrink(key: ValueKey<String>('settings-empty'));
    }
  }

  Widget _adaptivePair(
    BuildContext context, {
    required Widget first,
    required Widget second,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: <Widget>[first, const SizedBox(height: 16), second],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _SectionConfig {
  const _SectionConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    super.key,
    required this.config,
    required this.children,
  });

  final _SectionConfig config;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          config.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          config.subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        ...children.expand(
          (Widget child) => <Widget>[child, const SizedBox(height: 16)],
        ),
      ],
    );
  }
}

class _SettingSurface extends StatelessWidget {
  const _SettingSurface({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MonoInfoCard extends StatelessWidget {
  const _MonoInfoCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            value,
            style: AppTheme.mono(
              context,
              color: theme.colorScheme.onSurface,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSurface extends StatelessWidget {
  const _ActionSurface({
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
    this.destructivePrimary = false,
  });

  final String title;
  final String subtitle;
  final String primaryLabel;
  final String secondaryLabel;
  final Future<void> Function()? onPrimaryPressed;
  final Future<void> Function()? onSecondaryPressed;
  final bool destructivePrimary;

  @override
  Widget build(BuildContext context) {
    return _SettingSurface(
      title: title,
      subtitle: subtitle,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          FilledButton.icon(
            onPressed: onPrimaryPressed == null
                ? null
                : () => onPrimaryPressed!(),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(primaryLabel),
          ),
          OutlinedButton.icon(
            onPressed: onSecondaryPressed == null
                ? null
                : () => onSecondaryPressed!(),
            icon: const Icon(Icons.layers_clear_outlined),
            label: Text(secondaryLabel),
          ),
        ],
      ),
    );
  }
}

class _StatusSurface extends StatelessWidget {
  const _StatusSurface({
    required this.title,
    required this.summary,
    required this.available,
  });

  final String title;
  final String summary;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            available ? Icons.check_circle_outline : Icons.schedule_outlined,
            color: available
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTheme.mono(
              context,
              color: theme.colorScheme.onSurface,
              fontSize: 16,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capability});

  final CapabilityStatus capability;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = capability.available
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return Container(
      key: ValueKey<String>(capability.keyName),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(capability.icon, color: accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        capability.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        capability.available ? 'Active' : 'Pending',
                        style: AppTheme.mono(
                          context,
                          color: accent,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  capability.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.config,
    required this.selected,
    required this.onTap,
  });

  final _SectionConfig config;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.72)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              config.icon,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                config.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSignal extends StatelessWidget {
  const _HeaderSignal({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTheme.mono(
            context,
            color: theme.colorScheme.onSurface,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
