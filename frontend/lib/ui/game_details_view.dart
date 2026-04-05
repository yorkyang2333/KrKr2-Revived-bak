import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

import 'game_profile.dart'; // We'll create this next

class GameDetailsView extends StatefulWidget {
  final GameProfile profile;
  final Function(GameProfile) onUpdate;
  final VoidCallback onDelete;
  final Function(String) onPlay;

  const GameDetailsView({
    super.key,
    required this.profile,
    required this.onUpdate,
    required this.onDelete,
    required this.onPlay,
  });

  @override
  State<GameDetailsView> createState() => _GameDetailsViewState();
}

class _GameDetailsViewState extends State<GameDetailsView> {
  late GameProfile _profile;
  bool _isSearchingVNDB = false;

  @override
  void initState() {
    super.initState();
    _profile = GameProfile(
      path: widget.profile.path,
      name: widget.profile.name,
      coverUrl: widget.profile.coverUrl,
      coverLocalPath: widget.profile.coverLocalPath,
    );
  }

  void _saveProfile() {
    widget.onUpdate(_profile);
  }

  Future<void> _pickLocalCover() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
      dialogTitle: 'Select Local Cover Image',
    );

    if (result != null && result.files.single.path != null) {
      try {
        final originalPath = result.files.single.path!;
        final appDir = await getApplicationSupportDirectory();
        final coversDir = Directory('${appDir.path}/covers');
        if (!await coversDir.exists()) {
          await coversDir.create(recursive: true);
        }
        
        final ext = originalPath.split('.').last;
        final safeName = _profile.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final newPath = '${coversDir.path}/${safeName}_local.$ext';
        
        // Copy the picked file into our internal sandbox
        await File(originalPath).copy(newPath);

        setState(() {
          _profile.coverLocalPath = newPath;
          _profile.coverUrl = null; // Prioritize local
        });
        _saveProfile();
      } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save cover locally: $e')));
        }
      }
    }
  }

  Future<void> _fetchVNDBCover() async {
    final TextEditingController searchController = TextEditingController(text: _profile.name);

    String? query = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search VNDB'),
          content: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: 'Visual Novel Title',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
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

    if (query != null && query.isNotEmpty) {
      setState(() => _isSearchingVNDB = true);
      try {
        final response = await http.post(
          Uri.parse('https://api.vndb.org/kana/vn'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "filters": ["search", "=", query],
            "fields": "title, image.url"
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List;
          if (results.isNotEmpty && context.mounted) {
            String? selectedUrl = await showDialog<String>(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  title: const Text('Select Cover'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final vn = results[index];
                        final url = vn['image']?['url'];
                        return ListTile(
                          leading: url != null ? Image.network(url, width: 50, height: 50, fit: BoxFit.cover) : const Icon(Icons.broken_image),
                          title: Text(vn['title'] ?? 'Unknown'),
                          onTap: () {
                            Navigator.pop(ctx, url);
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            );

            if (selectedUrl != null) {
              setState(() => _isSearchingVNDB = true);
              try {
                final imageRes = await http.get(Uri.parse(selectedUrl));
                if (imageRes.statusCode == 200) {
                  final appDir = await getApplicationSupportDirectory();
                  final coversDir = Directory('${appDir.path}/covers');
                  if (!await coversDir.exists()) {
                    await coversDir.create(recursive: true);
                  }
                  final ext = selectedUrl.split('.').last;
                  final safeName = _profile.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                  final localFile = File('${coversDir.path}/${safeName}_cover.$ext');
                  await localFile.writeAsBytes(imageRes.bodyBytes);
                  
                  setState(() {
                    _profile.coverLocalPath = localFile.path;
                    _profile.coverUrl = null;
                  });
                  _saveProfile();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download cover: $e')));
                }
              } finally {
                setState(() => _isSearchingVNDB = false);
              }
            }
          } else {
             if(context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No results found on VNDB.')));
             }
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        setState(() => _isSearchingVNDB = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget coverWidget;
    if (_profile.coverLocalPath != null) {
      coverWidget = Image.file(
        File(_profile.coverLocalPath!),
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image, size: 64)),
      );
    } else if (_profile.coverUrl != null) {
      coverWidget = Image.network(
        _profile.coverUrl!,
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
            Icons.image_not_supported_rounded,
            size: 80,
            color: colorScheme.onPrimaryContainer.withOpacity(0.5),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Details', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Cover Image
            Expanded(
              flex: 1,
              child: Column(
                children: [
                   Card(
                    elevation: 8,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 2 / 3, // Standard poster ratio
                      child: coverWidget,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isSearchingVNDB)
                    const CircularProgressIndicator()
                  else ... [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('VNDB Search'),
                        onPressed: _fetchVNDBCover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        icon: const Icon(Icons.folder),
                        label: const Text('Local Cover'),
                        onPressed: _pickLocalCover,
                      ),
                    ),
                    if (_profile.coverUrl != null || _profile.coverLocalPath != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                          icon: const Icon(Icons.hide_image),
                          label: const Text('Remove Cover'),
                          onPressed: () {
                            setState(() {
                              _profile.coverUrl = null;
                              _profile.coverLocalPath = null;
                            });
                            _saveProfile();
                          },
                        ),
                      ),
                    ]
                  ]
                ],
              ),
            ),
            const SizedBox(width: 32),
            // Right Column: Information and Actions
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profile.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _profile.path,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 200,
                    height: 56,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text('PLAY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      onPressed: () => widget.onPlay(_profile.path),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    height: 48,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Remove from Library'),
                      onPressed: () {
                         showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Remove Game?'),
                            content: const Text('Are you sure you want to remove this game from the library?\nThis will not delete your local game files.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                                onPressed: () {
                                  Navigator.pop(ctx); // Pop dialog
                                  widget.onDelete(); // Delete internally
                                  Navigator.pop(context); // Pop screen
                                }, 
                                child: const Text('Remove')
                              ),
                            ],
                          )
                         );
                      },
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
