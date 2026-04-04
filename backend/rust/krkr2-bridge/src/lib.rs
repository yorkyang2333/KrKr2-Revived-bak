//! krkr2-bridge: CXX bridge bindings for KrKr2 C++ engine types.
//!
//! This crate provides Rust-side declarations for bridging C++ types like
//! `tTJSBinaryStream` via the [cxx](https://cxx.rs/) framework. Unlike the
//! `extern "C"` FFI used by krkr2-crypto/fft/encoding, cxx enables:
//!
//! - Safe, type-checked bidirectional bindings
//! - Direct use of C++ types (via opaque wrappers) from Rust
//! - Automatic lifetime and ownership management at the boundary
//!
//! ## Architecture
//!
//! `tTJSBinaryStream` is an abstract C++ class with virtual methods. Since cxx
//! cannot directly map C++ vtables, we introduce `BinaryStreamWrapper` — a thin
//! C++ class that holds a `tTJSBinaryStream*` and exposes non-virtual methods
//! that forward to the underlying virtual calls.
//!
//! ```text
//! Rust code
//!   ↓ calls via cxx bridge
//! BinaryStreamWrapper (C++ glue)
//!   ↓ forwards to virtual methods
//! tTJSBinaryStream (engine abstract class)
//! ```

#[cxx::bridge(namespace = "krkr2::bridge")]
mod ffi {
    // =========================================================================
    // C++ types and functions exposed to Rust
    // =========================================================================
    unsafe extern "C++" {
        include!("krkr2_bridge_glue.h");

        /// Opaque wrapper around `tTJSBinaryStream*`.
        /// Constructed on the C++ side and passed to Rust via `UniquePtr`.
        type BinaryStreamWrapper;

        /// Read up to `buf.len()` bytes from the stream.
        /// Returns the number of bytes actually read.
        fn read(self: &BinaryStreamWrapper, buf: &mut [u8]) -> u32;

        /// Write `buf.len()` bytes to the stream.
        /// Returns the number of bytes actually written.
        fn write(self: &BinaryStreamWrapper, buf: &[u8]) -> u32;

        /// Seek to a position in the stream.
        /// `whence`: 0 = SEEK_SET, 1 = SEEK_CUR, 2 = SEEK_END
        /// Returns the new absolute position.
        fn seek(self: &BinaryStreamWrapper, offset: i64, whence: i32) -> u64;

        /// Get the total size of the stream in bytes.
        fn get_size(self: &BinaryStreamWrapper) -> u64;

        /// Get the current read/write position.
        fn get_position(self: &BinaryStreamWrapper) -> u64;

        /// Set the current read/write position.
        fn set_position(self: &BinaryStreamWrapper, pos: u64);

        /// Read exactly `buf.len()` bytes. Throws C++ exception on short read.
        fn read_buffer(self: &BinaryStreamWrapper, buf: &mut [u8]);

        /// Read a little-endian 32-bit integer.
        fn read_i32_le(self: &BinaryStreamWrapper) -> u32;

        /// Read a little-endian 16-bit integer.
        fn read_i16_le(self: &BinaryStreamWrapper) -> u16;

        /// Read a little-endian 64-bit integer.
        fn read_i64_le(self: &BinaryStreamWrapper) -> u64;

        /// Factory: wrap a raw `tTJSBinaryStream*` into a `BinaryStreamWrapper`.
        /// The wrapper does NOT take ownership — the caller must ensure the
        /// underlying stream outlives the wrapper.
        fn make_stream_wrapper(raw_ptr: usize) -> UniquePtr<BinaryStreamWrapper>;
    }
}

// Re-export the ffi module's types for downstream crate usage.
pub use ffi::BinaryStreamWrapper;

/// Helper: create a `BinaryStreamWrapper` from a raw C++ pointer.
///
/// # Safety
/// `ptr` must be a valid, non-null `tTJSBinaryStream*` that outlives the
/// returned wrapper.
pub unsafe fn wrap_stream(
    ptr: *mut std::ffi::c_void,
) -> cxx::UniquePtr<BinaryStreamWrapper> {
    ffi::make_stream_wrapper(ptr as usize)
}

#[cfg(test)]
mod tests {
    // Bridge tests require linking against the C++ glue, so they are
    // only meaningful when run through the full CMake build.
    // Unit-level Rust-only tests go here if needed.

    #[test]
    fn bridge_module_compiles() {
        // Smoke test: the cxx bridge module parsed and compiled successfully.
        // Actual integration tests require C++ linkage.
        assert!(true);
    }
}
