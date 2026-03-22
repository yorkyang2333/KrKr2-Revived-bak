#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to the window and renderer
typedef void* krkr2_window_t;
typedef void* krkr2_renderer_t;
typedef void* krkr2_texture_t;

// Render Interface Callbacks
typedef struct krkr2_renderer_interface {
    krkr2_texture_t (*create_texture)(int width, int height, int format);
    void (*update_texture)(krkr2_texture_t tex, const void* pixels, int pitch);
    void (*destroy_texture)(krkr2_texture_t tex);
    
    void (*clear)();
    void (*draw_texture)(krkr2_texture_t tex, int x, int y, int w, int h);
    void (*present)();
} krkr2_renderer_interface_t;

// Set the global renderer interface implemented by the platform (Flutter/SDL)
void krkr2_set_renderer_interface(krkr2_renderer_interface_t* renderer);

#ifdef __cplusplus
}
#endif
