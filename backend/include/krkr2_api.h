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
typedef enum krkr2_startup_state {
    KRKR2_STARTUP_IDLE = 0,
    KRKR2_STARTUP_STARTING = 1,
    KRKR2_STARTUP_RUNNING = 2,
    KRKR2_STARTUP_FAILED = 3,
} krkr2_startup_state_t;

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
void krkr2_set_global_option(const char* key, const char* value);
void krkr2_set_current_game_option(const char* key, const char* value);
void krkr2_clear_current_game_option(const char* key);

// ---------------------------------------------------------------------------
// Logging & Debugging
// ---------------------------------------------------------------------------
// Log levels: 0 = Info, 1 = Warning, 2 = Error, 3 = Important
typedef void (*krkr2_log_callback_t)(int level, const char* message);
void krkr2_set_log_callback(krkr2_log_callback_t callback);

// ---------------------------------------------------------------------------
// Display queries
// ---------------------------------------------------------------------------
int krkr2_get_startup_state();
bool krkr2_has_first_frame();
const char* krkr2_get_last_error_message();
void krkr2_get_window_size(int* width, int* height);

#ifdef __cplusplus
}
#endif

#endif // KRKR2_API_H
