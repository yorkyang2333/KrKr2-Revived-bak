import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'src/ffi/krkr2_bindings.dart';

class EngineController {
  late KrKr2Bindings _bindings;
  late ffi.DynamicLibrary _dylib;
  final List<String> logs = [];
  
  // Singleton pattern
  static final EngineController _instance = EngineController._internal();
  factory EngineController() => _instance;
  EngineController._internal();

  /// Initialize the engine with path to library
  void initialize() {
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
        ffi.Void Function(ffi.Int32 level, ffi.Pointer<ffi.Char> message)>.listener(_onLogReceived);
    _bindings.krkr2_set_log_callback(logCallback.nativeFunction);
  }

  void _onLogReceived(int level, ffi.Pointer<ffi.Char> message) {
    if (message != ffi.nullptr) {
      final text = message.cast<Utf8>().toDartString();
      logs.add('[$level] $text');
      print('Engine Log: $text');
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

  void tick() {
    _bindings.krkr2_tick();
  }

  void shutdown() {
    _bindings.krkr2_shutdown();
  }
}
