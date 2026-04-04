#pragma once

#include "../../../core/visual/IWindow.h"
#include <SDL3/SDL.h>

class SDLInput {
public:
    static void PollEvents(IWindow* window);
};
