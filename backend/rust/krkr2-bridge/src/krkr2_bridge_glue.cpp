// krkr2_bridge_glue.cpp
// =====================
// Implementation of BinaryStreamWrapper — forwards cxx bridge calls
// to tTJSBinaryStream virtual methods.

#include "krkr2_bridge_glue.h"
#include "tjs.h" // TJS::tTJSBinaryStream definition

namespace krkr2 {
namespace bridge {

BinaryStreamWrapper::BinaryStreamWrapper(TJS::tTJSBinaryStream *stream)
    : stream_(stream) {}

uint32_t BinaryStreamWrapper::read(rust::Slice<uint8_t> buf) const {
    return stream_->Read(buf.data(), static_cast<tjs_uint>(buf.size()));
}

uint32_t BinaryStreamWrapper::write(rust::Slice<const uint8_t> buf) const {
    return stream_->Write(buf.data(), static_cast<tjs_uint>(buf.size()));
}

uint64_t BinaryStreamWrapper::seek(int64_t offset, int32_t whence) const {
    return stream_->Seek(offset, whence);
}

uint64_t BinaryStreamWrapper::get_size() const {
    return stream_->GetSize();
}

uint64_t BinaryStreamWrapper::get_position() const {
    return stream_->GetPosition();
}

void BinaryStreamWrapper::set_position(uint64_t pos) const {
    stream_->SetPosition(pos);
}

void BinaryStreamWrapper::read_buffer(rust::Slice<uint8_t> buf) const {
    stream_->ReadBuffer(buf.data(), static_cast<tjs_uint>(buf.size()));
}

uint32_t BinaryStreamWrapper::read_i32_le() const {
    return stream_->ReadI32LE();
}

uint16_t BinaryStreamWrapper::read_i16_le() const {
    return stream_->ReadI16LE();
}

uint64_t BinaryStreamWrapper::read_i64_le() const {
    return stream_->ReadI64LE();
}

std::unique_ptr<BinaryStreamWrapper> make_stream_wrapper(size_t raw_ptr) {
    auto *stream = reinterpret_cast<TJS::tTJSBinaryStream *>(raw_ptr);
    return std::make_unique<BinaryStreamWrapper>(stream);
}

} // namespace bridge
} // namespace krkr2
