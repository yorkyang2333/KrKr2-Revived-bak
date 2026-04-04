import Cocoa
import FlutterMacOS
import CoreVideo

// MARK: - Global State for KrKr2 Texture
var globalTextureId: Int64 = -1
var globalTextureRegistry: FlutterTextureRegistry?
var globalKrKr2Texture: KrKr2Texture?
var globalWidth: Int32 = 0
var globalHeight: Int32 = 0

// MARK: - Flutter Texture Implementation
class KrKr2Texture: NSObject, FlutterTexture {
    var pixelBuffer: CVPixelBuffer?
    
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if let pb = pixelBuffer {
            return Unmanaged.passRetained(pb)
        }
        return nil
    }
}

// MARK: - C-Compatible API Exports for KrKr2 C++ Engine (Called via Dart FFI Function Pointers)
@_cdecl("swift_krkr2_create_texture")
public func swiftKrKr2CreateTexture(width: Int32, height: Int32, format: Int32) -> UnsafeMutableRawPointer? {
    globalWidth = width
    globalHeight = height
    var pb: CVPixelBuffer?
    let options: [String: Any] = [
        kCVPixelBufferMetalCompatibilityKey as String: true,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
    CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height), kCVPixelFormatType_32BGRA, options as CFDictionary, &pb)
    globalKrKr2Texture?.pixelBuffer = pb
    return UnsafeMutableRawPointer(bitPattern: 1) // Dummy handle
}

@_cdecl("swift_krkr2_update_texture")
public func swiftKrKr2UpdateTexture(tex: UnsafeMutableRawPointer?, pixels: UnsafeRawPointer?, pitch: Int32) {
    guard let pb = globalKrKr2Texture?.pixelBuffer, let pixels = pixels else { return }
    CVPixelBufferLockBaseAddress(pb, [])
    let dest = CVPixelBufferGetBaseAddress(pb)!
    let destPitch = CVPixelBufferGetBytesPerRow(pb)
    
    // Copy scanlines (KrKr2 outputs 32-bit BGRA exactly matching our CVPixelBuffer)
    let height = Int(globalHeight)
    let widthBytes = Int(globalWidth) * 4
    for y in 0..<height {
        memcpy(dest.advanced(by: y * destPitch), pixels.advanced(by: y * Int(pitch)), widthBytes)
    }
    CVPixelBufferUnlockBaseAddress(pb, [])
}

@_cdecl("swift_krkr2_destroy_texture")
public func swiftKrKr2DestroyTexture(tex: UnsafeMutableRawPointer?) {
    globalKrKr2Texture?.pixelBuffer = nil
}

@_cdecl("swift_krkr2_clear")
public func swiftKrKr2Clear() {
    guard let pb = globalKrKr2Texture?.pixelBuffer else { return }
    CVPixelBufferLockBaseAddress(pb, [])
    let dest = CVPixelBufferGetBaseAddress(pb)!
    let destPitch = CVPixelBufferGetBytesPerRow(pb)
    let height = Int(globalHeight)
    for y in 0..<height {
        memset(dest.advanced(by: y * destPitch), 0, destPitch)
    }
    CVPixelBufferUnlockBaseAddress(pb, [])
}

@_cdecl("swift_krkr2_present")
public func swiftKrKr2Present() {
    if let registry = globalTextureRegistry, globalTextureId != -1 {
        // Trigger Flutter repaint on the main thread
        DispatchQueue.main.async {
            registry.textureFrameAvailable(globalTextureId)
        }
    }
}

@_cdecl("swift_krkr2_draw_texture")
public func swiftKrKr2DrawTexture(tex: UnsafeMutableRawPointer?, x: Int32, y: Int32, w: Int32, h: Int32) {
    // Engine generally draws to its final buffer, draw_texture is often a no-op internally if we handle composition in engine
}

// MARK: - App Delegate
@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    globalTextureRegistry = controller.engine.textureRegistry
    
    // Setup MethodChannel for Texture Initialization from Dart
    let channel = FlutterMethodChannel(name: "krkr2/texture", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { (call, result) in
        if call.method == "initTexture" {
            let texture = KrKr2Texture()
            globalKrKr2Texture = texture
            globalTextureId = globalTextureRegistry!.register(texture)
            result(globalTextureId)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
