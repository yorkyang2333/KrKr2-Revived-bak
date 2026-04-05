#include "../../../include/krkr2_api.h"
#include "../../../include/krkr2_renderer.h"
#include <string>
#include <unordered_map>
#include <vector>
#include <mutex>
#include <algorithm>
#include <cctype>
#include <string_view>
#include <condition_variable>
#include <chrono>
#include <deque>
#include <functional>
#include <SDL3/SDL.h>

#include "tjsCommHead.h"
#include "tjsString.h"
#include "Application.h"
#include "DebugIntf.h"
#include "PluginImpl.h"
#include "EventIntf.h"
#include "WindowIntf.h"
#include "tvpinputdefs.h"
#include "vkdefine.h"
#include "../../../core/visual/IWindow.h"
#include "../../../core/visual/IRenderer.h"
#include "../../../core/visual/GraphicsLoaderIntf.h"

// Basic headless window implementation
class KrKr2HeadlessWindow : public IWindow {
public:
    KrKr2HeadlessWindow() {}
    ~KrKr2HeadlessWindow() override {}

    void SetTitle(const std::string& title) override {}
    void SetSize(int width, int height) override { w = width; h = height; }
    void SetVisible(bool visible) override {}
    void SetFullScreen(bool fullscreen) override {}
    int GetWidth() const override { return w; }
    int GetHeight() const override { return h; }
    bool IsVisible() const override { return true; }
    void* GetNativeHandle() const override { return nullptr; }

    void SetWidth(int width) override { w = width; }
    void SetHeight(int height) override { h = height; }
    void SetLeft(int l) override {}
    int  GetLeft() const override { return 0; }
    void SetTop(int t) override {}
    int  GetTop() const override { return 0; }
    void SetPosition(int x, int y) override {}
    
    void SetMinWidth(int v) override {}
    int  GetMinWidth() const override { return 0; }
    void SetMinHeight(int v) override {}
    int  GetMinHeight() const override { return 0; }
    void SetMinSize(int w, int h) override {}
    void SetMaxWidth(int v) override {}
    int  GetMaxWidth() const override { return 0; }
    void SetMaxHeight(int v) override {}
    int  GetMaxHeight() const override { return 0; }
    void SetMaxSize(int w, int h) override {}
    
    void SetFullScreenMode(bool b) override {}
    bool GetFullScreenMode() override { return false; }
    void GetCaption(std::string& v) const override {}
    void SetCaption(const std::string& v) override {}
    void SetVisibleFromScript(bool s) override {}
    bool GetVisible() const override { return true; }
    void SetStayOnTop(bool b) override {}
    bool GetStayOnTop() const override { return false; }
    
    void GetCursorPos(int& cx, int& cy) override { cx = mX; cy = mY; }
    void SetCursorPos(int x, int y) override { mX = x; mY = y; }
    void SetMouseCursorState(eIWindowMouseCursorState mcs) override {}
    eIWindowMouseCursorState GetMouseCursorState() const override { return imcsVisible; }
    
    void BringToFront() override {}
    void Close() override {}
    void SendCloseMessage() override {}
    void TickBeat() override {}

private:
    int w = 800;
    int h = 600;
    int mX = 0;
    int mY = 0;
};

// Forward declaration of tTJSNI_Window (defined in WindowImpl.cpp)
class tTJSNI_Window;

std::shared_ptr<IWindow> TVPCreateAndAddWindow(tTJSNI_Window* /*w*/) {
    return std::make_shared<KrKr2HeadlessWindow>();
}

static krkr2_log_callback_t g_logCallback = nullptr;
static std::string g_gamePath;
static std::unordered_map<std::string, std::string> g_globalOptions;
static std::unordered_map<std::string, std::string> g_currentGameOptions;
static std::mutex g_optionMutex;

#include <thread>
#include <atomic>
#include <queue>

static std::thread            g_engineThread;
static std::mutex             g_engineCommandMutex;
static std::condition_variable g_engineCommandCv;
static std::deque<std::function<void()>> g_engineCommandQueue;
static std::atomic<bool>      g_engineStopRequested{false};
static std::atomic<int>       g_startupState{KRKR2_STARTUP_IDLE};
static std::atomic<bool>      g_firstFrameReady{false};
static std::atomic<int>       g_windowWidth{0};
static std::atomic<int>       g_windowHeight{0};
static std::atomic<int>       g_windowCount{0};
static std::mutex             g_errorMutex;
static std::string            g_lastErrorMessage;
static std::mutex             g_startupStepMutex;
static std::string            g_lastStartupStep = "Idle";
static tjs_uint32             g_inputShiftState = 0;
static tjs_uint32             g_inputMouseButtonState = 0;

// ---------------------------------------------------------------------------
// Thread-safe log queue
// ---------------------------------------------------------------------------
// krkr2_log_hook is called from the C++ startup background thread.
// g_logCallback is a Dart NativeCallable.isolateLocal — it may ONLY be
// invoked from the Dart isolate thread.  Therefore we never call it directly
// from the background thread; instead we buffer the message here and flush
// the queue inside krkr2_tick(), which is always called on the Dart thread.
static std::mutex             g_logMutex;
static std::queue<std::string> g_logQueue;

static void krkr2_set_startup_state(krkr2_startup_state_t state) {
    g_startupState.store(static_cast<int>(state), std::memory_order_release);
}

static void krkr2_set_startup_step(std::string step) {
    std::lock_guard<std::mutex> lock(g_startupStepMutex);
    g_lastStartupStep = std::move(step);
}

static std::string krkr2_get_startup_step_copy() {
    std::lock_guard<std::mutex> lock(g_startupStepMutex);
    return g_lastStartupStep;
}

static void krkr2_set_last_error_message(const std::string &message) {
    std::lock_guard<std::mutex> lock(g_errorMutex);
    g_lastErrorMessage = message;
}

static void krkr2_clear_last_error_message() {
    std::lock_guard<std::mutex> lock(g_errorMutex);
    g_lastErrorMessage.clear();
}

static std::string krkr2_get_last_error_copy() {
    std::lock_guard<std::mutex> lock(g_errorMutex);
    return g_lastErrorMessage;
}

static std::string krkr2_build_diagnostic_message(std::string_view message) {
    std::string combined(message.empty() ?
                             "Engine reported an unspecified fatal error." :
                             std::string(message));
    const std::string step = krkr2_get_startup_step_copy();
    if(!step.empty() && step != "Idle" && step != "Startup complete" &&
       step != "Engine running") {
        combined += "\nLast startup step: " + step;
    }

    const std::vector<std::string> pluginFailures =
        TVPGetPluginFailureLogSnapshot();
    if(!pluginFailures.empty()) {
        combined += "\nPlugin failures: ";
        for(size_t index = 0; index < pluginFailures.size(); ++index) {
            if(index != 0) {
                combined += ", ";
            }
            combined += pluginFailures[index];
        }
    }

    return combined;
}

static void krkr2_record_engine_error(std::string_view message) {
    krkr2_set_last_error_message(krkr2_build_diagnostic_message(message));
    krkr2_set_startup_state(KRKR2_STARTUP_FAILED);
}

static void krkr2_reset_startup_tracking() {
    krkr2_clear_last_error_message();
    TVPClearPluginFailureLog();
    g_firstFrameReady.store(false, std::memory_order_release);
    g_windowWidth.store(0, std::memory_order_release);
    g_windowHeight.store(0, std::memory_order_release);
    g_windowCount.store(0, std::memory_order_release);
    krkr2_set_startup_step("Queued startup");
    krkr2_set_startup_state(KRKR2_STARTUP_STARTING);
}

static void krkr2_update_window_size(int width, int height) {
    if(width > 0) {
        g_windowWidth.store(width, std::memory_order_release);
    }
    if(height > 0) {
        g_windowHeight.store(height, std::memory_order_release);
    }
}

static bool krkr2_try_get_option(const std::string &key, std::string &value) {
    std::lock_guard<std::mutex> lock(g_optionMutex);
    auto current = g_currentGameOptions.find(key);
    if (current != g_currentGameOptions.end()) {
        value = current->second;
        return true;
    }
    auto global = g_globalOptions.find(key);
    if (global != g_globalOptions.end()) {
        value = global->second;
        return true;
    }
    return false;
}

static void krkr2_set_option(
    std::unordered_map<std::string, std::string> &target,
    const char *key,
    const char *value
) {
    if (!key || !value) return;
    std::lock_guard<std::mutex> lock(g_optionMutex);
    target[key] = value;
}

static bool krkr2_parse_bool_value(const std::string &value, bool defVal) {
    std::string normalized = value;
    std::transform(
        normalized.begin(),
        normalized.end(),
        normalized.begin(),
        [](unsigned char c) { return static_cast<char>(std::tolower(c)); }
    );
    if (normalized == "1" || normalized == "true" || normalized == "yes" ||
        normalized == "on") {
        return true;
    }
    if (normalized == "0" || normalized == "false" || normalized == "no" ||
        normalized == "off") {
        return false;
    }
    return defVal;
}

static void krkr2_log_hook(const ttstr &line) {
    // Buffer the log message — safe to call from any thread.
    std::lock_guard<std::mutex> lk(g_logMutex);
    g_logQueue.push(line.AsStdString());
}

// Flush buffered log messages.  Must be called from the Dart thread.
static void krkr2_flush_logs() {
    if (!g_logCallback) return;
    std::queue<std::string> tmp;
    {
        std::lock_guard<std::mutex> lk(g_logMutex);
        tmp.swap(g_logQueue);
    }
    while (!tmp.empty()) {
        g_logCallback(0, tmp.front().c_str());
        tmp.pop();
    }
}

extern "C" void krkr2_report_startup_step(const char* message);
extern "C" void krkr2_report_engine_error(const char* message);

static void krkr2_queue_engine_task(std::function<void()> task) {
    {
        std::lock_guard<std::mutex> lock(g_engineCommandMutex);
        g_engineCommandQueue.push_back(std::move(task));
    }
    g_engineCommandCv.notify_one();
}

static tTJSNI_Window* krkr2_get_primary_window_instance() {
    if(TVPGetWindowCount() <= 0) {
        return nullptr;
    }
    return TVPGetWindowListAt(TVPGetWindowCount() - 1);
}

static tTVPMouseButton krkr2_map_mouse_button(int button) {
    switch(button) {
        case 1:
            return mbRight;
        case 2:
            return mbMiddle;
        case 3:
            return mbX1;
        case 4:
            return mbX2;
        case 0:
        default:
            return mbLeft;
    }
}

static tjs_uint32 krkr2_mouse_button_flag(int button) {
    switch(button) {
        case 1:
            return TVP_SS_RIGHT;
        case 2:
            return TVP_SS_MIDDLE;
        default:
            return TVP_SS_LEFT;
    }
}

static void krkr2_update_modifier_state(int keycode, bool pressed) {
    tjs_uint32 flag = 0;
    switch(keycode) {
        case VK_SHIFT:
        case VK_LSHIFT:
        case VK_RSHIFT:
            flag = TVP_SS_SHIFT;
            break;
        case VK_CONTROL:
        case VK_LCONTROL:
        case VK_RCONTROL:
            flag = TVP_SS_CTRL;
            break;
        case VK_MENU:
        case VK_LMENU:
        case VK_RMENU:
            flag = TVP_SS_ALT;
            break;
        default:
            break;
    }

    if(flag == 0) {
        return;
    }

    if(pressed) {
        g_inputShiftState |= flag;
    } else {
        g_inputShiftState &= ~flag;
    }
}

static void krkr2_dispatch_mouse_event(int type, int button, int x, int y) {
    tTJSNI_Window* window = krkr2_get_primary_window_instance();
    if(!window) {
        return;
    }

    switch(type) {
        case 1:
            g_inputMouseButtonState |= krkr2_mouse_button_flag(button);
            TVPPostInputEvent(new tTVPOnMouseDownInputEvent(
                window, x, y, krkr2_map_mouse_button(button),
                g_inputShiftState | g_inputMouseButtonState));
            break;
        case 2: {
            const tjs_uint32 flags = g_inputShiftState | g_inputMouseButtonState;
            TVPPostInputEvent(new tTVPOnMouseUpInputEvent(
                window, x, y, krkr2_map_mouse_button(button), flags));
            g_inputMouseButtonState &= ~krkr2_mouse_button_flag(button);
            break;
        }
        case 3:
            TVPPostInputEvent(new tTVPOnMouseOutOfWindowInputEvent(window));
            TVPPostInputEvent(new tTVPOnMouseLeaveInputEvent(window));
            break;
        case 0:
        default:
            TVPPostInputEvent(new tTVPOnMouseMoveInputEvent(
                window, x, y, g_inputShiftState | g_inputMouseButtonState),
                TVP_EPT_DISCARDABLE | TVP_EPT_REMOVE_POST);
            break;
    }
}

static void krkr2_dispatch_key_event(int type, int keycode) {
    tTJSNI_Window* window = krkr2_get_primary_window_instance();
    if(!window) {
        return;
    }

    switch(type) {
        case 1:
            krkr2_update_modifier_state(keycode, false);
            TVPPostInputEvent(new tTVPOnKeyUpInputEvent(
                window, keycode, g_inputShiftState | g_inputMouseButtonState));
            break;
        case 2:
            TVPPostInputEvent(new tTVPOnKeyPressInputEvent(
                window, static_cast<tjs_char>(keycode)));
            break;
        case 0:
        default:
            krkr2_update_modifier_state(keycode, true);
            TVPPostInputEvent(new tTVPOnKeyDownInputEvent(
                window, keycode, g_inputShiftState | g_inputMouseButtonState));
            break;
    }
}

static void krkr2_engine_thread_main() {
    TVPSetStartupStepCallback(krkr2_report_startup_step);
    TVPSetEngineErrorCallback(krkr2_report_engine_error);

    while(true) {
        std::deque<std::function<void()>> tasks;
        {
            std::unique_lock<std::mutex> lock(g_engineCommandMutex);
            const auto waitDuration =
                g_startupState.load(std::memory_order_acquire) ==
                        KRKR2_STARTUP_RUNNING
                    ? std::chrono::milliseconds(8)
                    : std::chrono::milliseconds(50);
            if(g_engineCommandQueue.empty() &&
               !g_engineStopRequested.load(std::memory_order_acquire)) {
                g_engineCommandCv.wait_for(
                    lock, waitDuration, []() {
                        return !g_engineCommandQueue.empty() ||
                            g_engineStopRequested.load(
                                std::memory_order_acquire);
                    });
            }
            tasks.swap(g_engineCommandQueue);
        }

        for(auto &task : tasks) {
            task();
        }

        if(g_engineStopRequested.load(std::memory_order_acquire)) {
            break;
        }

        if(Application &&
           g_startupState.load(std::memory_order_acquire) ==
               KRKR2_STARTUP_RUNNING) {
            Application->Run();
            g_windowCount.store(TVPGetWindowCount(), std::memory_order_release);
        }
    }

    TVPSetStartupStepCallback(nullptr);
    TVPSetEngineErrorCallback(nullptr);
}

extern "C" {

void krkr2_report_startup_step(const char* message) {
    krkr2_set_startup_step((message && *message) ? message : "Startup progress");
}

void krkr2_report_engine_error(const char* message) {
    if(message && *message) {
        krkr2_record_engine_error(message);
        return;
    }
    krkr2_record_engine_error("Engine reported an unspecified fatal error.");
}

void krkr2_set_log_callback(krkr2_log_callback_t callback) {
    g_logCallback = callback;
    TVPSetPlatformOnLog(krkr2_log_hook);
}

void krkr2_set_game_path(const char* path) {
    if (path) {
        g_gamePath = path;
    }
}

void krkr2_set_global_option(const char* key, const char* value) {
    krkr2_set_option(g_globalOptions, key, value);
}

void krkr2_set_current_game_option(const char* key, const char* value) {
    krkr2_set_option(g_currentGameOptions, key, value);
}

void krkr2_clear_current_game_option(const char* key) {
    std::lock_guard<std::mutex> lock(g_optionMutex);
    if (!key) {
        g_currentGameOptions.clear();
        return;
    }
    g_currentGameOptions.erase(key);
}

krkr2_renderer_interface_t g_krkr2_renderer_interface = {0};

void krkr2_set_renderer_interface(krkr2_renderer_interface_t* renderer) {
    if (renderer) {
        g_krkr2_renderer_interface = *renderer;
    }
}

krkr2_renderer_interface_t* krkr2_get_renderer_interface() {
    return &g_krkr2_renderer_interface;
}

void krkr2_destroy() {
    krkr2_shutdown();
}

bool krkr2_init(int argc, char** argv) {
    std::string pathStr = g_gamePath;
    if (pathStr.empty() && argc > 1 && argv[1]) {
        pathStr = argv[1];
    }
    if(pathStr.empty()) {
        krkr2_record_engine_error("No game path was configured for startup.");
        return false;
    }
    if(g_engineThread.joinable()) {
        krkr2_record_engine_error(
            "Engine thread is already active. Shutdown before starting again.");
        return false;
    }

    krkr2_reset_startup_tracking();
    g_inputShiftState = 0;
    g_inputMouseButtonState = 0;
    g_engineStopRequested.store(false, std::memory_order_release);

    try {
        g_engineThread = std::thread(krkr2_engine_thread_main);
    } catch(const std::exception& e) {
        krkr2_record_engine_error(e.what());
        return false;
    } catch(...) {
        krkr2_record_engine_error("Failed to create the engine thread.");
        return false;
    }

    krkr2_queue_engine_task([pathStr]() {
        try {
            if(!Application) {
                Application = new tTVPApplication();
            }

            ttstr path(pathStr.c_str());
            fprintf(stderr, "[KRKR2] Engine startup thread starting, path=%s\n",
                    pathStr.c_str());

            const bool ok = Application->StartApplication(path);
            if(ok) {
                krkr2_clear_last_error_message();
                krkr2_set_startup_step("Engine running");
                g_windowCount.store(TVPGetWindowCount(),
                                    std::memory_order_release);
                krkr2_set_startup_state(KRKR2_STARTUP_RUNNING);
                TVPAddImportantLog(
                    ttstr(TJS_W("[KRKR2] Startup state -> running")));
            } else {
                if(krkr2_get_last_error_copy().empty()) {
                    krkr2_set_last_error_message(krkr2_build_diagnostic_message(
                        "Engine startup returned false before the first frame "
                        "was rendered."));
                }
                krkr2_set_startup_step("Startup failed");
                krkr2_set_startup_state(KRKR2_STARTUP_FAILED);
                TVPAddImportantLog(
                    ttstr(TJS_W("[KRKR2] Startup state -> failed")));
            }

            fprintf(stderr,
                    "[KRKR2] Engine startup thread finished, result=%d\n",
                    (int)ok);
        } catch(const std::exception& e) {
            krkr2_set_startup_step("Startup failed");
            krkr2_record_engine_error(e.what());
        } catch(...) {
            krkr2_set_startup_step("Startup failed");
            krkr2_record_engine_error(
                "Engine startup threw an unknown exception.");
        }
    });

    return true;
}

void krkr2_shutdown() {
    if(g_engineThread.joinable()) {
        {
            std::lock_guard<std::mutex> lock(g_engineCommandMutex);
            g_engineStopRequested.store(true, std::memory_order_release);
            g_engineCommandQueue.push_back([]() {
                if(Application) {
                    Application->Terminate();
                    delete Application;
                    Application = nullptr;
                }
                TVPClearPluginFailureLog();
                krkr2_clear_last_error_message();
                g_firstFrameReady.store(false, std::memory_order_release);
                g_windowWidth.store(0, std::memory_order_release);
                g_windowHeight.store(0, std::memory_order_release);
                g_windowCount.store(0, std::memory_order_release);
                g_inputShiftState = 0;
                g_inputMouseButtonState = 0;
                krkr2_set_startup_step("Idle");
                krkr2_set_startup_state(KRKR2_STARTUP_IDLE);
            });
        }
        g_engineCommandCv.notify_one();
        g_engineThread.join();
    } else if(Application) {
        Application->Terminate();
        delete Application;
        Application = nullptr;
    }

    {
        std::lock_guard<std::mutex> lock(g_engineCommandMutex);
        g_engineCommandQueue.clear();
    }
    g_engineStopRequested.store(false, std::memory_order_release);
    {
        std::lock_guard<std::mutex> lock(g_optionMutex);
        g_currentGameOptions.clear();
    }
    TVPClearPluginFailureLog();
    krkr2_clear_last_error_message();
    g_firstFrameReady.store(false, std::memory_order_release);
    g_windowWidth.store(0, std::memory_order_release);
    g_windowHeight.store(0, std::memory_order_release);
    g_windowCount.store(0, std::memory_order_release);
    g_inputShiftState = 0;
    g_inputMouseButtonState = 0;
    krkr2_set_startup_step("Idle");
    krkr2_set_startup_state(KRKR2_STARTUP_IDLE);
}

void krkr2_tick() {
    krkr2_flush_logs();
}

void krkr2_push_mouse_event(int type, int button, int x, int y) {
    if(!g_engineThread.joinable()) {
        return;
    }
    krkr2_queue_engine_task(
        [type, button, x, y]() { krkr2_dispatch_mouse_event(type, button, x, y); });
}

void krkr2_push_key_event(int type, int keycode) {
    if(!g_engineThread.joinable()) {
        return;
    }
    krkr2_queue_engine_task(
        [type, keycode]() { krkr2_dispatch_key_event(type, keycode); });
}

void krkr2_push_touch_event(int type, int id, float x, float y) {
    // TODO: Forward to engine
}

int krkr2_get_window_count() {
    return g_windowCount.load(std::memory_order_acquire);
}

void* krkr2_get_primary_native_window() {
    return nullptr;
}

int krkr2_get_startup_state() {
    return g_startupState.load(std::memory_order_acquire);
}

bool krkr2_has_first_frame() {
    return g_firstFrameReady.load(std::memory_order_acquire);
}

const char* krkr2_get_last_error_message() {
    static thread_local std::string errorCopy;
    {
        std::lock_guard<std::mutex> lock(g_errorMutex);
        errorCopy = g_lastErrorMessage;
    }
    return errorCopy.c_str();
}

void krkr2_get_window_size(int* width, int* height) {
    if(width) *width = g_windowWidth.load(std::memory_order_acquire);
    if(height) *height = g_windowHeight.load(std::memory_order_acquire);
}

} // extern "C"

#include <SDL3/SDL.h>

tjs_uint32 TVPGetRoughTickCount32() {
    return (tjs_uint32)SDL_GetTicks();
}


namespace TJS {
    void TVPConsoleLog(const tTJSString &str) {
        // Console log stub
    }
}

void tTVPGraphicHandlerType::Save(const ttstr &storagename, const ttstr &mode, const iTVPBaseBitmap *image, iTJSDispatch2 *meta) {
    // Stub
}

void tTVPGraphicHandlerType::Header(TJS::tTJSBinaryStream *src, iTJSDispatch2 **dic) {
    // Stub
}

// IndividualConfigManager Stubs
#include "../../../core/environ/ConfigManager/IndividualConfigManager.h"
#include "../../../core/environ/ConfigManager/LocaleConfigManager.h"

class tTJSNC_PhaseVocoder : public tTJSNativeClass {
public:
    tTJSNC_PhaseVocoder();
};

IndividualConfigManager *IndividualConfigManager::GetInstance() {
    static IndividualConfigManager instance;
    return &instance;
}
template <>
bool IndividualConfigManager::GetValue<bool>(
    const std::string &name,
    const bool &defVal
) {
    std::string value;
    if (!krkr2_try_get_option(name, value)) {
        return defVal;
    }
    return krkr2_parse_bool_value(value, defVal);
}
template <>
int IndividualConfigManager::GetValue<int>(
    const std::string &name,
    const int &defVal
) {
    std::string value;
    if (!krkr2_try_get_option(name, value)) {
        return defVal;
    }
    try {
        return std::stoi(value);
    } catch (...) {
        return defVal;
    }
}
template <>
std::string IndividualConfigManager::GetValue<std::string>(
    const std::string &name,
    const std::string &defVal
) {
    std::string value;
    if (!krkr2_try_get_option(name, value)) {
        return defVal;
    }
    return value;
}
template <>
float IndividualConfigManager::GetValue<float>(
    const std::string &name,
    const float &defVal
) {
    std::string value;
    if (!krkr2_try_get_option(name, value)) {
        return defVal;
    }
    try {
        return std::stof(value);
    } catch (...) {
        return defVal;
    }
}
std::string IndividualConfigManager::GetFilePath() { return ""; }
std::vector<std::string> IndividualConfigManager::GetCustomArgumentsForPush() { return {}; }
bool IndividualConfigManager::CheckExistAt(const std::string &folder) { return false; }
bool IndividualConfigManager::CreatePreferenceAt(const std::string &folder) { return false; }
bool IndividualConfigManager::UsePreferenceAt(const std::string &folder) { return false; }
void IndividualConfigManager::Clear() {}

LocaleConfigManager *LocaleConfigManager::GetInstance() {
    static LocaleConfigManager instance;
    return &instance;
}
const std::string& LocaleConfigManager::GetText(const std::string &key) { 
    static std::string empty;
    return empty; 
}
std::string LocaleConfigManager::GetFilePath() { return ""; }

void TVPCauseAtInstallExtensionClass(TJS::iTJSDispatch2*) {}
tTJSNativeClass* TVPCreateNativeClass_VideoOverlay() { return new tTJSNativeClass(TJS_W("VideoOverlay")); }
tTJSNativeClass* TVPCreateNativeClass_CDDASoundBuffer() { return new tTJSNativeClass(TJS_W("CDDASoundBuffer")); }
tTJSNativeClass* TVPCreateNativeClass_MIDISoundBuffer() { return new tTJSNativeClass(TJS_W("MIDISoundBuffer")); }
tTJSNativeClass* TVPCreateNativeClass_WaveSoundBuffer() { return new tTJSNativeClass(TJS_W("WaveSoundBuffer")); }
void TVPFreeArchiveHandlePoolByPointer(void*) {}

tTJSNC_PhaseVocoder::tTJSNC_PhaseVocoder() : tTJSNativeClass(TJS_W("PhaseVocoder")) {}

#include "../../../core/visual/RenderManager.h"

iTVPRenderMethod* iTVPRenderManager::GetRenderMethod(int, bool, int) { return nullptr; }

void tTVPGraphicHandlerType::Load(void *formatdata, void *callbackdata,
          tTVPGraphicSizeCallback sizecallback,
          tTVPGraphicScanLineCallback scanlinecallback,
          tTVPMetaInfoPushCallback metainfopushcallback,
          TJS::tTJSBinaryStream *src, tjs_int32 keyidx,
          tTVPGraphicLoadMode mode) {}

LocaleConfigManager::LocaleConfigManager() {}
ttstr TVPGetPlatformName() { return ttstr(TJS_W("MacOS_Headless")); }
std::string TVPGetPackageVersionString() { return "1.0.0"; }
void TVPOpenPatchLibUrl() {}
int TVPShowSimpleMessageBox(const TJS::tTJSString&, const TJS::tTJSString&, const std::vector<TJS::tTJSString>&) { return 0; }
extern "C" int TVPShowSimpleMessageBox(const char*, const char*, unsigned int, const char**) { return 0; }
tjs_int TVPGetSystemFreeMemory() { return 1024; }
tjs_int TVPGetSelfUsedMemory() { return 0; }
ttstr TVPReadAboutStringFromResource() {
    return TJS_W("Kirikiri2 Runtime Core version %1(TJS version %2)");
}
void* TVPGetCachedArchiveHandle(void*, const TJS::tTJSString&) { return nullptr; }
void TVPReleaseCachedArchiveHandle(void*, TJS::tTJSBinaryStream*) {}

extern "C" void TVPUtf8ToWideCharString_C(const char*, char16_t*) asm("_TVPUtf8ToWideCharString");
void TVPUtf8ToWideCharString(const char* in, char16_t* out) {
    TVPUtf8ToWideCharString_C(in, out);
}

// Second batch of missing stubs
#include <functional>
namespace TJS { class tTJSVariant; class tTJSString; }
struct TVPMemoryInfo;

bool TVPAutoSaveBookMark = false;
int TVPSegmentCacheLimit = 0;

extern tjs_int TVPVersionMajor;
extern tjs_int TVPVersionMinor;
extern tjs_int TVPVersionRelease;
extern tjs_int TVPVersionBuild;

void TVPGetVersion(void) {
    TVPVersionMajor = 1;
    TVPVersionMinor = 4;
    TVPVersionRelease = 1;
    TVPVersionBuild = 20;
}

ttstr TVPGetOSName() { return ttstr(TJS_W("macOS")); }
void TVPLoadPVRv3(TJS::tTJSBinaryStream*, const std::function<void(const TJS::tTJSString&, const TJS::tTJSVariant&)>&) {}
bool TVPSelectFile(TJS::iTJSDispatch2*) { return false; }
void TVPGetMemoryInfo(TVPMemoryInfo&) {}
class tTVPWaveDecoderCreator;
void TVPRegisterWaveDecoderCreator(tTVPWaveDecoderCreator*) {}
void TVPUnregisterWaveDecoderCreator(tTVPWaveDecoderCreator*) {}
unsigned int TVPToActualColor(unsigned int c) { return c; }
unsigned int TVPFromActualColor(unsigned int c) { return c; }
void TVPExitApplication(int) {}
bool TVPGetKeyMouseAsyncState(tjs_uint, bool) { return false; }
bool TVPGetJoyPadAsyncState(tjs_uint, bool) { return false; }

#include <filesystem>
#include <fstream>
#include <vector>

bool TVPCreateFolders(const ttstr &folder) {
    try {
        return std::filesystem::create_directories(folder.AsStdString());
    } catch (...) {
        return false;
    }
}

bool TVPWriteDataToFile(const ttstr &filepath, const void *data, unsigned int len) {
    std::ofstream os(filepath.AsStdString(), std::ios::binary);
    if(!os.is_open()) return false;
    os.write(reinterpret_cast<const char*>(data), len);
    return os.good();
}

const std::vector<std::string> &TVPGetApplicationHomeDirectory() {
    static std::vector<std::string> ret{"/tmp/"};
    return ret;
}


#include <sys/stat.h>
#include "Platform.h"

bool TVP_stat(const char *name, tTVP_stat &s) {
    struct stat my_stat;
    if (stat(name, &my_stat) == 0) {
        s.st_mode = my_stat.st_mode;
        s.st_size = my_stat.st_size;
        s.st_atime = my_stat.st_atimespec.tv_sec;
        s.st_mtime = my_stat.st_mtimespec.tv_sec;
        s.st_ctime = my_stat.st_ctimespec.tv_sec;
        return true;
    }
    return false;
}

bool TVP_stat(const tjs_char *name, tTVP_stat &s) {
    std::string utf8_name = tTJSNarrowStringHolder(name).Buf;
    return TVP_stat(utf8_name.c_str(), s);
}


#include "../../../core/visual/BasicDrawDevice.h"
#include "../../../core/visual/LayerBitmapIntf.h"

// Define uninitialized ClassID for tTJSNC_BasicDrawDevice
tjs_uint32 tTJSNC_BasicDrawDevice::ClassID = (tjs_uint32)-1;

class HeadlessDrawDevice : public tTVPDrawDevice {
    krkr2_texture_t tex_ = nullptr;
    int tex_w_ = 0;
    int tex_h_ = 0;

public:
    HeadlessDrawDevice() {}

    ~HeadlessDrawDevice() override {
        if (tex_ && g_krkr2_renderer_interface.destroy_texture) {
            g_krkr2_renderer_interface.destroy_texture(tex_);
        }
    }

    void StartBitmapCompletion(iTVPLayerManager *manager) override {
        tjs_int w = 0, h = 0;
        GetSrcSize(w, h);
        if (w <= 0 || h <= 0) return;

        const int previousWidth = g_windowWidth.load(std::memory_order_acquire);
        const int previousHeight =
            g_windowHeight.load(std::memory_order_acquire);
        krkr2_update_window_size(w, h);
        if(previousWidth != w || previousHeight != h) {
            TVPAddImportantLog(
                ttstr(TJS_W("[KRKR2] Render size updated to ")) + ttstr(w) +
                TJS_W("x") + ttstr(h));
        }

        if (!tex_ || tex_w_ != w || tex_h_ != h) {
            if (tex_ && g_krkr2_renderer_interface.destroy_texture) {
                g_krkr2_renderer_interface.destroy_texture(tex_);
            }
            if (g_krkr2_renderer_interface.create_texture) {
                // Usually Kirikiri uses 32bpp. Pass 1 for format if needed.
                tex_ = g_krkr2_renderer_interface.create_texture(w, h, 1);
            }
            tex_w_ = w;
            tex_h_ = h;
        }
    }

    void NotifyBitmapCompleted(iTVPLayerManager *manager, tjs_int x, tjs_int y,
                               tTVPBaseTexture *bmp, const tTVPRect &cliprect,
                               tTVPLayerType type, tjs_int opacity) override {
        if (!tex_ || !g_krkr2_renderer_interface.update_texture || !bmp) return;
        
        // Grab the raw pixels from the primary layer buffer
        const void* pixels = bmp->GetScanLine(0);
        int pitch = bmp->GetPitchBytes();
        
        g_krkr2_renderer_interface.update_texture(tex_, pixels, pitch);
        krkr2_update_window_size(tex_w_, tex_h_);
        if(!g_firstFrameReady.exchange(true, std::memory_order_acq_rel)) {
            TVPAddImportantLog(
                ttstr(TJS_W("[KRKR2] First frame uploaded to host texture")));
        }
    }

    void EndBitmapCompletion(iTVPLayerManager *manager) override {
    }

    void Show() override {
        if (g_krkr2_renderer_interface.clear) {
            g_krkr2_renderer_interface.clear();
        }
        if (tex_ && g_krkr2_renderer_interface.draw_texture) {
            g_krkr2_renderer_interface.draw_texture(tex_, 0, 0, tex_w_, tex_h_);
        }
        if (g_krkr2_renderer_interface.present) {
            g_krkr2_renderer_interface.present();
        }
    }
};

class tTJSNI_BasicDrawDevice : public tTJSNativeInstance {
    HeadlessDrawDevice *Device;
public:
    tTJSNI_BasicDrawDevice() {
        Device = new HeadlessDrawDevice();
    }
    ~tTJSNI_BasicDrawDevice() override {
        if (Device) {
            Device->Destruct();
            delete Device;
        }
    }
    tjs_error Construct(tjs_int numparams, tTJSVariant **param, iTJSDispatch2 *tjs_obj) override {
        tTJSVariant val(static_cast<tjs_int64>(
            reinterpret_cast<tjs_intptr_t>(static_cast<iTVPDrawDevice*>(Device))));
        tjs_obj->PropSet(TJS_MEMBERENSURE, TJS_W("interface"), nullptr, &val, tjs_obj);
        return TJS_S_OK;
    }
    void Invalidate() override {
        // Device->Destruct();
    }
};

tTJSNativeInstance* tTJSNC_BasicDrawDevice::CreateNativeInstance() {
    return new tTJSNI_BasicDrawDevice();
}
