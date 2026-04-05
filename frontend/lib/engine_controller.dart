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

  ffi.NativeCallable<krkr2_log_callback_tFunction>? _logCallback;
  ffi.Pointer<krkr2_renderer_interface_t>? _rendererInterface;

  Stream<String> get logStream => _logStreamController.stream;
  bool get isLogForwardingEnabled => _forwardEngineLogs;

  int? textureId;
  Ticker? _ticker;
  bool _isRunning = false;
  bool _isInitialized = false;
  bool _forwardEngineLogs = true;
  int _logRetention = 250;
  Duration? _frameInterval;
  Duration? _lastTickAt;

  Future<void> initialize({required LauncherSettings settings}) async {
    _applyRuntimeSettings(settings);
    logs.clear();
    _lastTickAt = null;

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
    _pushEngineOptions(profile, settings);

    final pathPtr = profile.path.toNativeUtf8();
    _bindings.krkr2_set_game_path(pathPtr.cast<ffi.Char>());

    final argvItems = <String>['krkr2_flutter', ...profile.launchOptions];
    final argv = calloc<ffi.Pointer<ffi.Char>>(argvItems.length);
    try {
      for (int index = 0; index < argvItems.length; index += 1) {
        argv[index] = argvItems[index].toNativeUtf8().cast<ffi.Char>();
      }
      return _bindings.krkr2_init(argvItems.length, argv);
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
  }

  void shutdown() {
    if (!_isInitialized) {
      return;
    }
    _isRunning = false;
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _lastTickAt = null;
    _bindings.krkr2_shutdown();
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

    if (_frameInterval == null) {
      _bindings.krkr2_tick();
      return;
    }

    if (_lastTickAt == null || elapsed - _lastTickAt! >= _frameInterval!) {
      _lastTickAt = elapsed;
      _bindings.krkr2_tick();
    }
  }

  void _onLogReceived(int level, ffi.Pointer<ffi.Char> message) {
    if (!_forwardEngineLogs || message == ffi.nullptr) {
      return;
    }

    try {
      final text = message.cast<Utf8>().toDartString();
      final logEntry = '[$level] $text';
      logs.add(logEntry);
      if (logs.length > _logRetention) {
        logs.removeRange(0, logs.length - _logRetention);
      }
      _logStreamController.add(logEntry);
      debugPrint('Engine Log: $text');
    } catch (_) {
      debugPrint('Engine Log: [Malformed UTF-8 string]');
    }
  }
}
