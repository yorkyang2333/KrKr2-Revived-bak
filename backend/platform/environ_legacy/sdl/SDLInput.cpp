#include "SDLInput.h"
#include "../../../include/krkr2_api.h"

void SDLInput::PollEvents(IWindow* window) {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_EVENT_QUIT) {
            krkr2_shutdown();
        } else if (e.type == SDL_EVENT_MOUSE_MOTION) {
            krkr2_push_mouse_event(0 /* motion */, 0, static_cast<int>(e.motion.x), static_cast<int>(e.motion.y));
        } else if (e.type == SDL_EVENT_MOUSE_BUTTON_DOWN) {
            krkr2_push_mouse_event(1 /* down */, e.button.button, static_cast<int>(e.button.x), static_cast<int>(e.button.y));
        } else if (e.type == SDL_EVENT_MOUSE_BUTTON_UP) {
            krkr2_push_mouse_event(2 /* up */, e.button.button, static_cast<int>(e.button.x), static_cast<int>(e.button.y));
        } else if (e.type == SDL_EVENT_KEY_DOWN) {
            krkr2_push_key_event(1 /* down */, e.key.key); // SDL3 uses e.key.key instead of keysym.sym
        } else if (e.type == SDL_EVENT_KEY_UP) {
            krkr2_push_key_event(2 /* up */, e.key.key);
        }
    }
}
