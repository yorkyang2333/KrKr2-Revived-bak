// krkr2_image_adapter.cpp
// =======================
// C++ adapter that:
//   1. Implements BinaryStreamWrapper for cxx bridge
//   2. Provides TVPLoadTLG_Rust() callable from GraphicsLoaderIntf

#include "krkr2_image_adapter.h"
#include "tjs.h" // tTJSBinaryStream, ttstr, tjs_int, tjs_uint8

// Forward-declare graphics loader types to avoid pulling in GraphicsLoaderIntf.h
// (which depends on drawable.h and the visual module)
enum tTVPGraphicPixelFormat {
    gpfLuminance,
    gpfPalette,
    gpfRGB,
    gpfRGBA,
};

enum tTVPGraphicLoadMode {
    glmNormal,
    glmPalettized,
    glmGrayscale,
};

typedef int (*tTVPGraphicSizeCallback)(void *callbackdata, tjs_uint w,
                                       tjs_uint h, tTVPGraphicPixelFormat fmt);
typedef void *(*tTVPGraphicScanLineCallback)(void *callbackdata, tjs_int y);
typedef void (*tTVPMetaInfoPushCallback)(void *callbackdata, const ttstr &name,
                                         const ttstr &value);

// Include the cxx-generated bridge header
#include "krkr2-image/src/lib.rs.h"

namespace krkr2 {
namespace image {

BinaryStreamWrapper::BinaryStreamWrapper(TJS::tTJSBinaryStream *stream)
    : stream_(stream) {}

void BinaryStreamWrapper::read_buffer(rust::Slice<uint8_t> buf) const {
    stream_->ReadBuffer(buf.data(), static_cast<tjs_uint>(buf.size()));
}

uint32_t BinaryStreamWrapper::read_i32_le() const {
    return stream_->ReadI32LE();
}

uint64_t BinaryStreamWrapper::seek(int64_t offset, int32_t whence) const {
    return stream_->Seek(offset, whence);
}

uint64_t BinaryStreamWrapper::get_position() const {
    return stream_->GetPosition();
}

std::unique_ptr<BinaryStreamWrapper> make_stream_wrapper(size_t raw_ptr) {
    auto *stream = reinterpret_cast<TJS::tTJSBinaryStream *>(raw_ptr);
    return std::make_unique<BinaryStreamWrapper>(stream);
}

} // namespace image
} // namespace krkr2

// =========================================================================
// TVPLoadTLG_Rust — drop-in replacement for TVPLoadTLG
// =========================================================================

extern "C" void TVPLoadTLG_Rust(
    void *formatdata,
    void *callbackdata,
    tTVPGraphicSizeCallback sizecallback,
    tTVPGraphicScanLineCallback scanlinecallback,
    tTVPMetaInfoPushCallback metainfopushcallback,
    TJS::tTJSBinaryStream *src,
    tjs_int keyidx,
    tTVPGraphicLoadMode mode)
{
    // Call Rust decoder
    auto result = krkr2::image::tlg_decode(reinterpret_cast<size_t>(src));

    const auto &info = result.info;
    const auto &pixels = result.pixels;

    // Notify size
    tTVPGraphicPixelFormat fmt =
        (info.colors == 3) ? gpfRGB : gpfRGBA;
    sizecallback(callbackdata, info.width, info.height, fmt);

    // Deliver scanlines
    tjs_int stride = info.width * 4;
    for (tjs_int y = 0; y < info.height; y++) {
        tjs_uint8 *dest =
            reinterpret_cast<tjs_uint8 *>(scanlinecallback(callbackdata, y));
        if (dest) {
            memcpy(dest, pixels.data() + y * stride, stride);
        }
        scanlinecallback(callbackdata, -1); // commit scanline
    }

    // Deliver metadata tags (if SDS container)
    if (result.has_sds && metainfopushcallback) {
        for (auto &tag : result.tags) {
            metainfopushcallback(
                callbackdata,
                ttstr(tag.name.c_str()),
                ttstr(tag.value.c_str()));
        }
    }
}
