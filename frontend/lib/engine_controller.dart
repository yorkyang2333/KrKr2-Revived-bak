import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'src/ffi/krkr2_bindings.dart';

class EngineController {
  late KrKr2Bindings _bindings;
  late ffi.DynamicLibrary _dylib;
  final List<String> logs = [];
  final StreamController<String> _logStreamController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logStreamController.stream;
  
  // Texture and Sync
  static const MethodChannel _channel = MethodChannel('krkr2/texture');
  int? textureId;
  Ticker? _ticker;
  bool _isRunning = false;
  
  // Singleton pattern
  static final EngineController _instance = EngineController._internal();
  factory EngineController() => _instance;
  EngineController._internal();

  /// Initialize the engine with path to library
  Future<void> initialize() async {
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
    
    // Set log callback
    final logCallback = ffi.NativeCallable<
        ffi.Void Function(ffi.Int level, ffi.Pointer<ffi.Char> message)>.listener(_onLogReceived);
    _bindings.krkr2_set_log_callback(logCallback.nativeFunction);
    
    // Register Texture
    if (Platform.isMacOS) {
      // 1. Invoke Swift MethodChannel to allocate KrKr2Texture
      final int id = await _channel.invokeMethod('initTexture');
      textureId = id;
      
      // 2. Map Swift @cdecl functions to C function pointers
      final rendererInterface = calloc<krkr2_renderer_interface_t>();
      rendererInterface.ref.create_texture = _dylib.lookup<ffi.NativeFunction<krkr2_texture_t Function(ffi.Int, ffi.Int, ffi.Int)>>('swift_krkr2_create_texture');
      rendererInterface.ref.update_texture = _dylib.lookup<ffi.NativeFunction<ffi.Void Function(krkr2_texture_t, ffi.Pointer<ffi.Void>, ffi.Int)>>('swift_krkr2_update_texture');
      rendererInterface.ref.destroy_texture = _dylib.lookup<ffi.NativeFunction<ffi.Void Function(krkr2_texture_t)>>('swift_krkr2_destroy_texture');
      rendererInterface.ref.clear = _dylib.lookup<ffi.NativeFunction<ffi.Void Function()>>('swift_krkr2_clear');
      rendererInterface.ref.draw_texture = _dylib.lookup<ffi.NativeFunction<ffi.Void Function(krkr2_texture_t, ffi.Int, ffi.Int, ffi.Int, ffi.Int)>>('swift_krkr2_draw_texture');
      rendererInterface.ref.present = _dylib.lookup<ffi.NativeFunction<ffi.Void Function()>>('swift_krkr2_present');
      
      // 3. Inject them into Engine C-API
      _bindings.krkr2_set_renderer_interface(rendererInterface);
    }
  }

  void _onLogReceived(int level, ffi.Pointer<ffi.Char> message) {
    if (message != ffi.nullptr) {
      try {
        final text = message.cast<Utf8>().toDartString();
        final logEntry = '[$level] $text';
        logs.add(logEntry);
        _logStreamController.add(logEntry);
        print('Engine Log: $text');
      } catch (e) {
        // Fallback for non-UTF8 logs without crashing the app
        print('Engine Log: [Malformed UTF-8 string]');
      }
    }
  }

  bool startEngine(String gamePath) {
    // We pass arguments directly. Convert gamePath to UTF-8
    final pathPtr = gamePath.toNativeUtf8();
    _bindings.krkr2_set_game_path(pathPtr.cast<ffi.Char>());
    
    // Prepare fake argv
    final argv = calloc<ffi.Pointer<ffi.Char>>(1);
    argv[0] = 'krkr2_flutter'.toNativeUtf8().cast<ffi.Char>();
    
    final result = _bindings.krkr2_init(1, argv);
    
    calloc.free(argv[0]);
    calloc.free(argv);
    calloc.free(pathPtr);
    
    return result;
  }

  void startTicker() {
    if (_ticker != null && _ticker!.isActive) return;
    _isRunning = true;
    _ticker = Ticker(_onTick);
    _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    if (_isRunning) {
      _bindings.krkr2_tick();
    }
  }

  void tick() {
    _bindings.krkr2_tick();
  }

  void shutdown() {
    _isRunning = false;
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _bindings.krkr2_shutdown();
  }
}
