#pragma once

#include <stdint.h>
#include <memory>

class ITexture {
public:
    virtual ~ITexture() = default;
    virtual void Update(const void* pixels, int pitch) = 0;
    virtual int GetWidth() const = 0;
    virtual int GetHeight() const = 0;
};

class IRenderer {
public:
    virtual ~IRenderer() = default;

    virtual std::shared_ptr<ITexture> CreateTexture(int width, int height, int format) = 0;
    virtual void Clear() = 0;
    virtual void DrawTexture(std::shared_ptr<ITexture> tex, int x, int y, int w, int h) = 0;
    virtual void Present() = 0;
};
