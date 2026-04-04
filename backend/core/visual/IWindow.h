#pragma once

#include <string>

class IWindow {
public:
    virtual ~IWindow() = default;

    virtual void SetTitle(const std::string& title) = 0;
    virtual void SetSize(int width, int height) = 0;
    virtual void SetVisible(bool visible) = 0;
    virtual void SetFullScreen(bool fullscreen) = 0;

    virtual int GetWidth() const = 0;
    virtual int GetHeight() const = 0;
    virtual bool IsVisible() const = 0;

    // Platform specific native handle if needed
    virtual void* GetNativeHandle() const = 0;
};
