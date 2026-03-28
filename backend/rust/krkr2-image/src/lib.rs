//! krkr2-image: TLG5/6 image decoder for KrKr2 engine.
//!
//! This crate replaces `LoadTLG.cpp` with a pure Rust implementation of
//! TLG5 (fast lossless) and TLG6 (high-ratio lossless/near-lossless) decoders.
//!
//! ## Architecture
//!
//! ```text
//! C++ (GraphicsLoaderIntf) → TVPLoadTLG_Rust (C++ adapter)
//!   → tlg_decode (Rust, via cxx bridge)
//!     → StreamReader (reads from tTJSBinaryStream via bridge)
//!     → tlg5::decode_tlg5 / tlg6::decode_tlg6
//!       → LZSS, Golomb, MED/AVG (pure Rust algorithms)
//!   ← TlgDecodeResult (image info + BGRA pixels + metadata tags)
//! C++ adapter → scanlinecallback (delivers to engine)
//! ```

pub mod stream;
pub mod tlg5;
pub mod tlg6;

/// Error type for TLG decoding.
#[derive(Debug)]
pub enum TlgError {
    /// Unsupported color type (not 1, 3, or 4 channels).
    UnsupportedColorType(i32),
    /// Invalid image dimensions.
    InvalidDimensions(i32, i32),
    /// Format error.
    Format(String),
    /// I/O error from stream.
    Io(String),
    /// Invalid TLG header or version.
    InvalidHeader,
    /// Unsupported load mode for TLG5.
    UnsupportedMode,
}

impl std::fmt::Display for TlgError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TlgError::UnsupportedColorType(c) => write!(f, "unsupported color type: {}", c),
            TlgError::InvalidDimensions(w, h) => write!(f, "invalid dimensions: {}x{}", w, h),
            TlgError::Format(s) => write!(f, "format error: {}", s),
            TlgError::Io(s) => write!(f, "I/O error: {}", s),
            TlgError::InvalidHeader => write!(f, "invalid TLG header or version"),
            TlgError::UnsupportedMode => write!(f, "unsupported load mode for TLG5"),
        }
    }
}

impl std::error::Error for TlgError {}

// =========================================================================
// CXX Bridge definition
// =========================================================================

#[cxx::bridge(namespace = "krkr2::image")]
pub mod ffi {
    /// Image information returned by the TLG decoder.
    struct TlgImageInfo {
        pub width: i32,
        pub height: i32,
        pub colors: i32,
    }

    /// A single metadata tag from TLG0.0 SDS wrapper.
    struct TlgTag {
        pub name: String,
        pub value: String,
    }

    /// Complete decode result containing pixels and metadata.
    struct TlgDecodeResult {
        pub info: TlgImageInfo,
        /// BGRA pixel data, width*4*height bytes
        pub pixels: Vec<u8>,
        /// Whether the image was wrapped in TLG0.0 SDS container
        pub has_sds: bool,
        /// Metadata tags from SDS container
        pub tags: Vec<TlgTag>,
    }

    // C++ functions we need from the bridge
    unsafe extern "C++" {
        include!("krkr2_image_adapter.h");

        type BinaryStreamWrapper;

        fn read_buffer(self: &BinaryStreamWrapper, buf: &mut [u8]);
        fn read_i32_le(self: &BinaryStreamWrapper) -> u32;
        fn seek(self: &BinaryStreamWrapper, offset: i64, whence: i32) -> u64;
        fn get_position(self: &BinaryStreamWrapper) -> u64;

        fn make_stream_wrapper(raw_ptr: usize) -> UniquePtr<BinaryStreamWrapper>;
    }

    // Rust functions callable from C++
    extern "Rust" {
        fn tlg_decode(stream_ptr: usize) -> Result<TlgDecodeResult>;
    }
}

/// Main entry point: decode a TLG image from a tTJSBinaryStream pointer.
///
/// Called from the C++ adapter layer. Handles:
/// 1. TLG0.0 SDS container detection and metadata extraction
/// 2. TLG5.0 raw decoding
/// 3. TLG6.0 raw decoding
pub fn tlg_decode(stream_ptr: usize) -> Result<ffi::TlgDecodeResult, String> {
    let mut reader = unsafe { stream::StreamReader::new(stream_ptr) };

    // Read the 11-byte header
    let mut mark = [0u8; 11];
    reader.read_exact(&mut mark).map_err(|e| e.to_string())?;

    let tlg5_sig = b"TLG5.0\x00raw\x1a\x00";
    let tlg6_sig = b"TLG6.0\x00raw\x1a\x00";
    let sds_sig = b"TLG0.0\x00sds\x1a\x00";

    if mark == sds_sig[..] {
        // TLG0.0 SDS container
        let rawlen = reader.read_i32_le().map_err(|e| e.to_string())? as u64;

        // Read the inner TLG header
        let mut inner_mark = [0u8; 11];
        reader.read_exact(&mut inner_mark).map_err(|e| e.to_string())?;

        let (width, height, colors, pixels) = if inner_mark == tlg5_sig[..] {
            tlg5::decode_tlg5(&mut reader).map_err(|e| e.to_string())?
        } else if inner_mark == tlg6_sig[..] {
            tlg6::decode_tlg6(&mut reader, false).map_err(|e| e.to_string())?
        } else {
            return Err("invalid TLG header or version".into());
        };

        // Seek to metadata section
        reader
            .seek_to(rawlen + 11 + 4)
            .map_err(|e| e.to_string())?;

        // Read metadata tags
        let tags = read_sds_tags(&mut reader);

        Ok(ffi::TlgDecodeResult {
            info: ffi::TlgImageInfo {
                width,
                height,
                colors,
            },
            pixels,
            has_sds: true,
            tags,
        })
    } else if mark == tlg5_sig[..] {
        let (width, height, colors, pixels) =
            tlg5::decode_tlg5(&mut reader).map_err(|e| e.to_string())?;

        Ok(ffi::TlgDecodeResult {
            info: ffi::TlgImageInfo {
                width,
                height,
                colors,
            },
            pixels,
            has_sds: false,
            tags: Vec::new(),
        })
    } else if mark == tlg6_sig[..] {
        let (width, height, colors, pixels) =
            tlg6::decode_tlg6(&mut reader, false).map_err(|e| e.to_string())?;

        Ok(ffi::TlgDecodeResult {
            info: ffi::TlgImageInfo {
                width,
                height,
                colors,
            },
            pixels,
            has_sds: false,
            tags: Vec::new(),
        })
    } else {
        // Seek back to start and retry (some files may have different alignment)
        Err("invalid TLG header or version".into())
    }
}

/// Parse TLG0.0 SDS metadata tags.
/// Tags are in format: "4:LEFT=2:20,3:TOP=3:120,"
fn read_sds_tags(reader: &mut stream::StreamReader) -> Vec<ffi::TlgTag> {
    let mut tags = Vec::new();

    loop {
        let mut chunkname = [0u8; 4];
        if reader.read_exact(&mut chunkname).is_err() {
            break;
        }

        let chunksize = match reader.read_i32_le() {
            Ok(s) => s as usize,
            Err(_) => break,
        };

        if &chunkname == b"tags" {
            let tag_data = match reader.read_bytes(chunksize) {
                Ok(d) => d,
                Err(_) => break,
            };

            if let Ok(tag_str) = std::str::from_utf8(&tag_data) {
                let mut pos = 0;
                let bytes = tag_str.as_bytes();
                while pos < bytes.len() {
                    // Parse name length
                    let mut namelen = 0usize;
                    while pos < bytes.len() && bytes[pos].is_ascii_digit() {
                        namelen = namelen * 10 + (bytes[pos] - b'0') as usize;
                        pos += 1;
                    }
                    if pos >= bytes.len() || bytes[pos] != b':' {
                        break;
                    }
                    pos += 1;

                    // Parse name
                    if pos + namelen > bytes.len() {
                        break;
                    }
                    let name = String::from_utf8_lossy(&bytes[pos..pos + namelen]).into_owned();
                    pos += namelen;

                    if pos >= bytes.len() || bytes[pos] != b'=' {
                        break;
                    }
                    pos += 1;

                    // Parse value length
                    let mut valuelen = 0usize;
                    while pos < bytes.len() && bytes[pos].is_ascii_digit() {
                        valuelen = valuelen * 10 + (bytes[pos] - b'0') as usize;
                        pos += 1;
                    }
                    if pos >= bytes.len() || bytes[pos] != b':' {
                        break;
                    }
                    pos += 1;

                    // Parse value
                    if pos + valuelen > bytes.len() {
                        break;
                    }
                    let value =
                        String::from_utf8_lossy(&bytes[pos..pos + valuelen]).into_owned();
                    pos += valuelen;

                    if pos >= bytes.len() || bytes[pos] != b',' {
                        break;
                    }
                    pos += 1;

                    tags.push(ffi::TlgTag { name, value });
                }
            }
        } else {
            // Skip unknown chunk
            let _ = reader.skip(chunksize as u64);
        }
    }

    tags
}

#[cfg(test)]
mod tests {
    #[test]
    fn crate_compiles() {
        assert!(true);
    }
}
