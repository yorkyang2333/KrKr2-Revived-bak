import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../engine_controller.dart';
import '../main.dart'; // To access KrKr2GameScreen

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final List<String> _gamePaths = []; // In-memory list for now
  final EngineController _engine = EngineController();

  Future<void> _addGame() async {
    // Attempt to pick a folder (.xp3 is typically inside or they pick a data directory)
    // On macOS, desktop users often pick a folder. On Android, it might be an .xp3 file.
    // For universal compatibility, we allow picking directories or files.
    String? selectedPath;
    
    // As a simple approach, try fetching a directory first as it represents the game root
    selectedPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select KrKr2 Game Folder Data',
    );

    if (selectedPath != null && !_gamePaths.contains(selectedPath)) {
      setState(() {
        _gamePaths.add(selectedPath!);
      });
    }
  }

  void _launchGame(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KrKr2GameScreen(gamePath: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KrKr2-Revived'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Settings placeholder
            },
          )
        ],
      ),
      body: _gamePaths.isEmpty ? _buildEmptyPlaceholder() : _buildGameList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGame,
        icon: const Icon(Icons.add),
        label: const Text('Add Game'),
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videogame_asset_off_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No games installed',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to locate your game directory\nor .xp3 archive.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _gamePaths.length,
      itemBuilder: (context, index) {
        final path = _gamePaths[index];
        final name = path.split('/').last; // Very naive name extraction

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _launchGame(path),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.videogame_asset,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          path,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
