#pragma once

#include "../../../core/visual/IRenderer.h"
#include <SDL3/SDL.h>
#include <memory>

class SDLTexture : public ITexture {
public:
    SDLTexture(SDL_Renderer* renderer, int width, int height, int format);
    ~SDLTexture() override;

    void Update(const void* pixels, int pitch) override;
    int GetWidth() const override;
    int GetHeight() const override;

    SDL_Texture* GetSDLTexture() const { return texture_; }

private:
    SDL_Texture* texture_;
    int width_;
    int height_;
};

class SDLRenderer : public IRenderer {
public:
    SDLRenderer(SDL_Window* window);
    ~SDLRenderer() override;

    std::shared_ptr<ITexture> CreateTexture(int width, int height, int format) override;
    void Clear() override;
    void DrawTexture(std::shared_ptr<ITexture> tex, int x, int y, int w, int h) override;
    void Present() override;

    SDL_Renderer* GetSDLRenderer() const { return renderer_; }

private:
    SDL_Renderer* renderer_;
};
