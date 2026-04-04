#include "SDLRenderer.h"
#include <stdexcept>

SDLTexture::SDLTexture(SDL_Renderer* renderer, int width, int height, int format)
    : width_(width), height_(height) {
    texture_ = SDL_CreateTexture(renderer, format, SDL_TEXTUREACCESS_STREAMING, width, height);
    if (!texture_) {
        throw std::runtime_error("Failed to create SDL Texture: " + std::string(SDL_GetError()));
    }
}

SDLTexture::~SDLTexture() {
    if (texture_) {
        SDL_DestroyTexture(texture_);
        texture_ = nullptr;
    }
}

void SDLTexture::Update(const void* pixels, int pitch) {
    if (texture_) {
        SDL_UpdateTexture(texture_, nullptr, pixels, pitch);
    }
}

int SDLTexture::GetWidth() const { return width_; }
int SDLTexture::GetHeight() const { return height_; }


SDLRenderer::SDLRenderer(SDL_Window* window) {
    renderer_ = SDL_CreateRenderer(window, nullptr);
    if (!renderer_) {
        throw std::runtime_error("Failed to create SDL3 renderer: " + std::string(SDL_GetError()));
    }
    SDL_SetRenderDrawColor(renderer_, 0, 0, 0, 255);
}

SDLRenderer::~SDLRenderer() {
    if (renderer_) {
        SDL_DestroyRenderer(renderer_);
        renderer_ = nullptr;
    }
}

std::shared_ptr<ITexture> SDLRenderer::CreateTexture(int width, int height, int format) {
    return std::make_shared<SDLTexture>(renderer_, width, height, format);
}

void SDLRenderer::Clear() {
    if (renderer_) {
        SDL_RenderClear(renderer_);
    }
}

void SDLRenderer::DrawTexture(std::shared_ptr<ITexture> tex, int x, int y, int w, int h) {
    if (renderer_ && tex) {
        SDLTexture* sdlTex = static_cast<SDLTexture*>(tex.get());
        SDL_FRect dstRect = { static_cast<float>(x), static_cast<float>(y), static_cast<float>(w), static_cast<float>(h) };
        SDL_RenderTexture(renderer_, sdlTex->GetSDLTexture(), nullptr, &dstRect);
    }
}

void SDLRenderer::Present() {
    if (renderer_) {
        SDL_RenderPresent(renderer_);
    }
}
