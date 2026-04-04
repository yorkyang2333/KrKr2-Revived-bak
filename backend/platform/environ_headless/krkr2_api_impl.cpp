#include "../../../include/krkr2_api.h"
#include <string>

#include "tjsCommHead.h"
#include "tjsString.h"
#include "Application.h"
#include "DebugIntf.h"
#include "../../../core/visual/IWindow.h"
#include "../../../core/visual/IRenderer.h"

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

static void krkr2_log_hook(const ttstr &line) {
    if (g_logCallback) {
        g_logCallback(0, line.AsStdString().c_str());
    }
}

extern "C" {

void krkr2_set_log_callback(krkr2_log_callback_t callback) {
    g_logCallback = callback;
    TVPSetOnLog(krkr2_log_hook);
}

void krkr2_set_game_path(const char* path) {
    if (path) {
        g_gamePath = path;
    }
}

bool krkr2_init(int argc, char** argv) {
    if (!Application) {
        Application = new tTVPApplication();
    }
    Application->ArgC = argc;
    Application->ArgV = argv;
    return Application->StartApplication(ttstr(g_gamePath.c_str()));
}

void krkr2_shutdown() {
    if (Application) {
        Application->Terminate();
        delete Application;
        Application = nullptr;
    }
}

void krkr2_tick() {
    if (Application) {
        Application->Run();
    }
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
