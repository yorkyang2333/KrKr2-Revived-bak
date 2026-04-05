import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/launcher_settings.dart';
import 'game_profile.dart';
import 'theme.dart';

class GameDetailsView extends StatefulWidget {
  const GameDetailsView({
    super.key,
    required this.profile,
    required this.onUpdate,
    required this.onDelete,
    required this.onPlay,
  });

  final GameProfile profile;
  final ValueChanged<GameProfile> onUpdate;
  final VoidCallback onDelete;
  final ValueChanged<GameProfile> onPlay;

  @override
  State<GameDetailsView> createState() => _GameDetailsViewState();
}

class _GameDetailsViewState extends State<GameDetailsView> {
  late GameProfile _profile;
  late TextEditingController _notesController;
  late TextEditingController _launchOptionsController;
  bool _isSearchingVNDB = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile.copy();
    _notesController = TextEditingController(text: _profile.notes ?? '');
    _launchOptionsController = TextEditingController(
      text: _profile.launchOptions.join('\n'),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _launchOptionsController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    widget.onUpdate(_profile.copy());
  }

  Future<void> _pickLocalCover() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      dialogTitle: 'Select Local Cover Image',
    );

    final String? originalPath = result?.files.single.path;
    if (originalPath == null) {
      return;
    }

    try {
      final Directory appDir = await getApplicationSupportDirectory();
      final Directory coversDir = Directory('${appDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final String extension = originalPath.split('.').last;
      final String safeName = _profile.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final String newPath = '${coversDir.path}/${safeName}_local.$extension';

      await File(originalPath).copy(newPath);

      setState(() {
        _profile.coverLocalPath = newPath;
        _profile.coverUrl = null;
      });
      _saveProfile();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save cover locally: $error')),
      );
    }
  }

  Future<void> _fetchVNDBCover() async {
    final TextEditingController searchController = TextEditingController(
      text: _profile.name,
    );

    final String? query = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Search VNDB'),
          content: TextField(
            controller: searchController,
            decoration: const InputDecoration(labelText: 'Visual Novel Title'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, searchController.text),
              child: const Text('Search'),
            ),
          ],
        );
      },
    );

    if (query == null || query.isEmpty) {
      return;
    }

    setState(() => _isSearchingVNDB = true);
    try {
      final response = await http.post(
        Uri.parse('https://api.vndb.org/kana/vn'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, Object>{
          'filters': <Object>['search', '=', query],
          'fields': 'title, image.url',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('VNDB request failed with ${response.statusCode}');
      }

      final Map<String, dynamic> payload =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> results = payload['results'] as List<dynamic>;
      if (results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No results found on VNDB.')),
          );
        }
        return;
      }

      if (!mounted) {
        return;
      }

      final String? selectedUrl = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Select Cover'),
          content: SizedBox(
            width: 520,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> vn =
                    results[index] as Map<String, dynamic>;
                final String? url =
                    (vn['image'] as Map<String, dynamic>?)?['url'] as String?;
                return ListTile(
                  leading: url != null
                      ? Image.network(
                          url,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.broken_image),
                  title: Text(vn['title'] as String? ?? 'Unknown'),
                  onTap: () => Navigator.pop(dialogContext, url),
                );
              },
            ),
          ),
        ),
      );

      if (selectedUrl == null) {
        return;
      }

      final http.Response imageResponse = await http.get(
        Uri.parse(selectedUrl),
      );
      if (imageResponse.statusCode != 200) {
        throw Exception('Failed to download cover from VNDB');
      }

      final Directory appDir = await getApplicationSupportDirectory();
      final Directory coversDir = Directory('${appDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final String extension = selectedUrl.split('.').last;
      final String safeName = _profile.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final File localFile = File(
        '${coversDir.path}/${safeName}_cover.$extension',
      );
      await localFile.writeAsBytes(imageResponse.bodyBytes);

      setState(() {
        _profile.coverLocalPath = localFile.path;
        _profile.coverUrl = null;
      });
      _saveProfile();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cover lookup failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingVNDB = false);
      }
    }
  }

  Future<void> _pickCompatibilityFont() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      dialogTitle: 'Select Override Font',
      type: FileType.custom,
      allowedExtensions: const <String>['ttf', 'ttc', 'otf', 'otc'],
    );
    final String? path = result?.files.single.path;
    if (path == null) {
      return;
    }

    setState(() {
      _profile.compatibilityOverrides.defaultFontPath = path;
    });
    _saveProfile();
  }

  void _updateMemoryUsage(MemoryUsagePreset? preset) {
    setState(() {
      _profile.compatibilityOverrides.memoryUsage = preset;
    });
    _saveProfile();
  }

  void _updateFramePacing(FramePacing? pacing) {
    setState(() {
      _profile.compatibilityOverrides.framePacing = pacing;
    });
    _saveProfile();
  }

  void _updateForceDefaultFont(TriStateOverride override) {
    setState(() {
      _profile.compatibilityOverrides.forceDefaultFont = override.nullableBool;
    });
    _saveProfile();
  }

  void _updateNotes(String value) {
    _profile.notes = value.trim().isEmpty ? null : value;
    _saveProfile();
  }

  void _updateLaunchOptions(String value) {
    _profile.launchOptions = value
        .split('\n')
        .map((String entry) => entry.trim())
        .where((String entry) => entry.isNotEmpty)
        .toList();
    _saveProfile();
  }

  Future<void> _confirmDelete() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Remove Game?'),
        content: const Text(
          'Are you sure you want to remove this game from the library?\nThis will not delete your local game files.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onDelete();
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktopPlatform = switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Game Details'), centerTitle: false),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double splitThreshold = isDesktopPlatform ? 720 : 980;
          final bool wide = constraints.maxWidth >= splitThreshold;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(width: 320, child: _buildCoverColumn(context)),
                      const SizedBox(width: 28),
                      Expanded(child: _buildDetailsColumn(context)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildCoverColumn(context),
                      const SizedBox(height: 24),
                      _buildDetailsColumn(context),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCoverColumn(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    Widget coverWidget;
    if (_profile.coverLocalPath != null) {
      coverWidget = Image.file(
        File(_profile.coverLocalPath!),
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                const Center(child: Icon(Icons.broken_image, size: 64)),
      );
    } else if (_profile.coverUrl != null) {
      coverWidget = Image.network(
        _profile.coverUrl!,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                const Center(child: Icon(Icons.broken_image, size: 64)),
      );
    } else {
      coverWidget = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.image_not_supported_rounded,
            size: 80,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Card(
          elevation: 8,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: AspectRatio(aspectRatio: 2 / 3, child: coverWidget),
        ),
        const SizedBox(height: 16),
        if (_isSearchingVNDB)
          const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              SizedBox(
                width: 170,
                height: 48,
                child: FilledButton.tonalIcon(
                  onPressed: _fetchVNDBCover,
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('VNDB Search'),
                ),
              ),
              SizedBox(
                width: 170,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _pickLocalCover,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Local Cover'),
                ),
              ),
              SizedBox(
                width: 170,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed:
                      (_profile.coverUrl == null &&
                          _profile.coverLocalPath == null)
                      ? null
                      : () {
                          setState(() {
                            _profile.coverUrl = null;
                            _profile.coverLocalPath = null;
                          });
                          _saveProfile();
                        },
                  icon: const Icon(Icons.hide_image_outlined),
                  label: const Text('Remove Cover'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDetailsColumn(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _profile.name,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        SelectableText(
          _profile.path,
          style: AppTheme.mono(
            context,
            color: colorScheme.onSurfaceVariant,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: <Widget>[
            SizedBox(
              width: 220,
              height: 48,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play'),
                onPressed: () => widget.onPlay(_profile.copy()),
              ),
            ),
            SizedBox(
              width: 220,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Remove from Library'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _panel(
          context,
          title: 'Compatibility Overrides',
          subtitle:
              'These settings override the global defaults for this game only.',
          child: Column(
            children: <Widget>[
              _infoRow(
                context,
                title: 'Default font override',
                value:
                    _profile.compatibilityOverrides.defaultFontPath ??
                    'Inherit global default',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  SizedBox(
                    width: 190,
                    height: 48,
                    child: FilledButton.tonalIcon(
                      onPressed: _pickCompatibilityFont,
                      icon: const Icon(Icons.font_download_outlined),
                      label: const Text('Pick Override Font'),
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed:
                          _profile.compatibilityOverrides.defaultFontPath ==
                              null
                          ? null
                          : () {
                              setState(() {
                                _profile
                                        .compatibilityOverrides
                                        .defaultFontPath =
                                    null;
                              });
                              _saveProfile();
                            },
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Inherit Global Font'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<MemoryUsagePreset?>(
                      initialValue: _profile.compatibilityOverrides.memoryUsage,
                      decoration: const InputDecoration(
                        labelText: 'Memory Usage',
                      ),
                      items: <DropdownMenuItem<MemoryUsagePreset?>>[
                        const DropdownMenuItem<MemoryUsagePreset?>(
                          value: null,
                          child: Text('Inherit global default'),
                        ),
                        ...MemoryUsagePreset.values.map(
                          (MemoryUsagePreset preset) =>
                              DropdownMenuItem<MemoryUsagePreset?>(
                                value: preset,
                                child: Text(preset.label),
                              ),
                        ),
                      ],
                      onChanged: _updateMemoryUsage,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<FramePacing?>(
                      initialValue: _profile.compatibilityOverrides.framePacing,
                      decoration: const InputDecoration(
                        labelText: 'Frame Pacing',
                      ),
                      items: <DropdownMenuItem<FramePacing?>>[
                        const DropdownMenuItem<FramePacing?>(
                          value: null,
                          child: Text('Inherit global default'),
                        ),
                        ...FramePacing.values.map(
                          (FramePacing pacing) =>
                              DropdownMenuItem<FramePacing?>(
                                value: pacing,
                                child: Text(pacing.label),
                              ),
                        ),
                      ],
                      onChanged: _updateFramePacing,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TriStateOverride>(
                initialValue: TriStateOverride.fromNullableBool(
                  _profile.compatibilityOverrides.forceDefaultFont,
                ),
                decoration: const InputDecoration(
                  labelText: 'Force Default Font',
                ),
                items: TriStateOverride.values
                    .map(
                      (TriStateOverride value) =>
                          DropdownMenuItem<TriStateOverride>(
                            value: value,
                            child: Text(value.label),
                          ),
                    )
                    .toList(),
                onChanged: (TriStateOverride? value) {
                  if (value != null) {
                    _updateForceDefaultFont(value);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _panel(
          context,
          title: 'Notes & Launch Options',
          subtitle:
              'Stored in the launcher for compatibility tracking. Launch options are kept locally for now.',
          child: Column(
            children: <Widget>[
              TextField(
                controller: _launchOptionsController,
                minLines: 3,
                maxLines: 5,
                style: AppTheme.mono(context, fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: 'Custom Launch Options',
                  hintText: '-debug\n-startup=first.ks',
                ),
                onChanged: _updateLaunchOptions,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Compatibility Notes',
                  hintText:
                      'Example: needs fallback font for CJK glyphs, runs better at 45 FPS pacing...',
                ),
                onChanged: _updateNotes,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _panel(
          context,
          title: 'Bridge Status',
          subtitle:
              'These emulator-facing controls are intentionally visible but not interactive yet.',
          child: Column(
            children: const <Widget>[
              _PendingStatusRow(
                title: 'Plugin loading',
                detail:
                    'Headless bridge still stubs plugin discovery and loading.',
              ),
              SizedBox(height: 12),
              _PendingStatusRow(
                title: 'Key mapping',
                detail:
                    'Custom key remapping is not exposed in the new Flutter shell yet.',
              ),
              SizedBox(height: 12),
              _PendingStatusRow(
                title: 'Window controls',
                detail:
                    'Fullscreen, cursor, IME, and advanced window hooks are pending.',
              ),
              SizedBox(height: 12),
              _PendingStatusRow(
                title: 'Input event bridge',
                detail:
                    'Mouse, keyboard, and touch callbacks still need engine routing in headless mode.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
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
            style: theme.textTheme.titleLarge?.copyWith(
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
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required String title,
    required String value,
  }) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
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

class _PendingStatusRow extends StatelessWidget {
  const _PendingStatusRow({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.hourglass_bottom_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
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
                  detail,
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
