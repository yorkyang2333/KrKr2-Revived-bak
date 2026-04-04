#include "SDLWindow.h"
#include <stdexcept>

SDLWindow::SDLWindow(const std::string& title, int width, int height) {
    if (!SDL_InitSubSystem(SDL_INIT_VIDEO)) {
        throw std::runtime_error("Failed to initialize SDL Video subsystem: " +
                                 std::string(SDL_GetError()));
    }

    window_ = SDL_CreateWindow(title.c_str(), width, height,
                               SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIDDEN);
    if (!window_) {
        throw std::runtime_error("Failed to create SDL3 window: " +
                                 std::string(SDL_GetError()));
    }
}

SDLWindow::~SDLWindow() {
    if (window_) {
        SDL_DestroyWindow(window_);
        window_ = nullptr;
    }
}

// ---------------------------------------------------------------------------
// Core
// ---------------------------------------------------------------------------
void SDLWindow::SetTitle(const std::string& title) {
    if (window_) SDL_SetWindowTitle(window_, title.c_str());
}

void SDLWindow::SetSize(int width, int height) {
    if (window_) SDL_SetWindowSize(window_, width, height);
}

void SDLWindow::SetVisible(bool visible) {
    if (!window_) return;
    if (visible) SDL_ShowWindow(window_);
    else         SDL_HideWindow(window_);
}

void SDLWindow::SetFullScreen(bool fullscreen) {
    if (window_) {
        SDL_SetWindowFullscreen(window_, fullscreen);
        fullscreen_ = fullscreen;
    }
}

int SDLWindow::GetWidth() const {
    if (!window_) return 0;
    int w = 0, h = 0;
    SDL_GetWindowSize(window_, &w, &h);
    return w;
}

int SDLWindow::GetHeight() const {
    if (!window_) return 0;
    int w = 0, h = 0;
    SDL_GetWindowSize(window_, &w, &h);
    return h;
}

bool SDLWindow::IsVisible() const {
    if (!window_) return false;
    SDL_WindowFlags flags = SDL_GetWindowFlags(window_);
    return (flags & SDL_WINDOW_HIDDEN) == 0;
}

void* SDLWindow::GetNativeHandle() const {
    // SDL3: use SDL_GetWindowProperties if needed
    return static_cast<void*>(window_);
}

// ---------------------------------------------------------------------------
// Extended geometry
// ---------------------------------------------------------------------------
void SDLWindow::SetWidth(int w) {
    if (window_) SDL_SetWindowSize(window_, w, GetHeight());
}

void SDLWindow::SetHeight(int h) {
    if (window_) SDL_SetWindowSize(window_, GetWidth(), h);
}

void SDLWindow::SetLeft(int x) {
    if (window_) {
        int y = GetTop();
        SDL_SetWindowPosition(window_, x, y);
    }
}

int SDLWindow::GetLeft() const {
    if (!window_) return 0;
    int x = 0, y = 0;
    SDL_GetWindowPosition(window_, &x, &y);
    return x;
}

void SDLWindow::SetTop(int y) {
    if (window_) {
        int x = GetLeft();
        SDL_SetWindowPosition(window_, x, y);
    }
}

int SDLWindow::GetTop() const {
    if (!window_) return 0;
    int x = 0, y = 0;
    SDL_GetWindowPosition(window_, &x, &y);
    return y;
}

void SDLWindow::SetPosition(int x, int y) {
    if (window_) SDL_SetWindowPosition(window_, x, y);
}

void SDLWindow::SetMinWidth(int v) {
    if (window_) SDL_SetWindowMinimumSize(window_, v, GetMinHeight());
}
int SDLWindow::GetMinWidth() const {
    if (!window_) return 0;
    int w = 0, h = 0;
    SDL_GetWindowMinimumSize(window_, &w, &h);
    return w;
}

void SDLWindow::SetMinHeight(int v) {
    if (window_) SDL_SetWindowMinimumSize(window_, GetMinWidth(), v);
}
int SDLWindow::GetMinHeight() const {
    if (!window_) return 0;
    int w = 0, h = 0;
    SDL_GetWindowMinimumSize(window_, &w, &h);
    return h;
}

void SDLWindow::SetMinSize(int w, int h) {
    if (window_) SDL_SetWindowMinimumSize(window_, w, h);
}

void SDLWindow::SetMaxWidth(int v) {
    if (window_) SDL_SetWindowMaximumSize(window_, v, GetMaxHeight());
}
int SDLWindow::GetMaxWidth() const {
    if (!window_) return 0;
    int w = 0, h = 0;
    SDL_GetWindowMaximumSize(window_, &w, &h);
    return w;
}

void SDLWindow::SetMaxHeight(int v) {
    if (window_) SDL_SetWindowMaximumSize(window_, GetMaxWidth(), v);
}
int SDLWindow::GetMaxHeight() const {
    if (!window_) return 0;
    int w = 0, h = 0;
    SDL_GetWindowMaximumSize(window_, &w, &h);
    return h;
}

void SDLWindow::SetMaxSize(int w, int h) {
    if (window_) SDL_SetWindowMaximumSize(window_, w, h);
}

// ---------------------------------------------------------------------------
// Fullscreen tracking
// ---------------------------------------------------------------------------
void SDLWindow::SetFullScreenMode(bool b) {
    SetFullScreen(b);
}

bool SDLWindow::GetFullScreenMode() {
    if (!window_) return false;
    SDL_WindowFlags flags = SDL_GetWindowFlags(window_);
    return (flags & SDL_WINDOW_FULLSCREEN) != 0;
}

// ---------------------------------------------------------------------------
// Caption
// ---------------------------------------------------------------------------
void SDLWindow::GetCaption(std::string& v) const {
    if (window_) {
        const char* title = SDL_GetWindowTitle(window_);
        v = title ? title : "";
    }
}

void SDLWindow::SetCaption(const std::string& v) {
    SetTitle(v);
}

// ---------------------------------------------------------------------------
// Visibility
// ---------------------------------------------------------------------------
void SDLWindow::SetVisibleFromScript(bool s) {
    SetVisible(s);
}

bool SDLWindow::GetVisible() const {
    return IsVisible();
}

// ---------------------------------------------------------------------------
// Stay on top
// ---------------------------------------------------------------------------
void SDLWindow::SetStayOnTop(bool b) {
    stayOnTop_ = b;
    if (window_) SDL_SetWindowAlwaysOnTop(window_, b);
}

bool SDLWindow::GetStayOnTop() const {
    return stayOnTop_;
}

// ---------------------------------------------------------------------------
// Cursor
// ---------------------------------------------------------------------------
void SDLWindow::GetCursorPos(int& x, int& y) {
    float fx, fy;
    SDL_GetMouseState(&fx, &fy);
    x = static_cast<int>(fx);
    y = static_cast<int>(fy);
}

void SDLWindow::SetCursorPos(int x, int y) {
    if (window_) SDL_WarpMouseInWindow(window_, static_cast<float>(x),
                                                static_cast<float>(y));
}

void SDLWindow::SetMouseCursorState(tTVPMouseCursorState mcs) {
    cursorState_ = mcs;
    if (mcs == mcsHidden) SDL_HideCursor();
    else                  SDL_ShowCursor();
}

tTVPMouseCursorState SDLWindow::GetMouseCursorState() const {
    return cursorState_;
}

// ---------------------------------------------------------------------------
// Window actions
// ---------------------------------------------------------------------------
void SDLWindow::BringToFront() {
    if (window_) SDL_RaiseWindow(window_);
}

void SDLWindow::Close() {
    closeRequested_ = true;
    // Push a SDL_EVENT_QUIT so the main event loop picks it up
    SDL_Event ev;
    ev.type      = SDL_EVENT_QUIT;
    ev.quit.type = SDL_EVENT_QUIT;
    SDL_PushEvent(&ev);
}

void SDLWindow::SendCloseMessage() {
    Close();
}

void SDLWindow::TickBeat() {
    // Called once per engine tick — nothing needed here; SDL events
    // are pumped centrally by SDLInput.
}
