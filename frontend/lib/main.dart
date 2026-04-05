import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final FocusNode _gameFocusNode = FocusNode(debugLabel: 'KrKr2Game');

  _GameLaunchState _launchState = _GameLaunchState.loading;
  String? _startupError;
  double _gameAspectRatio = 4 / 3;
  int _gameWidth = 0;
  int _gameHeight = 0;
  int _activeMouseButton = 0;

  @override
  void initState() {
    super.initState();
    _engine.startupSnapshotListenable.addListener(
      _handleStartupSnapshotChanged,
    );
    _initEngine();
  }

  Future<void> _initEngine() async {
    _engine.shutdown();

    if (mounted) {
      setState(() {
        _launchState = _GameLaunchState.loading;
        _startupError = null;
      });
    }

    try {
      final LauncherSettings settings = await _settingsRepository.load();

      if (settings.autoOpenConsole) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showConsole());
      }

      await _engine.initialize(settings: settings);
      final bool requested = _engine.startEngine(
        profile: widget.profile,
        settings: settings,
      );
      if (requested) {
        _engine.startTicker();
        _handleStartupSnapshotChanged();
      } else if (mounted) {
        setState(() {
          _launchState = _GameLaunchState.failed;
          _startupError = 'Engine startup request was rejected.';
        });
      }
    } catch (error, stackTrace) {
      debugPrint('[Flutter] initEngine EXCEPTION: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _launchState = _GameLaunchState.failed;
        _startupError = '$error';
      });
    }
  }

  @override
  void dispose() {
    _engine.startupSnapshotListenable.removeListener(
      _handleStartupSnapshotChanged,
    );
    _gameFocusNode.dispose();
    _engine.shutdown();
    super.dispose();
  }

  void _handleStartupSnapshotChanged() {
    if (!mounted) {
      return;
    }

    final EngineStartupSnapshot snapshot = _engine.startupSnapshot;
    final _GameLaunchState nextState;
    switch (snapshot.state) {
      case EngineStartupState.idle:
      case EngineStartupState.starting:
        nextState = _GameLaunchState.loading;
        break;
      case EngineStartupState.running:
        nextState = snapshot.hasFirstFrame
            ? _GameLaunchState.ready
            : _GameLaunchState.runningWithoutFrame;
        break;
      case EngineStartupState.failed:
        nextState = _GameLaunchState.failed;
        break;
    }

    final String? nextError = nextState == _GameLaunchState.failed
        ? snapshot.errorMessage
        : null;
    final double nextAspectRatio = snapshot.hasRenderableSize
        ? snapshot.aspectRatio
        : _gameAspectRatio;
    final int nextWidth = snapshot.width > 0 ? snapshot.width : _gameWidth;
    final int nextHeight = snapshot.height > 0 ? snapshot.height : _gameHeight;

    if (_launchState == nextState &&
        _startupError == nextError &&
        _gameAspectRatio == nextAspectRatio &&
        _gameWidth == nextWidth &&
        _gameHeight == nextHeight) {
      return;
    }

    setState(() {
      _launchState = nextState;
      _startupError = nextError;
      _gameAspectRatio = nextAspectRatio;
      _gameWidth = nextWidth;
      _gameHeight = nextHeight;
    });

    if (nextState == _GameLaunchState.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _gameFocusNode.requestFocus();
        }
      });
    }
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
          Center(child: _buildGameBody(context)),
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

  Widget _buildGameBody(BuildContext context) {
    switch (_launchState) {
      case _GameLaunchState.loading:
        return _buildLaunchProgress(
          context,
          title: 'Starting engine',
          message:
              'Mounting archives, loading plugins, and preparing startup scripts.',
        );
      case _GameLaunchState.runningWithoutFrame:
        return _buildLaunchProgress(
          context,
          title: 'Waiting for first frame',
          message:
              'The engine is running, but the game has not produced a frame yet.',
        );
      case _GameLaunchState.ready:
        if (_engine.textureId == null) {
          return _buildLaunchProgress(
            context,
            title: 'Renderer not attached',
            message:
                'The engine is running, but Flutter did not register a texture for the game output yet.',
          );
        }
        return AspectRatio(
          aspectRatio: _gameAspectRatio,
          child: _buildInteractiveTexture(),
        );
      case _GameLaunchState.failed:
        return _buildStartupError(context);
    }
  }

  Widget _buildInteractiveTexture() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;

        return Focus(
          focusNode: _gameFocusNode,
          onKeyEvent: (_, KeyEvent event) => _handleKeyEvent(event),
          child: MouseRegion(
            onExit: (_) {
              _activeMouseButton = 0;
              _engine.pushMouseEvent(
                type: _MouseEventType.leave,
                button: 0,
                x: 0,
                y: 0,
              );
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (PointerDownEvent event) {
                _gameFocusNode.requestFocus();
                _activeMouseButton = _pointerButtonToEngineButton(
                  event.buttons,
                );
                final Offset point = _mapPointerToGame(
                  event.localPosition,
                  width,
                  height,
                );
                _engine.pushMouseEvent(
                  type: _MouseEventType.down,
                  button: _activeMouseButton,
                  x: point.dx.round(),
                  y: point.dy.round(),
                );
              },
              onPointerUp: (PointerUpEvent event) {
                final Offset point = _mapPointerToGame(
                  event.localPosition,
                  width,
                  height,
                );
                _engine.pushMouseEvent(
                  type: _MouseEventType.up,
                  button: _activeMouseButton,
                  x: point.dx.round(),
                  y: point.dy.round(),
                );
                _activeMouseButton = 0;
              },
              onPointerHover: (PointerHoverEvent event) {
                final Offset point = _mapPointerToGame(
                  event.localPosition,
                  width,
                  height,
                );
                _engine.pushMouseEvent(
                  type: _MouseEventType.move,
                  button: 0,
                  x: point.dx.round(),
                  y: point.dy.round(),
                );
              },
              onPointerMove: (PointerMoveEvent event) {
                final Offset point = _mapPointerToGame(
                  event.localPosition,
                  width,
                  height,
                );
                _engine.pushMouseEvent(
                  type: _MouseEventType.move,
                  button: 0,
                  x: point.dx.round(),
                  y: point.dy.round(),
                );
              },
              child: ColoredBox(
                color: Colors.black,
                child: Texture(textureId: _engine.textureId!),
              ),
            ),
          ),
        );
      },
    );
  }

  Offset _mapPointerToGame(Offset localPosition, double width, double height) {
    final int sourceWidth = _gameWidth > 0 ? _gameWidth : 1;
    final int sourceHeight = _gameHeight > 0 ? _gameHeight : 1;
    final double safeWidth = width <= 0 ? 1 : width;
    final double safeHeight = height <= 0 ? 1 : height;

    final double x =
        (localPosition.dx.clamp(0.0, safeWidth) / safeWidth) * sourceWidth;
    final double y =
        (localPosition.dy.clamp(0.0, safeHeight) / safeHeight) * sourceHeight;
    return Offset(x, y);
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    final int? keycode = _mapLogicalKeyToVk(event.logicalKey);
    if (keycode == null) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      _engine.pushKeyEvent(type: _KeyEventType.down, keycode: keycode);
      final String? character = event.character;
      if (character != null && character.isNotEmpty) {
        final int codePoint = character.runes.first;
        if (codePoint > 0 && codePoint <= 0xFFFF) {
          _engine.pushKeyEvent(type: _KeyEventType.press, keycode: codePoint);
        }
      }
      return KeyEventResult.handled;
    }

    if (event is KeyUpEvent) {
      _engine.pushKeyEvent(type: _KeyEventType.up, keycode: keycode);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  int _pointerButtonToEngineButton(int buttons) {
    if ((buttons & 0x02) != 0) {
      return 1;
    }
    if ((buttons & 0x04) != 0) {
      return 2;
    }
    return 0;
  }

  int? _mapLogicalKeyToVk(LogicalKeyboardKey key) {
    final Map<LogicalKeyboardKey, int> directMap = <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.enter: 0x0D,
      LogicalKeyboardKey.numpadEnter: 0x0D,
      LogicalKeyboardKey.escape: 0x1B,
      LogicalKeyboardKey.space: 0x20,
      LogicalKeyboardKey.backspace: 0x08,
      LogicalKeyboardKey.delete: 0x2E,
      LogicalKeyboardKey.tab: 0x09,
      LogicalKeyboardKey.arrowLeft: 0x25,
      LogicalKeyboardKey.arrowUp: 0x26,
      LogicalKeyboardKey.arrowRight: 0x27,
      LogicalKeyboardKey.arrowDown: 0x28,
      LogicalKeyboardKey.home: 0x24,
      LogicalKeyboardKey.end: 0x23,
      LogicalKeyboardKey.pageUp: 0x21,
      LogicalKeyboardKey.pageDown: 0x22,
      LogicalKeyboardKey.insert: 0x2D,
      LogicalKeyboardKey.shiftLeft: 0xA0,
      LogicalKeyboardKey.shiftRight: 0xA1,
      LogicalKeyboardKey.controlLeft: 0xA2,
      LogicalKeyboardKey.controlRight: 0xA3,
      LogicalKeyboardKey.altLeft: 0xA4,
      LogicalKeyboardKey.altRight: 0xA5,
      LogicalKeyboardKey.f1: 0x70,
      LogicalKeyboardKey.f2: 0x71,
      LogicalKeyboardKey.f3: 0x72,
      LogicalKeyboardKey.f4: 0x73,
      LogicalKeyboardKey.f5: 0x74,
      LogicalKeyboardKey.f6: 0x75,
      LogicalKeyboardKey.f7: 0x76,
      LogicalKeyboardKey.f8: 0x77,
      LogicalKeyboardKey.f9: 0x78,
      LogicalKeyboardKey.f10: 0x79,
      LogicalKeyboardKey.f11: 0x7A,
      LogicalKeyboardKey.f12: 0x7B,
      LogicalKeyboardKey.minus: 0xBD,
      LogicalKeyboardKey.equal: 0xBB,
      LogicalKeyboardKey.comma: 0xBC,
      LogicalKeyboardKey.period: 0xBE,
      LogicalKeyboardKey.slash: 0xBF,
      LogicalKeyboardKey.semicolon: 0xBA,
      LogicalKeyboardKey.quote: 0xDE,
      LogicalKeyboardKey.bracketLeft: 0xDB,
      LogicalKeyboardKey.bracketRight: 0xDD,
      LogicalKeyboardKey.backslash: 0xDC,
      LogicalKeyboardKey.backquote: 0xC0,
    };

    final int? direct = directMap[key];
    if (direct != null) {
      return direct;
    }

    final String label = key.keyLabel.toUpperCase();
    if (label.length == 1) {
      final int codeUnit = label.codeUnitAt(0);
      final bool isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
      final bool isLetter = codeUnit >= 0x41 && codeUnit <= 0x5A;
      if (isDigit || isLetter) {
        return codeUnit;
      }
    }

    return null;
  }

  Widget _buildLaunchProgress(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartupError(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.error_outline, color: colorScheme.error, size: 36),
                const SizedBox(height: 16),
                Text(
                  'Game failed to start',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The engine stopped before the game screen was ready. The detail below includes the last startup step and any plugin failures the bridge detected.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_startupError != null &&
                    _startupError!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  SelectableText(
                    _startupError!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _initEngine,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _GameLaunchState { loading, runningWithoutFrame, ready, failed }

abstract final class _MouseEventType {
  static const int move = 0;
  static const int down = 1;
  static const int up = 2;
  static const int leave = 3;
}

abstract final class _KeyEventType {
  static const int down = 0;
  static const int up = 1;
  static const int press = 2;
}
