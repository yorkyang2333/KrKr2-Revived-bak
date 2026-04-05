# KrKr2-Revived 重构进度文档

> 最后更新：2026-04-05

---

## 一、总体目标

将 KrKr2-Revived 从一个深度耦合 Cocos2d-x 的老旧架构，改造成**跨全平台（Windows / macOS / Linux / iOS / Android）**的现代化 Visual Novel 引擎。核心思路：

- **底层（C++ 引擎）**：彻底剥离 Cocos2d-x，编译为独立的静态/动态库，通过扁平 C-API 向外暴露接口
- **渲染层**：抽象为 `IRenderer` / `IWindow` 接口，将来对接 SDL3 / bgfx / Metal / Vulkan
- **UI 层**：使用 Flutter 重写全部界面，通过 Dart FFI 调用底层 C-API
- **原生游戏兼容性**：无需修改直接读取并运行原版吉里吉里2游戏（`.xp3` 自动挂载、加密解密自动匹配、系统 API dummy 化）

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

#### Phase 3c — cxx bridge 基础设施 ✅ 已完成

> **策略升级**：剩余模块与 C++ 引擎核心类型耦合较深（`tTJSBinaryStream`、`ttstr`），需要使用 [cxx](https://cxx.rs/) bridge 进行双向绑定，而非 `extern "C"` FFI。

| 任务 | 状态 |
|------|------|
| 创建 `krkr2-bridge` crate，声明核心 C++ 类型绑定 | ✅ |
| 桥接 `tTJSBinaryStream`（Read/Write/Seek/GetSize） | ✅（通过 `BinaryStreamWrapper` C++ glue 转发虚函数调用） |
| 桥接 `ttstr` ↔ `rust::String` 互转 | ⏭ 延后到 Phase 3d/3e 按需实现 |
| CMake 集成 cxx 生成的 C++ 源文件编译 | ✅（`krkr2_bridge_glue` 静态库） |

#### Phase 3d — 图像解码器（via cxx bridge） ✅ 已完成

| 任务 | 状态 |
|------|------|
| `krkr2-image` crate：TLG5/6 解码器 Rust 重写 | ✅（LZSS + Golomb + 16 chroma filters + MED/AVG） |
| 通过 cxx bridge 读取 `tTJSBinaryStream`，回调 scanline | ✅（`krkr2_image_adapter` C++ 适配器） |
| 替换 `LoadTLG.cpp` → `LoadTLGHeader.cpp` + Rust decoder | ✅ |
| TLG0.0 SDS metadata tag 解析 | ✅ |
| 单元测试（7/7 passed） | ✅ |

#### Phase 3e — 存档层（via cxx bridge） ✅ 已完成

| 任务 | 状态 |
|------|------|
| `krkr2-archive` crate：XP3 解析 + flate2 zlib | ✅ |
| 通过 cxx bridge 实现 `tTVPArchive` 子类 | ✅ |
| 替换 `XP3Archive.cpp`，并在 C++ 端保留 `xp3filter` 加密逻辑 | ✅ |

#### Phase 3f — 音频缓冲管理（via cxx bridge） ✅ 已完成

| 任务 | 状态 |
|------|------|
| `RingBuffer` | 将 `RingBuffer.h` 替换为安全的 Rust 环形队列实现，支持 `cxx` 对象调用 | ✅ |
| `WaveSegmentQueue` | 将音频帧排队和片段管理替换为 Rust 实现，废除复杂的 C++ 双端队列运算 | ✅ |
| 解码器接口 FFI | 通过 `cxx` 的 Trait 对象映射，实现 `tTVPWaveDecoder` 的 Rust 框架基类 | ✅ |

### 第四阶段：渲染层与输入层重写 ✅ 已完成

| 任务 | 状态 |
|------|------|
| 将 `vcpkg.json` 中的依赖从 `sdl2` 升级为 `sdl3` | ✅ |
| 定义 `IWindow` 抽象接口（`backend/core/visual/IWindow.h`） | ✅ |
| 定义 `IRenderer` 抽象接口（`backend/core/visual/IRenderer.h`） | ✅ |
| 实现 `SDLWindow`（`backend/platform/environ_legacy/sdl/`） | ✅ （包含完整几何/全屏/光标/标题栏实现） |
| 实现 `SDLRenderer` | ✅ |
| 实现 `SDLInput`（SDL 事件 → 引擎路由） | ✅ |
| 实现 `TVPCreateAndAddWindow`（SDL 平台工厂） | ✅ (`TVPWindow_SDL.cpp`) |
| 重构 `WindowImpl.cpp`：使用 `IWindow`/`IRenderer` 代替 Win32/Cocos API | ✅ |
| 更新 `backend/platform/CMakeLists.txt` | ✅ |
| 更新 C-API：`krkr2_api.h` 和 `krkr2_renderer.h` | ✅ |

### 第五阶段：Flutter UI 整合 🚧 进行中

| 任务 | 状态 |
|------|------|
| 修复引擎底层依赖与接口隔离，支持 `BUILD_AS_LIBRARY` 无头静态编译 | ✅ |
| C-API 完善 (`krkr2_api.h`) 与无头层 `KrKr2HeadlessWindow` 实现 | ✅ |
| 引擎核心编译消除无头模式下的依赖错误 | ✅ |
| `flutter create` 初始化 `frontend/` 工程 | ✅ |
| Dart FFI 绑定 C-API | ✅ |
| 实现 Flutter Texture 渲染（Metal/GL/Vulkan 共享纹理） | ✅ |
| 用 Flutter 重写主菜单、控制台、文件选择器 | ⬜ |
| GitHub Actions CI/CD 全平台自动编译打包 | ⬜ |
| 修复 `build_all.sh` 路径 Bug（`cd frontend` 后 `find/mkdir` 路径失效） | ✅ |
| 修复 Xcode 未链接后端静态库与缺失符号（引入 `ForceFeedback` 框架、补全平台空实现、添加 brotli） | ✅ |
| 成功链接并执行 macOS Headless 构建，无依赖挂起 | ✅ |
| 修复 macOS 下 FFI 崩溃、日志不显示及因路径挂载顺序导致的黑屏死锁与启动抛错 | ✅ |
| **修复引擎启动初期黑屏崩溃异常（处理 `TVPGetAppPath()` 生命周期导致的 `[RAW: '']` 空路径访问抛出致命错误）** | ✅ |
| **Flutter UI 增强：初始化并实装日志控制台在有新数据输出时的自动吸附与滚屏至底部功能** | ✅ |
| **修复游戏目录路径因缺少 `/` 尾随斜杠引发的路径解析截断及 `TVPAutoMountArchives` POSIX 挂载失效导致的无法读取 `startup.tjs` 与 `Data path does not exist` 生成失败问题** | ✅ |
| **修复 Play 按钮点击崩溃：`StartApplication` 中调用顺序错误——`TVPNormalizeStorageName` 在 `TVPInitializeBaseSystems`（存储子系统）初始化之前被调用；以及 `TVPInitScriptEngine` 被重复调用两次（`StartApplication` Step 2 + `TVPSystemInit` 内部）导致 TJS2 引擎双重初始化崩溃** | ✅ |
| **修复 Play 按钮点击卡死：`krkr2_init` 在 Flutter UI 线程同步运行 `StartApplication`（涉及 XP3 挂载、字体扫描、TJS 脚本执行等长耗时操作），导致 Flutter 完全冻结。改为后台 `std::thread` 异步执行启动流程，`krkr2_init` 立即返回 `true`；`krkr2_tick` 通过 `g_startupDone` flag 和 `std::try_to_lock` 保证在启动完成后才驱动引擎事件循环，同时避免启动/tick 并发竞争** | ✅ |

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

### CXX Bridge 基础设施（2026-03-28）
- 新增 `backend/rust/krkr2-bridge/` crate，使用 [cxx](https://cxx.rs/) 进行 Rust ↔ C++ 双向绑定
- `krkr2_bridge_glue.h/cpp`：`BinaryStreamWrapper` C++ glue 类，持有 `tTJSBinaryStream*` 并转发虚函数调用
- `backend/rust/CMakeLists.txt` 新增 `krkr2_bridge_glue` 静态库目标
- cxx 生成的桥接头文件位于 `target/cxxbridge/` 目录

### TLG 图像解码器 Rust 重写（2026-03-28）
- 新增 `backend/rust/krkr2-image/` crate，完整重写 TLG5/6 解码器
- 纯 Rust 实现：LZSS 滑动窗口解压、Golomb-Rice 熵编码、16 种 chroma 相关滤镜、MED/AVG 像素预测
- `krkr2_image_adapter.h/cpp`：C++ 适配器，直接实现 C 接口的 `TVPLoadTLG()`
- 原有 `LoadTLG.cpp` 和 `LoadTLG.h` 已被彻底删除，原有的 header 读取逻辑单独提取到了 `LoadTLGHeader.cpp`

### XP3 存档文件系统 Rust 重写（2026-04-04）
- 新增 `backend/rust/krkr2-archive/` crate，使用 Rust `flate2` 重写 XP3 解析与解压缩引擎
- `krkr2_archive_adapter.cpp`：C++ 适配层基于 cxx bridge 对接 `tTVPXP3Archive::CreateStreamByIndex`
- 原有 `XP3Archive.cpp` (~1000 行) 已被彻底删除，极大增强了内核底层的内存安全性和并行演进能力
- 提取并保留了 C++ 中的 `TVPXP3ArchiveExtractionFilter` 回调边界，保证对旧版吉里吉里加密插件 100% 兼容
- 7 个 Rust 单元测试全部通过（LZSS、Golomb 表、MED/AVG 预测器）


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

1. ~~**Phase 3c: cxx bridge 基础设施**~~：✅ 已完成。
2. ~~**Phase 3d: TLG 图像解码器**~~：✅ 已完成。
3. ~~**Phase 3e: XP3 存档层**~~：✅ 已完成。用 Rust 重写 XP3 解析 + xp3filter（特有格式 + 密码学）。
4. **第四阶段：渲染与输入重写**：在底层逻辑加固后，启动 SDL3 接入。


### Phase 10: 原生原版游戏兼容层 (Native Compatibility Layer) ✅ 完成

- [x] XP3 游戏资源及补丁 (patch.xp3, patch2.xp3...) 自动按优先级挂载
- [x] Windows 独占不兼容插件 (如 wuvorbis.dll, util_unicode.dll 等) 黑/白名单过滤与静默容错
- [x] 对 Window、Layer、System 的 TJS2 缺失成员进行 dummy stub 降级，并支持 `TVPEnableCompatStubs` 全局开关
- [x] 基于 `RegisterData.tjs` 与 `RegistryEmulation.cpp` 的跨平台 Registry/KV 配置读取及持久化
- [x] 基于特征/Heuristic 的 XP3 文件加密自动匹配框架 (`XP3CryptoRegistry`)
- [x] `krkr2-audio` 桥接与跨平台虚拟降级音频解码实例 (`tTVPWaveDecoder_Rust`)，预防未支持音频格式静音崩溃

---

## 八、已知问题与技术债）

| 问题 | 位置 | 原因 |
|------|------|------|
| 大量 Win32 API 调用 | `platform/environ_legacy/win32/` | 原始代码强依赖 Windows |
| `lseek64` 等 POSIX 扩展调用 | `base/impl/StorageImpl.cpp` | 需要跨平台替换 |
