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

### 第二阶段：使 Core Modules 独立编译 🔄 进行中

#### 已完成

| 任务 | 说明 |
|------|------|
| `tjs2` 模块独立编译通过 | ✅ 有若干 Warning（已知，待后续修复） |
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
| 添加 `visual`, `environ`, `sound` 到包含路径 | ✅ |

#### 暂时排除（TODO）

| 文件 | 原因 | 优先级 |
|------|------|--------|
| `base/ZIPArchive.cpp` | 内部重新实现了 minizip 所有数据结构，与 minizip-ng 的 API 存在深层不兼容（`zlib_filefunc64_32_def` 已废弃、`offset_curfile` 改名为 `disk_offset`、函数重载冲突等） | 中 |
| `base/ScriptMgnIntf.cpp` | 依赖 `CDDAImpl.h`（位于 `platform/win32/`，是 Win32 CD-DA 音频的平台实现） | 中 |

#### 已知编译 Warning（非致命）

- `tjs2/tjsInterCodeGen.h:213` — 解引空指针绑定到引用（原始代码遗留）
- `tjs2/tjsBinarySerializer.h` — `ULONG_MAX` 与 `tjs_uint` 的永真比较（类型宽度问题）
- `base/UtilStreams.cpp:811` — `UnpSizeHigh << 32` 移位溢出（Win32 只有 32 位 `DWORD`）

### 第三阶段：渲染层与输入层重写 ⬜ 待开始

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
- 暂时注释了 `ZIPArchive.cpp` 和 `ScriptMgnIntf.cpp`
- 添加了 `minizip-ng` 的 `find_package` + `target_link_libraries`
- 添加了 `../visual`, `../environ`, `../sound` 的头文件包含路径

### `backend/core/utils/CMakeLists.txt`
- 添加了 `../visual`, `../environ` 的头文件包含路径
- 移除了直接链接 `core_environ_module`

### `backend/core/visual/WindowImpl.h`
- 用前向声明 `class iWindowLayer;` 替换 `#include "TVPWindow.h"`
- 添加 `enum tTVPWMRRegMode { wrmRegister = 0, wrmUnregister = 1 };`

### `backend/core/base/ZIPArchive.cpp`
- 修改 `#include <minizip/unzip.h>` → `#include <unzip.h>`
- 添加 minizip-ng compat 层（`typedef`, `#define offset_curfile disk_offset` 等）
- 移除了与 minizip-ng 头文件冲突的 `unz_file_info64_s` 结构体重定义
- **注意**：由于 API 深层不兼容，该文件已从构建中暂时排除

### `CMakeLists.txt`（根目录）
- `KRKR2PLUGIN_PATH` 从 `cpp/plugins` 更新为 `backend/plugins`

### 目录清理（2026-03-22）
- 删除：`build/`, `build-fast/`, `build-refactor/`（旧构建目录，~399MB）
- 删除：`build_base*.log`, `cmake_*.log`（调试日志）
- 删除：`vcpkg.json.bak`
- 删除：`cpp/`（内容已全量迁移到 `backend/`）
- 删除：`ui/`（Cocos Studio 工程，已弃用）

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

1. **优先**：移植 `ZIPArchive.cpp` 使用 minizip-ng 的原生 API（`mz_zip.h` / `mz_strm.h`）
2. **随后**：解决 `ScriptMgnIntf.cpp` 的 `CDDAImpl.h` 平台依赖——可以用空实现或 SDL 音频替换
3. **修复编译 Warning**：特别是 `tjsBinarySerializer.h` 中 `ULONG_MAX` 的类型宽度问题
4. **启动第三阶段**：着手 SDL3/SDL2 渲染后端接入

---

## 七、已知遗留问题（技术债）

| 问题 | 位置 | 原因 |
|------|------|------|
| 大量 Win32 API 调用 | `platform/environ_legacy/win32/` | 原始代码强依赖 Windows |
| `lseek64` 等 POSIX 扩展调用 | `base/impl/StorageImpl.cpp` | 需要跨平台替换 |
| Live2D OpenGL ES2/ANGLE 问题 | `platform/legacy_cocos2d/` | 见独立 issue |
| `tjs2` 中空指针解引 Warning | `tjsInterCodeGen.h:213` | 历史遗留，有 UB 风险 |
