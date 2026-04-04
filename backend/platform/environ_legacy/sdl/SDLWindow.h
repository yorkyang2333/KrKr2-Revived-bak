#pragma once

#include "../../../core/visual/IWindow.h"
#include <SDL3/SDL.h>
#include <string>

class SDLWindow : public IWindow {
public:
    SDLWindow(const std::string& title, int width, int height);
    ~SDLWindow() override;

    // --- Core ---
    void SetTitle(const std::string& title) override;
    void SetSize(int width, int height) override;
    void SetVisible(bool visible) override;
    void SetFullScreen(bool fullscreen) override;

    int  GetWidth() const override;
    int  GetHeight() const override;
    bool IsVisible() const override;
    void* GetNativeHandle() const override;

    SDL_Window* GetSDLWindow() const { return window_; }

    // --- Extended geometry ---
    void SetWidth(int w) override;
    void SetHeight(int h) override;
    void SetLeft(int x) override;
    int  GetLeft() const override;
    void SetTop(int y) override;
    int  GetTop() const override;
    void SetPosition(int x, int y) override;

    void SetMinWidth(int v) override;
    int  GetMinWidth() const override;
    void SetMinHeight(int v) override;
    int  GetMinHeight() const override;
    void SetMinSize(int w, int h) override;

    void SetMaxWidth(int v) override;
    int  GetMaxWidth() const override;
    void SetMaxHeight(int v) override;
    int  GetMaxHeight() const override;
    void SetMaxSize(int w, int h) override;

    // --- Fullscreen tracking ---
    void SetFullScreenMode(bool b) override;
    bool GetFullScreenMode() override;

    // --- Caption ---
    void GetCaption(std::string& v) const override;
    void SetCaption(const std::string& v) override;

    // --- Visibility ---
    void SetVisibleFromScript(bool s) override;
    bool GetVisible() const override;

    // --- Stay on top ---
    void SetStayOnTop(bool b) override;
    bool GetStayOnTop() const override;

    // --- Cursor ---
    void GetCursorPos(int& x, int& y) override;
    void SetCursorPos(int x, int y) override;
    void SetMouseCursorState(tTVPMouseCursorState mcs) override;
    tTVPMouseCursorState GetMouseCursorState() const override;

    // --- Window actions ---
    void BringToFront() override;
    void Close() override;
    void SendCloseMessage() override;
    void TickBeat() override;

private:
    SDL_Window* window_;
    bool fullscreen_ = false;
    bool stayOnTop_  = false;
    tTVPMouseCursorState cursorState_ = mcsVisible;
    bool closeRequested_ = false;
};
