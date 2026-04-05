import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'data/launcher_settings_repository.dart';
import 'engine_controller.dart';
import 'models/launcher_settings.dart';
import 'ui/console_view.dart';
import 'ui/game_profile.dart';
import 'ui/main_menu.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KrKr2App());
}

class KrKr2App extends StatelessWidget {
  const KrKr2App({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'KrKr2 Revived',
          theme: AppTheme.lightTheme(lightDynamic),
          darkTheme: AppTheme.darkTheme(darkDynamic),
          themeMode: ThemeMode.system,
          home: Builder(
            builder: (BuildContext context) => MainMenuScreen(
              onGameSelected: (GameProfile profile) {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => KrKr2GameScreen(profile: profile),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class KrKr2GameScreen extends StatefulWidget {
  const KrKr2GameScreen({super.key, required this.profile});

  final GameProfile profile;

  @override
  State<KrKr2GameScreen> createState() => _KrKr2GameScreenState();
}

class _KrKr2GameScreenState extends State<KrKr2GameScreen> {
  final EngineController _engine = EngineController();
  final LauncherSettingsRepository _settingsRepository =
      LauncherSettingsRepository();

  bool _isEngineReady = false;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    try {
      final LauncherSettings settings = await _settingsRepository.load();

      if (settings.autoOpenConsole) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showConsole());
      }

      await _engine.initialize(settings: settings);
      final bool ready = _engine.startEngine(
        profile: widget.profile,
        settings: settings,
      );
      _engine.startTicker();

      if (!mounted) {
        return;
      }
      setState(() {
        _isEngineReady = ready;
      });
    } catch (error, stackTrace) {
      debugPrint('[Flutter] initEngine EXCEPTION: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _isEngineReady = true;
      });
    }
  }

  @override
  void dispose() {
    _engine.shutdown();
    super.dispose();
  }

  void _showConsole() {
    if (!mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        builder: (_, ScrollController controller) => const ConsoleView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Center(
            child: _isEngineReady && _engine.textureId != null
                ? AspectRatio(
                    aspectRatio: 800 / 600,
                    child: Container(
                      color: Colors.black,
                      child: Texture(textureId: _engine.textureId!),
                    ),
                  )
                : _isEngineReady
                ? Container(color: Colors.black)
                : const CircularProgressIndicator(),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.8),
        onPressed: _showConsole,
        child: Icon(
          Icons.terminal,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
