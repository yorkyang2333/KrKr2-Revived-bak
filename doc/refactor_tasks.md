# KrKr2-Revived 重构进度文档

> 最后更新：2026-03-22

---

## 一、总体目标

将 KrKr2-Revived 从一个深度耦合 Cocos2d-x 的老旧架构，改造成**跨全平台（Windows / macOS / Linux / iOS / Android）**的现代化 Visual Novel 引擎。核心思路：

- **底层（C++ 引擎）**：彻底剥离 Cocos2d-x，编译为独立的静态/动态库，通过扁平 C-API 向外暴露接口
- **渲染层**：抽象为 `IRenderer` / `IWindow` 接口，将来对接 SDL3 / bgfx / Metal / Vulkan
- **UI 层**：使用 Flutter 重写全部界面，通过 Dart FFI 调用底层 C-API

---

## 二、架构重构方案（已定）

### 新目录结构

```
KrKr2-Revived/
├── backend/
│   ├── core/              ← 纯 C++ 引擎核心（无平台依赖）
│   │   ├── tjs2/          ← TJS2 脚本引擎
│   │   ├── base/          ← 存档、事件、脚本调度等核心逻辑
│   │   ├── visual/        ← 图层、窗口接口（含 gl/ 子目录）
│   │   ├── sound/         ← 音频接口
│   │   ├── utils/         ← 工具库（编码、iconv、win32 variant）
│   │   ├── environ/       ← 环境抽象接口（含 ConfigManager/）
│   │   ├── movie/         ← 视频播放（ffmpeg）
│   │   ├── plugin/        ← 插件框架（PluginIntf, ncbind）
│   │   ├── extension/     ← 扩展框架
│   │   └── common/        ← 公共头文件
│   ├── include/           ← 对外公共头文件
│   ├── plugins/           ← 具体插件实现（steam, psbfile, psdfile, motionplayer 等）
│   ├── external/          ← 第三方库（libbpg, minizip legacy）
│   └── platform/
│       ├── legacy_cocos2d/    ← 原 cocos2d 渲染实现（待逐步替换）
│       └── environ_legacy/    ← 原平台实现
│           ├── win32/
│           ├── apple/
│           ├── android/
│           ├── linux/
│           ├── sdl/
│           └── ui/
├── doc/                   ← 本文档
└── CMakeLists.txt
```


### 技术选型
| 层次 | 技术方案 |
|------|---------|
| 脚本引擎 | TJS2（保留） |
| 渲染抽象 | `IRenderer` / `IWindow` 纯虚接口，将来对接 SDL3/bgfx/Metal |
| 输入 | SDL2（当前）→ SDL3（目标） |
| 音频 | 待定（miniaudio 或 SDL3 audio） |
| 包管理 | vcpkg manifest 模式 |
| 构建 | CMake 3.19+，Ninja |
| UI | Flutter + Dart FFI |

---

## 三、详细实施计划

### 第一阶段：Core Decoupling ✅ 已完成

| 任务 | 状态 |
|------|------|
| 创建 `backend/` 目录结构 | ✅ |
| 将 `cpp/core` 迁移到 `backend/core` | ✅ |
| 将 `cpp/plugins` 迁移到 `backend/plugins` | ✅ |
| 将 `cpp/external` 迁移到 `backend/external` | ✅ |
| 将 `environ/cocos2d` 实现移入 `backend/platform/legacy_cocos2d` | ✅ |
| 定义 C-API 抽象接口头文件（`backend/c_api/`） | ✅ |
| 配置 CMake 使 `backend/core` 可独立编译 | ✅ |
| 清理旧目录：删除 `cpp/`、`ui/`、旧构建目录和调试日志 | ✅ |

### 第二阶段：使 Core Modules 独立编译 ✅ 已完成

#### 已完成

| 任务 | 说明 |
|------|------|
| `tjs2` 模块独立编译通过 | ✅ 无 Warning |
| `core_utils_module` 独立编译通过 | ✅ |
| `core_base_module` 独立编译通过 | ✅（部分文件暂时排除，见下） |
| 将 `LayerImpl.h/cpp` 迁移到 `core/visual/` | ✅ |
| 将 `WindowImpl.h/cpp` 迁移到 `core/visual/` | ✅ |
| 将 `BitmapInfomation.h/cpp` 迁移到 `core/visual/` | ✅ |
| 将 `DrawDevice.h`, `LayerBitmapImpl.h` 迁移到 `core/visual/` | ✅ |
| 将 `ApplicationSpecialPath.h` 迁移到 `core/environ/` | ✅ |
| 将 `SoundBufferBaseImpl.h` 迁移到 `core/sound/` | ✅ |
| 从 `core_base_module` 移除平台相关 `impl/*.cpp` 文件 | ✅ |
| 添加 `minizip-ng` 到 `vcpkg.json` 并配置 CMake | ✅ |
| 修复 `WindowImpl.h` 中对 `TVPWindow.h`（win32）的依赖 | ✅ |
| 通过前向声明 + 枚举定义解决 `tTVPWMRRegMode` 问题 | ✅ |
| 添加 `visual`, `environ`, `sound`, `plugin`, `movie`, `extension` 到包含路径 | ✅ |
| `base/ScriptMgnIntf.cpp` 独立编译通过 | ✅（通过分别给 `CDDA`, `MIDI`, `Wave`, `MenuItem`, `VideoOvl`, `BasicDrawDevice` 添加跨平台空实现/接口） |
| 修复 `tjsInterCodeGen.h` UB及 `UtilStreams.cpp` 移位溢出警告 | ✅ |
| `base/ZIPArchive.cpp` 移植到 minizip-ng 公开 API | ✅（完全重写，去除 2000 行 unzip 内部实现分支，改用 `unzOpen2_64` / `unzGoToFirstFile` / `unzGetFilePos64` 等公开接口） |

#### 暂时排除（TODO）

暂无。`core_base_module` 中所有非跨平台源文件均已成功编译。

#### 已知编译 Warning（非致命）

- `tjs2/tjsBinarySerializer.h` — `ULONG_MAX` 与 `tjs_uint` 的永真比较 ✅ 已修复（改为 `UINT32_MAX`）

### 第三阶段：Rust 重构底层组件 🔄 进行中

#### Phase 3a — FFI 基础设施 + 试点模块 ✅ 已完成

| 任务 | 状态 |
|------|------|
| 创建 `backend/rust/` Cargo workspace | ✅ |
| CMake Corrosion 集成（FetchContent v0.5.1） | ✅ |
| `krkr2-crypto` crate：替代 `md5.c` + `Random.cpp` | ✅ |
| `krkr2-fft` crate：替代 `RealFFT_Default.cpp`（Ooura FFT 移植） | ✅ |
| cbindgen 自动生成 C 头文件 | ✅ |
| Rust 单元测试（6/6 通过） | ✅ |
| CMake 全量编译验证（tjs2 + core_utils_module + core_base_module） | ✅ |

#### Phase 3b — 编码层 ✅ 已完成

| 任务 | 状态 |
|------|------|
| `krkr2-encoding` crate（encoding_rs 封装） | ✅ |
| 替换 `CharacterSet.cpp` + `gbk2unicode.c` + `jis2unicode.c`（~889KB） | ✅ |

#### Phase 3c — cxx bridge 基础设施 ⬜ 待开始

> **策略升级**：剩余模块与 C++ 引擎核心类型耦合较深（`tTJSBinaryStream`、`ttstr`），需要使用 [cxx](https://cxx.rs/) bridge 进行双向绑定，而非 `extern "C"` FFI。

| 任务 | 状态 |
|------|------|
| 创建 `krkr2-bridge` crate，声明核心 C++ 类型绑定 | ⬜ |
| 桥接 `tTJSBinaryStream`（Read/Write/Seek/GetSize） | ⬜ |
| 桥接 `ttstr` ↔ `rust::String` 互转 | ⬜ |
| CMake 集成 cxx 生成的 C++ 源文件编译 | ⬜ |

#### Phase 3d — 图像解码器（via cxx bridge） ⬜ 待开始

| 任务 | 状态 |
|------|------|
| `krkr2-image` crate：TLG5/6 解码器 Rust 重写 | ⬜ |
| 通过 cxx bridge 读取 `tTJSBinaryStream`，回调 scanline | ⬜ |
| 替换 `LoadTLG.cpp` | ⬜ |

#### Phase 3e — 存档层（via cxx bridge） ⬜ 待开始

| 任务 | 状态 |
|------|------|
| `krkr2-archive` crate：XP3 解析 + xp3filter | ⬜ |
| 通过 cxx bridge 实现 `tTVPArchive` 子类 | ⬜ |
| 替换 `XP3Archive.cpp` + `xp3filter.cpp` | ⬜ |

#### Phase 3f — 音频缓冲管理（via cxx bridge） ⬜ 待开始

| 任务 | 状态 |
|------|------|
| `krkr2-audio` crate：RingBuffer + WaveSegmentQueue | ⬜ |
| 通过 cxx bridge 实现 `tTVPWaveDecoder` 接口 | ⬜ |

### 第四阶段：渲染层与输入层重写 ⬜ 待开始

| 任务 | 状态 |
|------|------|
| 实现 `IRenderer` 接口的 SDL3/SDL2 后端 | ⬜ |
| 实现 `IWindow` 接口的跨平台窗口管理 | ⬜ |
| 图层位图（Layer Bitmap）硬件加速合成 | ⬜ |
| 对接触摸/鼠标输入事件到引擎 | ⬜ |
| 端口 Live2D 插件到新渲染管线 | ⬜ |

### 第四阶段：Flutter UI 整合 ⬜ 待开始

| 任务 | 状态 |
|------|------|
| `flutter create` 初始化 `frontend/` 工程 | ⬜ |
| Dart FFI 绑定 C-API | ⬜ |
| 实现 Flutter Texture 渲染（Metal/GL/Vulkan 共享纹理） | ⬜ |
| 用 Flutter 重写主菜单、控制台、文件选择器 | ⬜ |
| GitHub Actions CI/CD 全平台自动编译打包 | ⬜ |

---

## 四、关键文件改动记录

### `vcpkg.json`
- 添加了 `minizip-ng` 依赖

### `backend/core/base/CMakeLists.txt`
- 移除了 `impl/` 下所有平台实现文件
- 暂时注释了 `ZIPArchive.cpp`
- 重新启用了 `ScriptMgnIntf.cpp` 的编译
- 添加了 `minizip-ng` 的 `find_package` + `target_link_libraries`
- 添加了 `../visual`, `../environ`, `../sound`, `../plugin`, `../movie`, `../extension` 的头文件包含路径

### `backend/core/` 下的空实现解耦（新增）
- 新增 `sound/CDDAImpl.h`, `sound/MIDIImpl.h`, `sound/WaveImpl.h` 空实现
- 新增 `visual/VideoOvlImpl.h`, `visual/MenuItemImpl.h`, `visual/BasicDrawDevice.h` 空实现（剥离原 win32/legacy_cocos2d 平台特有依赖）

### `backend/core/utils/CMakeLists.txt`
- 添加了 `../visual`, `../environ` 的头文件包含路径
- 移除了直接链接 `core_environ_module`

### `backend/core/visual/WindowImpl.h`
- 用前向声明 `class iWindowLayer;` 替换 `#include "TVPWindow.h"`
- 添加 `enum tTVPWMRRegMode { wrmRegister = 0, wrmUnregister = 1 };`

### `backend/core/base/ZIPArchive.cpp`（重写）
- 去除了 2000+ 行的 minizip `unzip.c` 内部实现分支（fork）
- 改为仅使用 minizip-ng 暴露的公开兼容 API：`unzOpen2_64`, `unzGoToFirstFile`, `unzGoToNextFile`, `unzGetFilePos64`, `unzGoToFilePos64`, `unzGetCurrentFileInfo64`, `unzOpenCurrentFile`, `unzReadCurrentFile`, `unzCloseCurrentFile`
- 对于 Stored 存储方式的文件，通过读取 local header 的 filename/extra 长度字段直接构造 `TArchiveStream`（零拷贝）
- 对于压缩文件，通过 `unzOpenCurrentFile` / `unzReadCurrentFile` 解压到 `tTVPMemoryStream`

### `backend/core/base/CMakeLists.txt`（变更）
- 重新启用了 `ZIPArchive.cpp` 编译（去掉注释）

### `CMakeLists.txt`（根目录）
- `KRKR2PLUGIN_PATH` 从 `cpp/plugins` 更新为 `backend/plugins`

### 目录清理（2026-03-22）
- 删除：`build/`, `build-fast/`, `build-refactor/`（旧构建目录，~399MB）
- 删除：`build_base*.log`, `cmake_*.log`（调试日志）
- 删除：`vcpkg.json.bak`
- 删除：`cpp/`（内容已全量迁移到 `backend/`）
- 删除：`ui/`（Cocos Studio 工程，已弃用）

### Rust 基础设施接入（2026-03-27）
- 新增 `backend/rust/` 目录存放 Rust 源码
- `CMakeLists.txt` 集成 Corrosion，支持 CMake ↔ Cargo 联编
- `.gitignore` 排除 `target/` 和生成的 C 头文件
- **试点替换**：`md5.c`, `Random.cpp`, `RealFFT_Default.cpp` 已彻底从 utils 模块中移除，改为链接 Rust 静态库


---

## 五、构建验证

```bash
# 当前已验证通过（macOS arm64）
cmake --build out/macos/debug --target tjs2
cmake --build out/macos/debug --target core_utils_module
cmake --build out/macos/debug --target core_base_module
# → 输出：ninja: no work to do.（编译成功）
```

---

## 六、下一步建议

1. **Phase 3c: cxx bridge 基础设施**：建立 `krkr2-bridge` crate，为 `tTJSBinaryStream`/`ttstr` 提供 Rust 绑定。
2. **Phase 3d: TLG 图像解码器**：用 Rust 重写 TLG5/6 解码器（Kirikiri 特有格式，安全收益最大）。
3. **Phase 3e: XP3 存档层**：用 Rust 重写 XP3 解析 + xp3filter（特有格式 + 密码学）。
4. **第四阶段：渲染与输入重写**：在底层逻辑加固后，启动 SDL3 接入。


---

## 七、已知遗留问题（技术债）

| 问题 | 位置 | 原因 |
|------|------|------|
| 大量 Win32 API 调用 | `platform/environ_legacy/win32/` | 原始代码强依赖 Windows |
| `lseek64` 等 POSIX 扩展调用 | `base/impl/StorageImpl.cpp` | 需要跨平台替换 |
| Live2D OpenGL ES2/ANGLE 问题 | `platform/legacy_cocos2d/` | 见独立 issue |
