#include "SDLWindow.h"
#include <stdexcept>

SDLWindow::SDLWindow(const std::string& title, int width, int height) {
    if (!SDL_InitSubSystem(SDL_INIT_VIDEO)) {
        throw std::runtime_error("Failed to initialize SDL Video subsystem: " + std::string(SDL_GetError()));
    }

    // SDL3 window creation uses flags like SDL_WINDOW_RESIZABLE
    window_ = SDL_CreateWindow(title.c_str(), width, height, SDL_WINDOW_RESIZABLE);
    if (!window_) {
        throw std::runtime_error("Failed to create SDL3 window: " + std::string(SDL_GetError()));
    }
}

SDLWindow::~SDLWindow() {
    if (window_) {
        SDL_DestroyWindow(window_);
        window_ = nullptr;
    }
}

void SDLWindow::SetTitle(const std::string& title) {
    if (window_) {
        SDL_SetWindowTitle(window_, title.c_str());
    }
}

void SDLWindow::SetSize(int width, int height) {
    if (window_) {
        SDL_SetWindowSize(window_, width, height);
    }
}

void SDLWindow::SetVisible(bool visible) {
    if (window_) {
        if (visible) {
            SDL_ShowWindow(window_);
        } else {
            SDL_HideWindow(window_);
        }
    }
}

void SDLWindow::SetFullScreen(bool fullscreen) {
    if (window_) {
        SDL_SetWindowFullscreen(window_, fullscreen);
    }
}

int SDLWindow::GetWidth() const {
    if (window_) {
        int w, h;
        SDL_GetWindowSize(window_, &w, &h);
        return w;
    }
    return 0;
}

int SDLWindow::GetHeight() const {
    if (window_) {
        int w, h;
        SDL_GetWindowSize(window_, &w, &h);
        return h;
    }
    return 0;
}

bool SDLWindow::IsVisible() const {
    if (window_) {
        Uint32 flags = SDL_GetWindowFlags(window_);
        return (flags & SDL_WINDOW_HIDDEN) == 0;
    }
    return false;
}

void* SDLWindow::GetNativeHandle() const {
    // Basic native handle bridging if needed later (e.g. SDL_GetWindowProperties with SDL3)
    return nullptr;
}
