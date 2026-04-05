import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import 'settings_view.dart';
import 'game_details_view.dart';
import 'game_profile.dart';

class MainMenuScreen extends StatefulWidget {
  final Function(String) onGameSelected;

  const MainMenuScreen({super.key, required this.onGameSelected});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  List<GameProfile> _games = [];

  @override
  void initState() {
    super.initState();
    _loadSavedGames();
  }

  Future<void> _loadSavedGames() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedGamesJson = prefs.getStringList('game_profiles_v2');
    
    if (savedGamesJson != null) {
      final appDir = await getApplicationSupportDirectory();
      setState(() {
        _games = savedGamesJson.map((str) {
          final profile = GameProfile.fromJson(jsonDecode(str));
          // Sanitize old Bundle Identifier paths dynamically to prevent broken images across updates/renames
          if (profile.coverLocalPath != null && profile.coverLocalPath!.contains('/Application Support/')) {
            final filename = profile.coverLocalPath!.split('/').last;
            profile.coverLocalPath = '${appDir.path}/covers/$filename';
          }
          return profile;
        }).toList();
      });
    } else {
      // Migrate old string lists if any
      final oldGames = prefs.getStringList('game_paths');
      if (oldGames != null && oldGames.isNotEmpty) {
        setState(() {
          _games = oldGames.map((path) => GameProfile(path: path, name: path.split(Platform.pathSeparator).last)).toList();
        });
        _saveGames(); // Save as v2
      }
    }
  }

  Future<void> _saveGames() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _games.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('game_profiles_v2', jsonList);
  }

  Future<void> _addGame() async {
    try {
      String? selectedPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select KrKr2 Game Directory',
      );

      if (selectedPath != null) {
        // Find if exists
        bool exists = _games.any((g) => g.path == selectedPath);
        if (!exists) {
          setState(() {
             _games.add(GameProfile(
              path: selectedPath,
              name: selectedPath.split(Platform.pathSeparator).last,
            ));
          });
          await _saveGames();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick game: $e')),
        );
      }
    }
  }

  void _removeGame(int index) {
    setState(() {
      _games.removeAt(index);
    });
    _saveGames();
  }

  void _confirmRemove(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Game?'),
        content: const Text('Are you sure you want to remove this game from the library?\nThis will not delete your local game files.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              _removeGame(index);
            },
            child: const Text('Remove'),
          ),
        ],
      )
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(
              'KrKr2 Revived',
              style: TextStyle(
                fontWeight: FontWeight.w900, // Make font weight bold
                color: colorScheme.onSurface,
              ),
            ),
            centerTitle: false, // Title挪到左上角 (Left aligned)
            surfaceTintColor: colorScheme.surfaceTint,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0), // 右上角的设置图标离右边缘太近了，保证边距
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsView()),
                    );
                  },
                ),
              )
            ],
          ),
          if (_games.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videogame_asset_off_rounded,
                      size: 100,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No games installed',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
              padding: const EdgeInsets.all(24.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 24.0,
                  crossAxisSpacing: 24.0,
                  childAspectRatio: 2 / 3, // Poster Aspect Ratio
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final profile = _games[index];
                    
                    Widget coverWidget;
                    if (profile.coverLocalPath != null) {
                      coverWidget = Image.file(
                        File(profile.coverLocalPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image, size: 64)),
                      );
                    } else if (profile.coverUrl != null) {
                      coverWidget = Image.network(
                        profile.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image, size: 64)),
                      );
                    } else {
                      coverWidget = Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colorScheme.primaryContainer, colorScheme.secondaryContainer],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        ),
                        child: Center(
                          child: Icon(
                            Icons.sports_esports,
                            size: 64,
                            color: colorScheme.onPrimaryContainer.withOpacity(0.5),
                          ),
                        ),
                      );
                    }

                    return Card(
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: GestureDetector(
                        onSecondaryTapDown: (details) {
                          showMenu(
                            context: context,
                            position: RelativeRect.fromLTRB(
                              details.globalPosition.dx,
                              details.globalPosition.dy,
                              details.globalPosition.dx,
                              details.globalPosition.dy,
                            ),
                            items: [
                              PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_forever, color: colorScheme.error),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Remove from Library',
                                      style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ).then((value) {
                            if (value == 'remove') {
                              _confirmRemove(index);
                            }
                          });
                        },
                        onLongPress: () { // for mobile
                          _confirmRemove(index);
                        },
                        child: InkWell(
                          onTap: () {
                             // Open Game Settings instead of running directly
                             Navigator.push(
                               context,
                               MaterialPageRoute(builder: (_) => GameDetailsView(
                                 profile: profile,
                                 onUpdate: (updated) => _updateProfile(index, updated),
                                 onDelete: () => _removeGame(index),
                                 onPlay: widget.onGameSelected,
                               ))
                             );
                          },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            coverWidget,
                            // Title Overlay at the bottom
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black87, Colors.transparent],
                                  )
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
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
                            )
                          ],
                        ),
                      ),
                      ),
                    );
                  },
                  childCount: _games.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton( // removed .extended to drop text
        onPressed: _addGame,
        child: const Icon(Icons.add),
      ),
    );
  }
}
