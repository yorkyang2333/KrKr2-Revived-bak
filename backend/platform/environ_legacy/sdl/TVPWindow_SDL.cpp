//---------------------------------------------------------------------------
/*
        TVP2 ( T Visual Presenter 2 )  A script authoring tool
        Copyright (C) 2000 W.Dee <dee@kikyou.info> and contributors

        See details of license at "license.txt"
*/
//---------------------------------------------------------------------------
// SDL3 platform factory for tTJSNI_Window
// Implements TVPCreateAndAddWindow() which is declared extern in WindowImpl.cpp
// and called from tTJSNI_Window::Construct().
//---------------------------------------------------------------------------
#include "SDLWindow.h"
#include "../../../core/visual/IWindow.h"

#include <memory>
#include <vector>
#include <mutex>
#include <algorithm>

// ---------------------------------------------------------------------------
// Forward declaration of tTJSNI_Window (defined in WindowImpl.cpp)
// ---------------------------------------------------------------------------
class tTJSNI_Window;

// ---------------------------------------------------------------------------
// Registry of all live windows (so the engine can tear them down)
// ---------------------------------------------------------------------------
static std::vector<std::weak_ptr<IWindow>> TVPWindowRegistry;
static std::mutex                          TVPWindowRegistryMutex;

// ---------------------------------------------------------------------------
// TVPCreateAndAddWindow
//
// Called by tTJSNI_Window::Construct() to fabricate the platform window.
// Returns a shared_ptr<IWindow> that tTJSNI_Window keeps alive as "Form".
// ---------------------------------------------------------------------------
std::shared_ptr<IWindow> TVPCreateAndAddWindow(tTJSNI_Window * /*w*/) {
    // Default size — the script can resize afterwards via SetWidth/SetHeight.
    const int kDefaultWidth  = 800;
    const int kDefaultHeight = 600;

    std::shared_ptr<IWindow> win =
        std::make_shared<SDLWindow>("KrKr2", kDefaultWidth, kDefaultHeight);

    {
        std::lock_guard<std::mutex> lock(TVPWindowRegistryMutex);
        // Prune expired entries
        TVPWindowRegistry.erase(
            std::remove_if(TVPWindowRegistry.begin(), TVPWindowRegistry.end(),
                           [](const std::weak_ptr<IWindow>& wp){ return wp.expired(); }),
            TVPWindowRegistry.end());
        TVPWindowRegistry.push_back(win);
    }

    return win;
}

// ---------------------------------------------------------------------------
// TVPGetWindowCount (optional helper used internally)
// ---------------------------------------------------------------------------
int TVPGetWindowCount() {
    std::lock_guard<std::mutex> lock(TVPWindowRegistryMutex);
    TVPWindowRegistry.erase(
        std::remove_if(TVPWindowRegistry.begin(), TVPWindowRegistry.end(),
                       [](const std::weak_ptr<IWindow>& wp){ return wp.expired(); }),
        TVPWindowRegistry.end());
    return static_cast<int>(TVPWindowRegistry.size());
}
