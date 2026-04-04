# KrKr2-Revived

KrKr2-Revived 是一款**跨平台**的 KiriKiri 引擎（T Visual Presenter）模拟器，目标是在 Windows / macOS / Linux / iOS / Android 上运行吉里吉里2引擎制作的游戏。
## 核心重构进度 (KrKr2-Revived)
本项目正在将原有的旧 C++ 代码大量重构为原生跨平台 C++17 及 Rust：
- **音频系统**：空实现解耦完成
- **编码转换**：使用 Rust `krkr2-encoding` 替代。
- **图像解码**：TLG5/6 原版 C++ 代码完全移除，重写为 Rust `krkr2-image` 并提供高质量解压与预测。
- **虚拟文件系统 (XP3)**：全量使用 Rust `krkr2-archive` 重写，原生支持 `flate2`/zlib 加速解压与共享内存块缓存机制。
- **其他周边**：MD5, Random, RealFFT 等模块也已用 Rust 改写。

本项目基于原项目 [2468785842/krkr2](https://github.com/2468785842/krkr2) 进行重构。

本仓库目前正在进行**全面重构**，将底层从 Cocos2d-x 解耦，迁移到现代 C++ 架构，并以 Flutter 重写 UI 层。本项目遵循 **GNU General Public License v3.0**。

**语言 / Language**: 中文 | [English](README.md)

---

## 目录

- [支持平台](#支持平台)
- [构建依赖](#构建依赖)
- [编译步骤](#编译步骤)
- [架构设计](#架构设计)
- [重构进度](#重构进度)
- [支持的游戏](#支持的游戏)
- [许可证](#许可证)

---

## 支持平台

| 平台 | 架构 | 状态 |
|------|------|------|
| Windows | x86_64 | ✅ 支持 |
| Linux | x86_64 | ✅ 支持 |
| macOS | arm64 | ✅ 支持 |
| Android | arm64-v8a, x86_64 | ✅ 支持 |
| iOS | arm64 | 🔄 规划中 |

---

## 构建依赖

| 工具 | 版本要求 |
|------|---------|
| CMake | 3.31.1+ |
| Ninja | latest |
| vcpkg | latest |
| bison | 3.8.2+（Windows 用 winflexbison） |
| python3 | any |
| NASM | latest |

**平台附加依赖：**
- **Windows**: Visual Studio 2022, [winflexbison](https://github.com/lexxmark/winflexbison)
- **Android**: Android SDK 33, NDK 28.0.13004108, JDK 17
- **macOS**: Xcode, YASM

### 环境变量

```bash
# Linux / macOS / Android
export VCPKG_ROOT=/path/to/vcpkg

# Android 附加
export ANDROID_SDK=/path/to/androidsdk
export ANDROID_NDK=/path/to/androidndk

# Windows（使用正斜杠）
set VCPKG_ROOT=D:/vcpkg
```

---

## 编译步骤

**macOS**:
```bash
cmake --preset="MacOS Debug Config"
cmake --build --preset="MacOS Debug Build"
# 产物: out/macos/debug/bin/krkr2/krkr2.app
```

**Linux**:
```bash
./scripts/build-linux.sh
# 产物: out/linux/debug/bin/krkr2/krkr2
```

**Windows**:
```powershell
./scripts/build-windows.bat
# 产物: out/windows/debug/bin/krkr2/krkr2.exe
```

**Android**:
```bash
./platforms/android/gradlew -p ./platforms/android assembleDebug
# 产物: platforms/android/out/android/app/outputs/apk/debug/*.apk
```

**Docker**:
```bash
docker build -f dockers/linux.Dockerfile -t linux-builder .
docker build -f dockers/android.Dockerfile -t android-builder .
```

---

## 架构设计

### 目标架构

原项目深度耦合 Cocos2d-x，现重构为三层：

```
┌─────────────────────────────────┐
│         Flutter UI 层           │  ← Dart FFI 调用 C-API
├─────────────────────────────────┤
│     C-API（扁平接口层）          │  ← 稳定的跨语言边界
├─────────────────────────────────┤
│      C++ 引擎核心（backend/）    │  ← 独立编译，无平台依赖
│  ┌──────────┬──────────────┐    │
│  │  TJS2    │  渲染抽象    │    │
│  │  脚本    │  IRenderer   │    │
│  │  引擎    │  IWindow     │    │
│  └──────────┴──────────────┘    │
└─────────────────────────────────┘
```

### 目录结构（当前）

```
KrKr2-Revived/
├── backend/
│   ├── core/                  ← 纯 C++ 引擎核心（无平台依赖）
│   │   ├── tjs2/              ← TJS2 脚本引擎
│   │   ├── base/              ← 存档、事件、脚本调度等核心逻辑
│   │   ├── visual/            ← 图层、窗口接口（含 gl/）
│   │   ├── sound/             ← 音频接口
│   │   ├── utils/             ← 工具库（编码、iconv 等）
│   │   ├── environ/           ← 环境抽象（含 ConfigManager/）
│   │   ├── movie/             ← 视频播放（ffmpeg）
│   │   ├── plugin/            ← 插件框架（PluginIntf, ncbind）
│   │   ├── extension/         ← 扩展框架
│   │   └── common/            ← 公共头文件
│   ├── include/               ← 对外公共头文件
│   ├── plugins/               ← 具体插件（steam, psbfile, psdfile 等）
│   ├── external/              ← 第三方库（libbpg, minizip legacy）
│   └── platform/
│       ├── legacy_cocos2d/    ← 原 cocos2d 渲染实现（待替换）
│       └── environ_legacy/    ← 各平台实现（win32/ apple/ android/ linux/ sdl/）
├── platforms/                 ← 平台工程（Android Gradle 等）
├── doc/                       ← 文档
├── scripts/                   ← 构建脚本
├── tests/                     ← 测试
└── CMakeLists.txt
```

### 技术选型

| 层次 | 当前 | 目标 |
|------|------|------|
| 脚本引擎 | TJS2 | TJS2（保留） |
| 渲染 | Cocos2d-x | `IRenderer` 接口 + SDL3/bgfx/Metal |
| 输入 | SDL2 | SDL3 |
| 音频 | 待定 | miniaudio / SDL3 |
| 包管理 | vcpkg manifest | vcpkg manifest |
| UI | Cocos Studio | Flutter + Dart FFI |

---

## 重构进度

> 详细任务记录见 [doc/refactor_tasks.md](./doc/refactor_tasks.md)

### 阶段一：核心解耦 ✅ 已完成

- [x] 建立 `backend/` 目录结构
- [x] 将 `cpp/core` → `backend/core`
- [x] 将 `cpp/plugins` → `backend/plugins`
- [x] 将 `cpp/external` → `backend/external`
- [x] 清理废弃目录（`cpp/`, `ui/`, 旧构建目录）

### 阶段二：核心模块独立编译 ✅ 已完成

已通过编译（macOS arm64）：
- [x] `tjs2` ✅
- [x] `core_utils_module` ✅
- [x] `core_base_module` ✅

### 阶段三：Rust 底层重构 ✅ 阶段性完成

- [x] Phase 3b: C++ 侧封装适配与双向通讯绑定 (CXX)
- [x] Phase 3c: 加密库 (krkr2-crypto crate) 迁移
- [x] Phase 3d: 核心数据反序列化与渲染逻辑 (krkr2-image crate)
- [x] Phase 3e: XP3 核心封包与 I/O 层架构 (krkr2-archive crate)
- [x] Phase 3f: 音频缓冲管理与环形队列 (krkr2-audio crate) ✅

### 阶段四：渲染方案重写 ⬜ 待开始

- [ ] 实现 `IRenderer` / `IWindow` SDL3/SDL2 后端
- [ ] 图层位图硬件加速合成
- [ ] 输入事件接入
- [ ] Live2D 插件迁移到新渲染管线

### 阶段四：Flutter UI 整合 ⬜ 待开始

- [ ] 初始化 Flutter `frontend/` 工程
- [ ] Dart FFI 绑定 C-API
- [ ] 用 Flutter 重写主菜单、控制台、文件选择器
- [ ] CI/CD 全平台自动编译

---

## 代码格式化

使用 `clang-format@20`：

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

## 支持的游戏

游戏兼容列表：[doc/support_games.txt](./doc/support_games.txt)

插件资源：[wamsoft GitHub 仓库](https://github.com/orgs/wamsoft/repositories?type=all)

---

## 许可证

本项目遵循 **GNU General Public License v3.0** 许可证。详细信息请参阅 [LICENSE](./LICENSE) 文件。
