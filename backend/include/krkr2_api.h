#ifndef KRKR2_API_H
#define KRKR2_API_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ---------------------------------------------------------------------------
// Engine initialization and shutdown
// ---------------------------------------------------------------------------
bool krkr2_init(int argc, char** argv);
void krkr2_shutdown();

// ---------------------------------------------------------------------------
// Frame updating
// Called once per frame from the host application's main loop.
// Pumps SDL events and drives the engine's per-frame logic.
// ---------------------------------------------------------------------------
void krkr2_tick();

// ---------------------------------------------------------------------------
// Input and Events
// Push synthesized input events into the engine from the host (Flutter, etc.)
// ---------------------------------------------------------------------------
void krkr2_push_mouse_event(int type, int button, int x, int y);
void krkr2_push_key_event(int type, int keycode);

// ---------------------------------------------------------------------------
// Window management
// krkr2_get_window_count() returns the number of open engine windows.
// krkr2_get_native_window()  returns the SDL_Window* (as void*) for the
//   primary engine window; returns NULL if none is open yet.
// ---------------------------------------------------------------------------
int   krkr2_get_window_count();
void* krkr2_get_primary_native_window();

// ---------------------------------------------------------------------------
// Headless / Windowless Support
// ---------------------------------------------------------------------------
void krkr2_set_game_path(const char* path);

// ---------------------------------------------------------------------------
// Logging & Debugging
// ---------------------------------------------------------------------------
// Log levels: 0 = Info, 1 = Warning, 2 = Error, 3 = Important
typedef void (*krkr2_log_callback_t)(int level, const char* message);
void krkr2_set_log_callback(krkr2_log_callback_t callback);

// ---------------------------------------------------------------------------
// Display queries
// ---------------------------------------------------------------------------
void krkr2_get_window_size(int* width, int* height);

#ifdef __cplusplus
}
#endif

#endif // KRKR2_API_H
