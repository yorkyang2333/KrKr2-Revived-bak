#pragma once

#include "../../../core/visual/IWindow.h"
#include <SDL3/SDL.h>
#include <string>

class SDLWindow : public IWindow {
public:
    SDLWindow(const std::string& title, int width, int height);
    ~SDLWindow() override;

    void SetTitle(const std::string& title) override;
    void SetSize(int width, int height) override;
    void SetVisible(bool visible) override;
    void SetFullScreen(bool fullscreen) override;

    int GetWidth() const override;
    int GetHeight() const override;
    bool IsVisible() const override;

    void* GetNativeHandle() const override;

    SDL_Window* GetSDLWindow() const { return window_; }

private:
    SDL_Window* window_;
};
