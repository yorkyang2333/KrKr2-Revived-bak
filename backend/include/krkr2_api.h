#ifndef KRKR2_API_H
#define KRKR2_API_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Engine initialization and shutdown
bool krkr2_init(int argc, char** argv);
void krkr2_shutdown();

// Frame updating
void krkr2_tick();

// Input and Events
void krkr2_push_mouse_event(int type, int button, int x, int y);
void krkr2_push_key_event(int type, int keycode);

#ifdef __cplusplus
}
#endif

#endif // KRKR2_API_H
