//! krkr2-crypto: MD5 hashing and environment-noise based PRNG for KrKr2 engine.
//!
//! This crate replaces the original C implementations:
//! - `utils/md5.c` (RFC 1321 MD5)
//! - `utils/Random.cpp` (environment noise + MD5-based PRNG)
//!
//! All functions are exposed via `extern "C"` FFI with the exact same signatures
//! as the original C code to maintain ABI compatibility.

use md5::{Digest, Md5};
use std::sync::Mutex;

// ============================================================================
// MD5 API — ABI-compatible with original md5.h
// ============================================================================

/// Opaque MD5 state. Layout matches original `md5_state_t`:
///   - count[2]: u32 (message length in bits)
///   - abcd[4]: u32 (digest buffer)
///   - buf[64]: u8 (accumulate block)
/// Total = 8 + 16 + 64 = 88 bytes
///
/// We store the Rust Md5 hasher inside an internal buffer of the same size.
/// Since `Md5` from the `md-5` crate is smaller than 88 bytes, this is safe.
#[repr(C)]
pub struct md5_state_t {
    /// Internal storage — opaque to C callers.
    /// We store a serialized representation of the Md5 hasher state.
    _internal: [u8; 88],
}

/// We need a way to store the Md5 hasher. Since we can't put a Rust type
/// with Drop into a C struct safely, we use a simple approach:
/// accumulate all data and compute on finish.
///
/// Internal representation stored in _internal:
///   bytes 0..3: u32 total_len (little-endian)
///   bytes 4..87: accumulated data ring buffer (84 bytes)
///
/// Actually, the simplest correct approach: since md5_init/append/finish
/// mirrors Md5::new/update/finalize, we store accumulated bytes in a Vec
/// via a global map keyed by pointer address. But that's complex.
///
/// Better approach: just implement MD5 directly using the md-5 crate
/// by storing partial state. The md-5 crate's Md5 type is 96 bytes on
/// most platforms which is larger than our 88-byte struct.
///
/// Simplest correct approach: implement our own streaming MD5 using the
/// md-5 crate's one-shot API, accumulating data in a side buffer.
/// We use a global HashMap<usize, Vec<u8>> keyed by struct address.

use std::collections::HashMap;
use std::sync::LazyLock;

static MD5_BUFFERS: LazyLock<Mutex<HashMap<usize, Vec<u8>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// Initialize the MD5 algorithm.
#[no_mangle]
pub extern "C" fn md5_init(pms: *mut md5_state_t) {
    let key = pms as usize;
    let mut map = MD5_BUFFERS.lock().unwrap();
    map.insert(key, Vec::new());
}

/// Append data to the MD5 message.
#[no_mangle]
pub extern "C" fn md5_append(pms: *mut md5_state_t, data: *const u8, nbytes: i32) {
    if data.is_null() || nbytes <= 0 {
        return;
    }
    let key = pms as usize;
    let slice = unsafe { std::slice::from_raw_parts(data, nbytes as usize) };
    let mut map = MD5_BUFFERS.lock().unwrap();
    if let Some(buf) = map.get_mut(&key) {
        buf.extend_from_slice(slice);
    }
}

/// Finish the MD5 message and return the 16-byte digest.
#[no_mangle]
pub extern "C" fn md5_finish(pms: *mut md5_state_t, digest: *mut u8) {
    let key = pms as usize;
    let mut map = MD5_BUFFERS.lock().unwrap();
    if let Some(buf) = map.remove(&key) {
        let result = Md5::digest(&buf);
        unsafe {
            std::ptr::copy_nonoverlapping(result.as_ptr(), digest, 16);
        }
    }
}

// ============================================================================
// Random API — replaces Random.cpp
// ============================================================================

static RANDOM_STATE: LazyLock<Mutex<RandomState>> = LazyLock::new(|| {
    Mutex::new(RandomState {
        pool: [0u8; 0x1000],
        pos: 0,
        atom: 0u8,
    })
});

struct RandomState {
    pool: [u8; 0x1000],
    pos: usize,
    atom: u8,
}

/// Push environment noise into the random seed pool.
#[no_mangle]
pub extern "C" fn TVPPushEnvironNoise(buf: *const u8, bufsize: i32) {
    if buf.is_null() || bufsize <= 0 {
        return;
    }
    let data = unsafe { std::slice::from_raw_parts(buf, bufsize as usize) };
    let mut state = RANDOM_STATE.lock().unwrap();

    for &byte in data {
        state.atom ^= byte;
        let pos = state.pos;
        state.pool[pos] ^= state.atom;
        state.pos = (pos + 1) & 0xfff;
    }
    let pos = state.pos;
    state.pos = (pos + (data[0] as usize & 1)) & 0xfff;
}

/// Retrieve 128 random bits based on the seed pool, using MD5 digest.
#[no_mangle]
pub extern "C" fn TVPGetRandomBits128(dest: *mut u8) {
    if dest.is_null() {
        return;
    }

    // Add some noise (intentionally using uninitialized-like data)
    let noise = [0u8; 16];
    TVPPushEnvironNoise(noise.as_ptr(), 16);

    let state = RANDOM_STATE.lock().unwrap();
    let pos_bytes = (state.pos as i32).to_ne_bytes();
    drop(state); // release lock before calling TVPPushEnvironNoise

    TVPPushEnvironNoise(pos_bytes.as_ptr(), pos_bytes.len() as i32);

    // Hash the pool using MD5
    let state = RANDOM_STATE.lock().unwrap();
    let result = Md5::digest(&state.pool[..0x1000]);
    drop(state);

    unsafe {
        std::ptr::copy_nonoverlapping(result.as_ptr(), dest, 16);
    }

    // Push hash itself as additional noise
    TVPPushEnvironNoise(result.as_ptr(), 16);
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_md5_empty() {
        let mut state = md5_state_t { _internal: [0; 88] };
        let mut digest = [0u8; 16];

        md5_init(&mut state);
        md5_finish(&mut state, digest.as_mut_ptr());

        // MD5("") = d41d8cd98f00b204e9800998ecf8427e
        let expected: [u8; 16] = [
            0xd4, 0x1d, 0x8c, 0xd9, 0x8f, 0x00, 0xb2, 0x04, 0xe9, 0x80, 0x09, 0x98, 0xec, 0xf8,
            0x42, 0x7e,
        ];
        assert_eq!(digest, expected);
    }

    #[test]
    fn test_md5_abc() {
        let mut state = md5_state_t { _internal: [0; 88] };
        let mut digest = [0u8; 16];
        let data = b"abc";

        md5_init(&mut state);
        md5_append(&mut state, data.as_ptr(), data.len() as i32);
        md5_finish(&mut state, digest.as_mut_ptr());

        // MD5("abc") = 900150983cd24fb0d6963f7d28e17f72
        let expected: [u8; 16] = [
            0x90, 0x01, 0x50, 0x98, 0x3c, 0xd2, 0x4f, 0xb0, 0xd6, 0x96, 0x3f, 0x7d, 0x28, 0xe1,
            0x7f, 0x72,
        ];
        assert_eq!(digest, expected);
    }

    #[test]
    fn test_md5_incremental() {
        let mut state = md5_state_t { _internal: [0; 88] };
        let mut digest = [0u8; 16];

        md5_init(&mut state);
        md5_append(&mut state, b"a".as_ptr(), 1);
        md5_append(&mut state, b"bc".as_ptr(), 2);
        md5_finish(&mut state, digest.as_mut_ptr());

        // Same as MD5("abc")
        let expected: [u8; 16] = [
            0x90, 0x01, 0x50, 0x98, 0x3c, 0xd2, 0x4f, 0xb0, 0xd6, 0x96, 0x3f, 0x7d, 0x28, 0xe1,
            0x7f, 0x72,
        ];
        assert_eq!(digest, expected);
    }

    #[test]
    fn test_random_bits_not_zero() {
        let mut dest = [0u8; 16];
        TVPGetRandomBits128(dest.as_mut_ptr());
        // The result should not be all zeros (extremely unlikely)
        // Note: pool starts at all zeros, but MD5 of zeros is non-zero
        assert_ne!(dest, [0u8; 16]);
    }
}
