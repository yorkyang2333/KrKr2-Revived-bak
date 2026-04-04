//---------------------------------------------------------------------------
/*
        Risa [りさ]      alias 吉里吉里3 [kirikiri-3]
         stands for "Risa Is a Stagecraft Architecture"
        Copyright (C) 2000 W.Dee <dee@kikyou.info> and contributors

        See details of license at "license.txt"
*/
//---------------------------------------------------------------------------
//! @file
//! @brief リングバッファを実現する自家製テンプレートクラス (Rust Adapter)
//---------------------------------------------------------------------------
#ifndef RingBufferH
#define RingBufferH

#include <stddef.h>
#include <memory>
// 引入 CXX 桥接头文件
#include "krkr2-audio/src/lib.rs.h"

//---------------------------------------------------------------------------
//! @brief		固定長リングバッファの実装
//---------------------------------------------------------------------------
template <typename T>
class tRisaRingBuffer {
    // We only specialize for those we use! Or we can fallback to C++ if needed.
};

// Specialized for float using Rust's krkr2::audio::RingBufferF32_Rust
template <>
class tRisaRingBuffer<float> {
    rust::Box<krkr2::audio::RingBufferF32_Rust> RustBuf;

public:
    //! @brief コンストラクタ
    tRisaRingBuffer(size_t size) : RustBuf(krkr2::audio::create_ring_buffer_f32(size)) {}

    //! @brief デストラクタ
    ~tRisaRingBuffer() {}

    //! @brief	サイズを得る
    size_t GetSize() const { return krkr2::audio::get_size(*RustBuf); }

    //! @brief	書き込み位置を得る
    size_t GetWritePos() const { return krkr2::audio::get_write_pos(*RustBuf); }

    //! @brief	読み込み位置を得る
    size_t GetReadPos() const { return krkr2::audio::get_read_pos(*RustBuf); }

    //! @brief	バッファに入っているデータのサイズを得る
    size_t GetDataSize() const { return krkr2::audio::get_data_size(*RustBuf); }

    //! @brief	バッファの空き容量を得る
    size_t GetFreeSize() const { return krkr2::audio::get_free_size(*RustBuf); }

    //! @brief	バッファから読み込むためのポインタを得る
    void GetReadPointer(size_t readsize, const float *&p1_out, size_t &p1size_out,
                        const float *&p2_out, size_t &p2size_out, ptrdiff_t offset = 0) const {
        krkr2::audio::BufferPointers ptrs = krkr2::audio::get_read_pointers(*RustBuf, readsize, offset);
        p1_out = ptrs.p1.ptr;
        p1size_out = ptrs.p1.len;
        p2_out = ptrs.p2.ptr;
        p2size_out = ptrs.p2.len;
    }

    void AdvanceReadPos(size_t advance = 1) {
        krkr2::audio::advance_read_pos(*RustBuf, advance);
    }

    [[nodiscard]] const float &GetFirst() const {
        // Can't return reference nicely over value returns from ffi, but float is copy!
        static float dummy_first;
        dummy_first = krkr2::audio::get_first(*RustBuf);
        return dummy_first;
    }

    [[nodiscard]] const float &GetAt(size_t n) const {
        static float dummy_at;
        dummy_at = krkr2::audio::get_at(*RustBuf, n);
        return dummy_at;
    }

    void GetWritePointer(size_t writesize, float *&p1_out, size_t &p1size_out, float *&p2_out,
                         size_t &p2size_out, ptrdiff_t offset = 0) {
        krkr2::audio::BufferPointers ptrs = krkr2::audio::get_write_pointers(*RustBuf, writesize, offset);
        p1_out = ptrs.p1.ptr;
        p1size_out = ptrs.p1.len;
        p2_out = ptrs.p2.ptr;
        p2size_out = ptrs.p2.len;
    }

    void AdvanceWritePos(size_t advance = 1) {
        krkr2::audio::advance_write_pos(*RustBuf, advance);
    }

    void AdvanceWritePosWithDiscard(size_t advance = 1) {
        krkr2::audio::advance_write_pos_with_discard(*RustBuf, advance);
    }

    float &GetLast() {
        return *krkr2::audio::get_last(*RustBuf);
    }
};

#endif
