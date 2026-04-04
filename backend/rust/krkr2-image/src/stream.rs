//! Stream reader abstraction for reading from tTJSBinaryStream via cxx bridge.

use crate::TlgError;
use cxx::UniquePtr;

/// A reader that wraps a raw tTJSBinaryStream pointer and provides
/// convenient read methods for TLG decoding.
pub struct StreamReader {
    /// Wrapped C++ BinaryStreamWrapper (holds the raw stream pointer).
    wrapper: UniquePtr<crate::ffi::BinaryStreamWrapper>,
}

impl StreamReader {
    /// Create a new StreamReader wrapping a raw tTJSBinaryStream pointer.
    ///
    /// # Safety
    /// The pointer must be valid for the lifetime of this reader.
    pub unsafe fn new(stream_ptr: usize) -> Self {
        let wrapper = crate::ffi::make_stream_wrapper(stream_ptr);
        StreamReader { wrapper }
    }

    /// Read exactly `buf.len()` bytes from the stream.
    pub fn read_exact(&mut self, buf: &mut [u8]) -> Result<(), TlgError> {
        self.wrapper.read_buffer(buf);
        Ok(())
    }

    /// Read a little-endian 32-bit integer.
    pub fn read_i32_le(&mut self) -> Result<u32, TlgError> {
        Ok(self.wrapper.read_i32_le())
    }

    /// Skip `count` bytes by seeking forward.
    pub fn skip(&mut self, count: u64) -> Result<(), TlgError> {
        self.wrapper.seek(count as i64, 1); // SEEK_CUR = 1
        Ok(())
    }

    /// Get current stream position.
    pub fn position(&self) -> u64 {
        self.wrapper.get_position()
    }

    /// Seek to absolute position.
    pub fn seek_to(&mut self, pos: u64) -> Result<(), TlgError> {
        self.wrapper.seek(pos as i64, 0); // SEEK_SET = 0
        Ok(())
    }

    /// Read `count` bytes into a new Vec.
    pub fn read_bytes(&mut self, count: usize) -> Result<Vec<u8>, TlgError> {
        let mut buf = vec![0u8; count];
        self.read_exact(&mut buf)?;
        Ok(buf)
    }

    /// Read a single byte.
    pub fn read_u8(&mut self) -> Result<u8, TlgError> {
        let mut buf = [0u8; 1];
        self.read_exact(&mut buf)?;
        Ok(buf[0])
    }
}
