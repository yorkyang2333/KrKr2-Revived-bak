#include "../../../include/krkr2_api.h"
#include "../../../include/krkr2_renderer.h"
#include <string>
#include <vector>
#include <SDL3/SDL.h>

#include "tjsCommHead.h"
#include "tjsString.h"
#include "Application.h"
#include "DebugIntf.h"
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

// --- Engine thread state ---
// The engine startup (StartApplication) is a long-running, potentially
// blocking operation. We run it in a dedicated background thread so that
// Flutter's UI thread (which calls krkr2_init) is never blocked.
//
// After startup completes, krkr2_tick() drives the engine's per-frame
// event loop from Flutter's Ticker (also on the UI thread). A mutex
// serializes startup vs tick so the engine's internals (TJS event queue,
// timers) are never accessed from two threads simultaneously.
#include <thread>
#include <mutex>
#include <atomic>
#include <queue>

static std::thread            g_engineThread;
static std::mutex             g_engineMutex;
static std::atomic<bool>      g_startupDone{false};
static std::atomic<bool>      g_startupSuccess{false};

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

extern "C" {

void krkr2_set_log_callback(krkr2_log_callback_t callback) {
    g_logCallback = callback;
    TVPSetPlatformOnLog(krkr2_log_hook);
}

void krkr2_set_game_path(const char* path) {
    if (path) {
        g_gamePath = path;
    }
}

krkr2_renderer_interface_t g_krkr2_renderer_interface = {0};

void krkr2_set_renderer_interface(krkr2_renderer_interface_t* renderer) {
    if (renderer) {
        g_krkr2_renderer_interface = *renderer;
    }
}

bool krkr2_init(int argc, char** argv) {
    if (!Application) {
        Application = new tTVPApplication();
    }

    // Copy the path before starting the thread (argv may be stack-allocated)
    std::string pathStr = g_gamePath;
    if (pathStr.empty() && argc > 1 && argv[1]) {
        pathStr = argv[1];
    }

    g_startupDone    = false;
    g_startupSuccess = false;

    // Spawn the engine startup in a background thread.
    // krkr2_tick() will be a no-op until g_startupDone becomes true.
    g_engineThread = std::thread([pathStr]() {
        ttstr path(pathStr.c_str());
        fprintf(stderr, "[KRKR2] Engine startup thread starting, path=%s\n",
                pathStr.c_str());

        bool ok = false;
        {
            std::lock_guard<std::mutex> lock(g_engineMutex);
            ok = Application->StartApplication(path);
        }

        g_startupSuccess = ok;
        g_startupDone    = true;

        fprintf(stderr, "[KRKR2] Engine startup thread finished, result=%d\n",
                (int)ok);
    });
    g_engineThread.detach();

    // Return true immediately — Flutter is not blocked.
    return true;
}

void krkr2_shutdown() {
    if (Application) {
        Application->Terminate();
        delete Application;
        Application = nullptr;
    }
    g_startupDone = true; // unblock any waiting tick
}

void krkr2_tick() {
    // Always flush buffered log messages first, regardless of startup state.
    // This is safe because krkr2_tick is always called from the Dart thread,
    // and g_logCallback (NativeCallable.isolateLocal) requires the Dart thread.
    krkr2_flush_logs();

    // Do not drive the engine until startup has finished.
    if (!g_startupDone.load(std::memory_order_acquire)) return;
    if (!Application) return;

    // Serialize tick with the mutex so that if startup is still holding
    // the lock for some reason we don't race on the engine internals.
    std::unique_lock<std::mutex> lock(g_engineMutex, std::try_to_lock);
    if (!lock.owns_lock()) return; // startup still running — skip this tick

    Application->Run();
}

void krkr2_push_mouse_event(int type, int button, int x, int y) {
    // TODO: Forward to engine
}

void krkr2_push_key_event(int type, int keycode) {
    // TODO: Forward to engine
}

void krkr2_push_touch_event(int type, int id, float x, float y) {
    // TODO: Forward to engine
}

int krkr2_get_window_count() {
    return 1;
}

void* krkr2_get_primary_native_window() {
    return nullptr;
}

void krkr2_get_window_size(int* width, int* height) {
    if (width) *width = 800;
    if (height) *height = 600;
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
template <> bool IndividualConfigManager::GetValue<bool>(const std::string &name, const bool &defVal) { return defVal; }
template <> int IndividualConfigManager::GetValue<int>(const std::string &name, const int &defVal) { return defVal; }
template <> std::string IndividualConfigManager::GetValue<std::string>(const std::string &name, const std::string &defVal) { return defVal; }
template <> float IndividualConfigManager::GetValue<float>(const std::string &name, const float &defVal) { return defVal; }
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

void TVPSetSystemEventDisabledState(bool disabled) {}
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
iTVPRenderManager* TVPGetRenderManager() { return nullptr; }
int TVPShowSimpleMessageBox(const TJS::tTJSString&, const TJS::tTJSString&, const std::vector<TJS::tTJSString>&) { return 0; }
void* TVPGetCachedArchiveHandle(void*, const TJS::tTJSString&) { return nullptr; }
void TVPReleaseCachedArchiveHandle(void*, TJS::tTJSBinaryStream*) {}
tTJSNativeClass* TVPCreateNativeClass_Layer() { return new tTJSNativeClass(TJS_W("Layer")); }
tTJSNativeClass* TVPCreateNativeClass_System() { return new tTJSNativeClass(TJS_W("System")); }
tTJSNativeClass* TVPCreateNativeClass_Plugins() { return new tTJSNativeClass(TJS_W("Plugins")); }
tTJSNativeClass* TVPCreateNativeClass_MenuItem() { return new tTJSNativeClass(TJS_W("MenuItem")); }
bool TVPIsSoftwareRenderManager() { return false; }
iTVPRenderManager* TVPGetSoftwareRenderManager() { return nullptr; }
bool TVPGetSystemEventDisabledState() { return false; }

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
void tvpLoadPlugins() {}
void TVPInvokeEvents() {}
void TVPEventReceived() {}
void TVPCallDeliverAllEventsOnIdle() {}
void TVPBreathe() {}
bool TVPGetBreathing() { return false; }
void TVPBeginContinuousEvent() {}
void TVPEndContinuousEvent() {}
void TVPGetMemoryInfo(TVPMemoryInfo&) {}
unsigned int TVPToActualColor(unsigned int c) { return c; }
unsigned int TVPFromActualColor(unsigned int c) { return c; }
void TVPExitApplication(int) {}

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

