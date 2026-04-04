import 'package:flutter/material.dart';
import 'engine_controller.dart';

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
      theme: ThemeData.dark(useMaterial3: true),
      home: const KrKr2GameScreen(),
    );
  }
}

class KrKr2GameScreen extends StatefulWidget {
  const KrKr2GameScreen({super.key});

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
    
    // Start engine ticking
    _engine.startTicker();
    
    // Optional: Boot the game engine. Pass the path to your data folder.
    // _engine.startEngine("/path/to/data");
    
    setState(() {
      _isEngineReady = true;
    });
  }

  @override
  void dispose() {
    _engine.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isEngineReady && _engine.textureId != null
            ? AspectRatio(
                aspectRatio: 800 / 600, // Typically 800x600 for early krkr2 games
                child: Container(
                  color: Colors.black,
                  // The zero-copy Texture bridged from KrKr2 C++ pixel buffer
                  child: Texture(textureId: _engine.textureId!),
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Temporarily hardcode a bootstrap or show logs
          print(_engine.logs.join('\n'));
        },
        child: const Icon(Icons.bug_report),
      ),
    );
  }
}
