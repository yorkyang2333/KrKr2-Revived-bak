import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/game_library_repository.dart';
import '../data/launcher_settings_repository.dart';
import '../models/launcher_settings.dart';
import 'game_details_view.dart';
import 'game_profile.dart';
import 'settings_view.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key, required this.onGameSelected});

  final ValueChanged<GameProfile> onGameSelected;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final GameLibraryRepository _libraryRepository = GameLibraryRepository();
  final LauncherSettingsRepository _settingsRepository =
      LauncherSettingsRepository();

  List<GameProfile> _games = <GameProfile>[];

  @override
  void initState() {
    super.initState();
    _loadSavedGames();
  }

  Future<void> _loadSavedGames() async {
    final profiles = await _libraryRepository.loadProfiles();
    if (!mounted) {
      return;
    }
    setState(() {
      _games = profiles;
    });
  }

  Future<void> _saveGames() async {
    await _libraryRepository.saveProfiles(_games);
  }

  Future<void> _addGame() async {
    try {
      final LauncherSettings settings = await _settingsRepository.load();
      final String? selectedPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select KrKr2 Game Directory',
        initialDirectory: settings.rememberLastImportPath
            ? settings.lastImportDirectory
            : null,
      );

      if (selectedPath == null) {
        return;
      }

      final exists = _games.any((game) => game.path == selectedPath);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('That game directory is already in your library.'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _games = <GameProfile>[
            ..._games,
            GameProfile(
              path: selectedPath,
              name: selectedPath.split(Platform.pathSeparator).last,
            ),
          ];
        });
      }
      await _saveGames();

      if (settings.rememberLastImportPath) {
        await _settingsRepository.save(
          settings.copyWith(lastImportDirectory: selectedPath),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick game: $error')));
    }
  }

  Future<void> _removeGame(int index) async {
    setState(() {
      _games.removeAt(index);
    });
    await _saveGames();
  }

  void _confirmRemove(int index) {
    showDialog<void>(
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
              _removeGame(index);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsView(
          libraryCount: _games.length,
          onLibraryChanged: _loadSavedGames,
        ),
      ),
    );
  }

  void _updateProfile(int index, GameProfile updated) {
    setState(() {
      _games[index] = updated;
    });
    _saveGames();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            title: Text(
              'KrKr2 Revived',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
              ),
            ),
            centerTitle: false,
            surfaceTintColor: colorScheme.surfaceTint,
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: _openSettings,
                ),
              ),
            ],
          ),
          if (_games.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.videogame_asset_off_rounded,
                      size: 100,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No games installed',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap the + button to add a game directory',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 2 / 3,
                ),
                delegate: SliverChildBuilderDelegate((
                  BuildContext context,
                  int index,
                ) {
                  final GameProfile profile = _games[index];

                  Widget coverWidget;
                  if (profile.coverLocalPath != null) {
                    coverWidget = Image.file(
                      File(profile.coverLocalPath!),
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) => const Center(
                            child: Icon(Icons.broken_image, size: 64),
                          ),
                    );
                  } else if (profile.coverUrl != null) {
                    coverWidget = Image.network(
                      profile.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) => const Center(
                            child: Icon(Icons.broken_image, size: 64),
                          ),
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
                          Icons.sports_esports,
                          size: 64,
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    );
                  }

                  return Card(
                    elevation: 4,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: GestureDetector(
                      onSecondaryTapDown: (TapDownDetails details) {
                        showMenu<String>(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                          ),
                          items: <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'remove',
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.delete_forever,
                                    color: colorScheme.error,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Remove from Library',
                                    style: TextStyle(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ).then((String? value) {
                          if (value == 'remove') {
                            _confirmRemove(index);
                          }
                        });
                      },
                      onLongPress: () => _confirmRemove(index),
                      child: InkWell(
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GameDetailsView(
                                profile: profile,
                                onUpdate: (GameProfile updated) =>
                                    _updateProfile(index, updated),
                                onDelete: () => _removeGame(index),
                                onPlay: widget.onGameSelected,
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            coverWidget,
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: <Color>[
                                      Colors.black87,
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 12,
                                ),
                                child: Text(
                                  profile.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: _games.length),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGame,
        child: const Icon(Icons.add),
      ),
    );
  }
}
