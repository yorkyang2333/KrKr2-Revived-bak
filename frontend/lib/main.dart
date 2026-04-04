import 'package:flutter/material.dart';
import 'engine_controller.dart';
import 'ui/theme.dart';
import 'ui/main_menu.dart';
import 'ui/console_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KrKr2App());
}

class KrKr2App extends StatelessWidget {
  const KrKr2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KrKr2-Revived',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Fully supports auto light/dark toggle
      home: const MainMenuScreen(),
    );
  }
}

class KrKr2GameScreen extends StatefulWidget {
  final String gamePath;

  const KrKr2GameScreen({super.key, required this.gamePath});

  @override
  State<KrKr2GameScreen> createState() => _KrKr2GameScreenState();
}

class _KrKr2GameScreenState extends State<KrKr2GameScreen> {
  final EngineController _engine = EngineController();
  bool _isEngineReady = false;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    // Wait for the FFI and Texture bindings to set up
    await _engine.initialize();
    
    // Pass the user-selected game path into the krkr2_init function
    _engine.startEngine(widget.gamePath);

    // Start engine ticking loop (sync to Flutter display refresh)
    _engine.startTicker();
    
    setState(() {
      _isEngineReady = true;
    });
  }

  @override
  void dispose() {
    _engine.shutdown();
    super.dispose();
  }

  void _showConsole() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        builder: (_, controller) => const ConsoleView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Immersive game background
      body: Stack(
        children: [
          Center(
            child: _isEngineReady && _engine.textureId != null
                ? AspectRatio(
                    aspectRatio: 800 / 600, // Typically 800x600 for early krkr2
                    child: Container(
                      color: Colors.black,
                      // The zero-copy Texture bridged from KrKr2 C++
                      child: Texture(textureId: _engine.textureId!),
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
          // Transparent overlay safety button to go back or open console
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
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
        onPressed: _showConsole,
        child: Icon(
          Icons.terminal, 
          color: Theme.of(context).colorScheme.onPrimaryContainer
        ),
      ),
    );
  }
}
