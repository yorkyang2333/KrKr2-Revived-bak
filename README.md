# KrKr2-Revived

**KrKr2-Revived** is a cross-platform emulator for games built with the **KiriKiri engine** (T Visual Presenter).

This project is a refactor based on the original project [2468785842/krkr2](https://github.com/2468785842/krkr2).

## Core Refactoring Progress (KrKr2-Revived)
This project is heavily refactoring legacy C++ code into cross-platform C++17 and Rust:
- **Audio System**: Null implementation decoupling completed.
- **Encoding**: Replaced with Rust `krkr2-encoding`.
- **Image Decoding**: TLG5/6 original C++ code removed, rewritten in Rust `krkr2-image` with high-quality decompression and prediction.
- **Virtual File System (XP3)**: Entirely rewritten using Rust `krkr2-archive`, natively supporting `flate2`/zlib accelerated decompression and segment caching.
- **Rendering / Input**: New `IWindow` & `IRenderer` abstract layer implemented, backed by an SDL3 platform implementation (`SDLWindow`, `SDLRenderer`, `SDLInput`). `WindowImpl.cpp` fully migrated to use the new interfaces.
- **Native Game Compatibility**: Run raw packed `.xp3` games unmodified with heuristic encryption matching and automatic TJS stubbing.
- **Miscellaneous**: MD5, Random, RealFFT and other utilities have also been rewritten in Rust.

This repository is currently undergoing a **full architectural refactor** — decoupling the engine from Cocos2d-x, rebuilding core modules in modern C++, and replacing the UI layer with Flutter. Licensed under **GNU General Public License v3.0**.

**语言 / Language**: [中文](README_CN.md) | English

---

## Table of Contents

- [Supported Platforms](#supported-platforms)
- [Build Dependencies](#build-dependencies)
- [Build Steps](#build-steps)
- [Repository Hygiene](#repository-hygiene)
- [Architecture](#architecture)
- [Refactor Progress](#refactor-progress)
- [Supported Games](#supported-games)
- [License](#license)

---

## Supported Platforms

| Platform | Architecture | Status |
|----------|-------------|--------|
| Windows | x86_64 | ✅ Supported |
| Linux | x86_64 | ✅ Supported |
| macOS | arm64 | ✅ Supported |
| Android | arm64-v8a, x86_64 | ✅ Supported |
| iOS | arm64 | 🔄 Planned |

---

## Build Dependencies

| Tool | Version |
|------|---------|
| CMake | 3.31.1+ |
| Ninja | latest |
| vcpkg | latest |
| bison | 3.8.2+ (Windows: winflexbison) |
| python3 | any |
| NASM | latest |

**Platform extras:**
- **Windows**: Visual Studio 2022, [winflexbison](https://github.com/lexxmark/winflexbison)
- **Android**: Android SDK 33, NDK 28.0.13004108, JDK 17
- **macOS**: Xcode, YASM

### Environment Variables

```bash
# Linux / macOS / Android
export VCPKG_ROOT=/path/to/vcpkg

# Android only
export ANDROID_SDK=/path/to/androidsdk
export ANDROID_NDK=/path/to/androidndk

# Windows (use forward slashes)
set VCPKG_ROOT=D:/vcpkg
```

---

## Build Steps

**Quick build (backend + Flutter frontend)**:
```bash
./build_all.sh
```

**macOS**:
```bash
cmake --preset="MacOS Debug Config"
cmake --build --preset="MacOS Debug Build"
# Output: out/macos/debug/bin/krkr2/krkr2.app
```

**Linux**:
```bash
./scripts/build-linux.sh
# Output: out/linux/debug/bin/krkr2/krkr2
```

**Windows**:
```powershell
./scripts/build-windows.bat
# Output: out/windows/debug/bin/krkr2/krkr2.exe
```

**Android**:
```bash
./platforms/android/gradlew -p ./platforms/android assembleDebug
# Output: platforms/android/out/android/app/outputs/apk/debug/*.apk
```

**Docker**:
```bash
docker build -f dockers/linux.Dockerfile -t linux-builder .
docker build -f dockers/android.Dockerfile -t android-builder .
```

---

## Repository Hygiene

The following paths are local build artifacts and can be safely deleted when cleaning the workspace:

- `build/`
- `out/`
- `frontend/build/`
- `frontend/.dart_tool/`
- `frontend/macos/krkr2_libs/`
- `*.log`
- `.DS_Store`

The root `.gitignore` already excludes these generated files so they do not pollute `git status`.

---

## Architecture

### Target Design

The original codebase was tightly coupled to Cocos2d-x. The refactor introduces a clean three-layer architecture:

```
┌─────────────────────────────────┐
│         Flutter UI Layer        │  ← Dart FFI → C-API
├─────────────────────────────────┤
│       C-API (flat interface)    │  ← Stable cross-language boundary
├─────────────────────────────────┤
│     C++ Engine Core (backend/)  │  ← Platform-independent
│  ┌──────────┬──────────────┐    │
│  │  TJS2    │  IRenderer   │    │
│  │ Scripting│  IWindow     │    │
│  └──────────┴──────────────┘    │
└─────────────────────────────────┘
```

### Repository Structure

```
KrKr2-Revived/
├── backend/
│   ├── core/                  ← Pure C++ engine (no platform deps)
│   │   ├── tjs2/              ← TJS2 scripting engine
│   │   ├── base/              ← Save/event/scheduler core logic
│   │   ├── visual/            ← Layer & window interfaces (incl. gl/)
│   │   ├── sound/             ← Audio interface
│   │   ├── utils/             ← Utilities (encoding, iconv, etc.)
│   │   ├── environ/           ← Environment abstraction
│   │   ├── movie/             ← Video playback (ffmpeg)
│   │   ├── plugin/            ← Plugin framework (PluginIntf, ncbind)
│   │   ├── extension/         ← Extension framework
│   │   └── common/            ← Shared headers
│   ├── include/               ← Public API headers
│   ├── plugins/               ← Plugin implementations (steam, psbfile, etc.)
│   ├── external/              ← Third-party libraries (libbpg, minizip)
│   └── platform/
│       ├── legacy_cocos2d/    ← Original cocos2d renderer (to be replaced)
│       └── environ_legacy/    ← Platform implementations (win32/ apple/ android/ linux/ sdl/)
├── platforms/                 ← Platform projects (Android Gradle, etc.)
├── frontend/                  ← Flutter launcher UI and FFI bridge
├── doc/                       ← Documentation
├── scripts/                   ← Build scripts
├── tests/                     ← Tests
└── CMakeLists.txt
```

### Technology Choices

| Layer | Current | Target |
|-------|---------|--------|
| Scripting | TJS2 | TJS2 (kept) |
| Rendering | Cocos2d-x | `IRenderer` + SDL3/bgfx/Metal |
| Input | SDL2 | SDL3 |
| Audio | — | miniaudio / SDL3 |
| Package mgmt | vcpkg manifest | vcpkg manifest |
| UI | Cocos Studio | Flutter + Dart FFI |

---

## Refactor Progress

> Full task tracking: [doc/refactor_tasks.md](./doc/refactor_tasks.md)

### Phase 1: Core Decoupling ✅ Complete

- [x] Establish `backend/` directory structure
- [x] Migrate `cpp/core` → `backend/core`
- [x] Migrate `cpp/plugins` → `backend/plugins`
- [x] Migrate `cpp/external` → `backend/external`
- [x] Remove obsolete directories (`cpp/`, `ui/`, old build dirs)

### Phase 2: Standalone Module Compilation ✅ Complete

Verified compiling (macOS arm64):
- [x] Phase 3b: C++ Encapsulation Adapters & Two-Way Bi-directional FFI Binding
- [x] Phase 3c: Cryptographic Algorithms Migration (`krkr2-crypto` crate)
- [x] Phase 3d: Core Deserialization & Render Logic (`krkr2-image` crate)
- [x] Phase 3e: XP3 Core Archive & Platform I/O Architecture (`krkr2-archive` crate)
- [x] Phase 3f: Audio Buffers & WaveSegment Queue (`krkr2-audio` crate) ✅
- [x] Encoding and Utilities rewrite (`krkr2-encoding`, `crypto`, `fft`) ✅

### Phase 4: Renderer Rewrite ✅ Complete

- [x] `IWindow` abstract interface (`backend/core/visual/IWindow.h`) — full method set for geometry, fullscreen, cursor, IME, touch, zoom, etc.
- [x] `IRenderer` abstract interface (`backend/core/visual/IRenderer.h`)
- [x] `SDLWindow` SDL3 implementation — position, min/max size, fullscreen, cursor, stay-on-top, close
- [x] `SDLRenderer` SDL3 implementation
- [x] `SDLInput` SDL3 event polling → engine routing
- [x] `TVPWindow_SDL.cpp` — SDL platform factory (`TVPCreateAndAddWindow`)
- [x] `WindowImpl.cpp` refactored to use `IWindow`/`IRenderer` instead of Win32/Cocos APIs
- [x] `krkr2_api.h` and `krkr2_renderer.h` updated with window management and renderer APIs

### Phase 5: Flutter UI Integration 🚧 In progress

- [x] Initialize Flutter `frontend/` project
- [x] Dart FFI bindings for C-API
- [x] Rewrite core launcher views in Flutter (main menu, console, file selector) - ongoing polish
- [x] Link the macOS frontend with the backend static library pipeline
- [ ] CI/CD for all platforms

---

## Code Formatting

Uses `clang-format@20`:

**Linux / macOS**:
```bash
clang-format -i --verbose $(find ./backend ./platforms ./tests ./tools -name "*.cpp" -o -name "*.cc" -o -name "*.h" -o -name "*.hpp" -o -name "*.inc")
```

**Windows**:
```powershell
Get-ChildItem -Path ./backend, ./platforms, ./tests, ./tools -Recurse -File |
Where-Object { $_.Name -match '\.(cpp|cc|h|hpp|inc)$' } |
ForEach-Object { clang-format -i --verbose $_.FullName }
```

---

## Supported Games

See the [supported games list](./doc/support_games.txt).

Plugin resources: [wamsoft GitHub repositories](https://github.com/orgs/wamsoft/repositories?type=all)

---

## License

**GNU General Public License v3.0**. See [LICENSE](./LICENSE) for details.
