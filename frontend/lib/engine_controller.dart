import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'models/launcher_settings.dart';
import 'src/ffi/krkr2_bindings.dart';
import 'ui/game_profile.dart';

enum EngineStartupState { idle, starting, running, failed }

@immutable
class EngineStartupSnapshot {
  const EngineStartupSnapshot({
    this.state = EngineStartupState.idle,
    this.hasFirstFrame = false,
    this.width = 0,
    this.height = 0,
    this.errorMessage,
  });

  final EngineStartupState state;
  final bool hasFirstFrame;
  final int width;
  final int height;
  final String? errorMessage;

  bool get hasRenderableSize => width > 0 && height > 0;
  bool get isReady => state == EngineStartupState.running && hasFirstFrame;
  double get aspectRatio => hasRenderableSize ? width / height : 4 / 3;

  @override
  bool operator ==(Object other) {
    return other is EngineStartupSnapshot &&
        other.state == state &&
        other.hasFirstFrame == hasFirstFrame &&
        other.width == width &&
        other.height == height &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode =>
      Object.hash(state, hasFirstFrame, width, height, errorMessage);
}

class EngineController {
  static const List<String> _knownOptionKeys = <String>[
    'default_font',
    'force_default_font',
    'memusage',
    'fps_limit',
    'outputlog',
  ];

  static const MethodChannel _channel = MethodChannel('krkr2/texture');

  EngineController._internal();

  static final EngineController _instance = EngineController._internal();

  factory EngineController() => _instance;

  late KrKr2Bindings _bindings;
  late ffi.DynamicLibrary _dylib;

  final List<String> logs = <String>[];
  final StreamController<String> _logStreamController =
      StreamController<String>.broadcast();
  final ValueNotifier<EngineStartupSnapshot> _startupSnapshot =
      ValueNotifier<EngineStartupSnapshot>(const EngineStartupSnapshot());

  ffi.NativeCallable<krkr2_log_callback_tFunction>? _logCallback;
  ffi.Pointer<krkr2_renderer_interface_t>? _rendererInterface;

  Stream<String> get logStream => _logStreamController.stream;
  ValueListenable<EngineStartupSnapshot> get startupSnapshotListenable =>
      _startupSnapshot;
  EngineStartupSnapshot get startupSnapshot => _startupSnapshot.value;
  bool get isLogForwardingEnabled => _forwardEngineLogs;

  int? textureId;
  Ticker? _ticker;
  bool _isRunning = false;
  bool _isInitialized = false;
  bool _forwardEngineLogs = true;
  int _logRetention = 250;
  Duration? _frameInterval;
  Duration? _lastTickAt;
  String? _activeLaunchLabel;

  Future<void> initialize({required LauncherSettings settings}) async {
    _applyRuntimeSettings(settings);
    _lastTickAt = null;
    _updateStartupSnapshot(const EngineStartupSnapshot());

    if (Platform.isMacOS) {
      _dylib = ffi.DynamicLibrary.process();
    } else if (Platform.isLinux || Platform.isAndroid) {
      _dylib = ffi.DynamicLibrary.open('libkrkr2platform.so');
    } else if (Platform.isWindows) {
      _dylib = ffi.DynamicLibrary.open('krkr2platform.dll');
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    _bindings = KrKr2Bindings(_dylib);
    _isInitialized = true;

    _logCallback?.close();
    _logCallback =
        ffi.NativeCallable<krkr2_log_callback_tFunction>.isolateLocal(
          _onLogReceived,
        );
    _bindings.krkr2_set_log_callback(_logCallback!.nativeFunction);

    if (Platform.isMacOS) {
      try {
        final int id = await _channel.invokeMethod('initTexture');
        textureId = id;
        debugPrint('[Engine] Texture registered with id=$id');
      } catch (e) {
        debugPrint('[Engine] WARNING: initTexture failed: $e');
      }

      try {
        _rendererInterface ??= calloc<krkr2_renderer_interface_t>();
        _rendererInterface!.ref.create_texture = _dylib
            .lookup<
              ffi.NativeFunction<
                krkr2_texture_t Function(ffi.Int, ffi.Int, ffi.Int)
              >
            >('swift_krkr2_create_texture');
        _rendererInterface!.ref.update_texture = _dylib
            .lookup<
              ffi.NativeFunction<
                ffi.Void Function(
                  krkr2_texture_t,
                  ffi.Pointer<ffi.Void>,
                  ffi.Int,
                )
              >
            >('swift_krkr2_update_texture');
        _rendererInterface!.ref.destroy_texture = _dylib
            .lookup<ffi.NativeFunction<ffi.Void Function(krkr2_texture_t)>>(
              'swift_krkr2_destroy_texture',
            );
        _rendererInterface!.ref.clear = _dylib
            .lookup<ffi.NativeFunction<ffi.Void Function()>>(
              'swift_krkr2_clear',
            );
        _rendererInterface!.ref.draw_texture = _dylib
            .lookup<
              ffi.NativeFunction<
                ffi.Void Function(
                  krkr2_texture_t,
                  ffi.Int,
                  ffi.Int,
                  ffi.Int,
                  ffi.Int,
                )
              >
            >('swift_krkr2_draw_texture');
        _rendererInterface!.ref.present = _dylib
            .lookup<ffi.NativeFunction<ffi.Void Function()>>(
              'swift_krkr2_present',
            );

        _bindings.krkr2_set_renderer_interface(_rendererInterface!);
        debugPrint('[Engine] Renderer interface set up successfully');
      } catch (e) {
        debugPrint(
          '[Engine] WARNING: Renderer interface setup failed (headless mode): $e',
        );
      }
    }
  }

  bool startEngine({
    required GameProfile profile,
    required LauncherSettings settings,
  }) {
    _applyRuntimeSettings(settings, profile: profile);
    _updateStartupSnapshot(
      const EngineStartupSnapshot(state: EngineStartupState.starting),
    );
    _activeLaunchLabel = profile.name;
    _appendLogEntry('=== Launch Start: ${profile.name} ===');
    _pushEngineOptions(profile, settings);

    final pathPtr = profile.path.toNativeUtf8();
    _bindings.krkr2_set_game_path(pathPtr.cast<ffi.Char>());

    final argvItems = <String>['krkr2_flutter', ...profile.launchOptions];
    final argv = calloc<ffi.Pointer<ffi.Char>>(argvItems.length);
    try {
      for (int index = 0; index < argvItems.length; index += 1) {
        argv[index] = argvItems[index].toNativeUtf8().cast<ffi.Char>();
      }
      final bool launched = _bindings.krkr2_init(argvItems.length, argv);
      if (!launched) {
        _updateStartupSnapshot(
          const EngineStartupSnapshot(
            state: EngineStartupState.failed,
            errorMessage: 'Engine startup request was rejected.',
          ),
        );
      }
      return launched;
    } finally {
      for (int index = 0; index < argvItems.length; index += 1) {
        calloc.free(argv[index]);
      }
      calloc.free(argv);
      calloc.free(pathPtr);
    }
  }

  void startTicker() {
    if (_ticker != null && _ticker!.isActive) {
      return;
    }
    _isRunning = true;
    _lastTickAt = null;
    _ticker = Ticker(_onTick);
    _ticker!.start();
  }

  void tick() {
    _bindings.krkr2_tick();
    _pollStartupSnapshot();
  }

  void pushMouseEvent({
    required int type,
    required int button,
    required int x,
    required int y,
  }) {
    if (!_isInitialized) {
      return;
    }
    _bindings.krkr2_push_mouse_event(type, button, x, y);
  }

  void pushKeyEvent({required int type, required int keycode}) {
    if (!_isInitialized) {
      return;
    }
    _bindings.krkr2_push_key_event(type, keycode);
  }

  void shutdown() {
    if (!_isInitialized) {
      return;
    }
    if (_activeLaunchLabel != null) {
      _appendLogEntry('=== Launch End: $_activeLaunchLabel ===');
      _activeLaunchLabel = null;
    }
    _isRunning = false;
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _lastTickAt = null;
    _bindings.krkr2_shutdown();
    _updateStartupSnapshot(const EngineStartupSnapshot());
    _isInitialized = false;
  }

  void dispose() {
    shutdown();
    _logCallback?.close();
    _logCallback = null;
    if (_rendererInterface != null) {
      calloc.free(_rendererInterface!);
      _rendererInterface = null;
    }
  }

  void _applyRuntimeSettings(
    LauncherSettings settings, {
    GameProfile? profile,
  }) {
    _forwardEngineLogs = settings.forwardEngineLogs;
    _logRetention = settings.logRetention;
    _frameInterval =
        (profile?.resolveFramePacing(settings) ?? settings.framePacing)
            .tickInterval;
  }

  void _pushEngineOptions(GameProfile profile, LauncherSettings settings) {
    final globalOptions = settings.toEngineGlobalOptions();
    for (final MapEntry<String, String> entry in globalOptions.entries) {
      final keyPtr = entry.key.toNativeUtf8();
      final valuePtr = entry.value.toNativeUtf8();
      try {
        _bindings.krkr2_set_global_option(
          keyPtr.cast<ffi.Char>(),
          valuePtr.cast<ffi.Char>(),
        );
      } finally {
        calloc.free(keyPtr);
        calloc.free(valuePtr);
      }
    }

    for (final String key in _knownOptionKeys) {
      final keyPtr = key.toNativeUtf8();
      try {
        _bindings.krkr2_clear_current_game_option(keyPtr.cast<ffi.Char>());
      } finally {
        calloc.free(keyPtr);
      }
    }

    final gameOptions = profile.compatibilityOverrides.toEngineOptionMap();
    for (final MapEntry<String, String> entry in gameOptions.entries) {
      final keyPtr = entry.key.toNativeUtf8();
      final valuePtr = entry.value.toNativeUtf8();
      try {
        _bindings.krkr2_set_current_game_option(
          keyPtr.cast<ffi.Char>(),
          valuePtr.cast<ffi.Char>(),
        );
      } finally {
        calloc.free(keyPtr);
        calloc.free(valuePtr);
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (!_isRunning) {
      return;
    }

    final bool shouldThrottle =
        _startupSnapshot.value.state == EngineStartupState.running &&
        _frameInterval != null;

    if (!shouldThrottle) {
      _lastTickAt = null;
      _bindings.krkr2_tick();
      _pollStartupSnapshot();
      return;
    }

    if (_lastTickAt == null || elapsed - _lastTickAt! >= _frameInterval!) {
      _lastTickAt = elapsed;
      _bindings.krkr2_tick();
    }
    _pollStartupSnapshot();
  }

  void _onLogReceived(int level, ffi.Pointer<ffi.Char> message) {
    if (!_forwardEngineLogs || message == ffi.nullptr) {
      return;
    }

    try {
      final text = message.cast<Utf8>().toDartString();
      final logEntry = '[$level] $text';
      _appendLogEntry(logEntry);
      debugPrint('Engine Log: $text');
    } catch (_) {
      debugPrint('Engine Log: [Malformed UTF-8 string]');
    }
  }

  void _appendLogEntry(String entry) {
    logs.add(entry);
    if (logs.length > _logRetention) {
      logs.removeRange(0, logs.length - _logRetention);
    }
    _logStreamController.add(entry);
  }

  void _pollStartupSnapshot() {
    if (!_isInitialized) {
      return;
    }

    final EngineStartupState state = _mapStartupState(
      _bindings.krkr2_get_startup_state(),
    );
    final bool hasFirstFrame = _bindings.krkr2_has_first_frame();
    final ({int width, int height}) size = _readWindowSize();
    final String? errorMessage = _readErrorMessage();

    _updateStartupSnapshot(
      EngineStartupSnapshot(
        state: state,
        hasFirstFrame: hasFirstFrame,
        width: size.width,
        height: size.height,
        errorMessage: errorMessage,
      ),
    );
  }

  ({int width, int height}) _readWindowSize() {
    final ffi.Pointer<ffi.Int> widthPtr = calloc<ffi.Int>();
    final ffi.Pointer<ffi.Int> heightPtr = calloc<ffi.Int>();
    try {
      _bindings.krkr2_get_window_size(widthPtr, heightPtr);
      return (width: widthPtr.value, height: heightPtr.value);
    } finally {
      calloc.free(widthPtr);
      calloc.free(heightPtr);
    }
  }

  String? _readErrorMessage() {
    final ffi.Pointer<ffi.Char> errorPtr = _bindings
        .krkr2_get_last_error_message();
    if (errorPtr == ffi.nullptr) {
      return null;
    }

    try {
      final String message = errorPtr.cast<Utf8>().toDartString().trim();
      return message.isEmpty ? null : message;
    } catch (_) {
      return 'Failed to decode engine error message.';
    }
  }

  void _updateStartupSnapshot(EngineStartupSnapshot snapshot) {
    if (_startupSnapshot.value == snapshot) {
      return;
    }
    _startupSnapshot.value = snapshot;
  }

  EngineStartupState _mapStartupState(int state) {
    switch (state) {
      case 1:
        return EngineStartupState.starting;
      case 2:
        return EngineStartupState.running;
      case 3:
        return EngineStartupState.failed;
      case 0:
      default:
        return EngineStartupState.idle;
    }
  }
}
