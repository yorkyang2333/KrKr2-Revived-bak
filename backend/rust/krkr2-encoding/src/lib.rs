//! krkr2-encoding: Character encoding conversion for KrKr2 engine.
//!
//! Replaces:
//! - `base/CharacterSet.cpp` — UTF-8 ↔ WideChar (UTF-16) conversion
//! - `encoding/gbk2unicode.c` — GBK multibyte to Unicode
//! - `encoding/jis2unicode.c` — Shift-JIS multibyte to Unicode
//!
//! Uses `encoding_rs` for GBK/Shift-JIS and Rust std for UTF-8/UTF-16.

use encoding_rs::{GBK, SHIFT_JIS};

// ============================================================================
// UTF-8 ↔ WideChar (UTF-16) — replaces CharacterSet.cpp
// ============================================================================

/// Convert a wide (UTF-16) string to UTF-8.
/// If `out` is null, returns the byte count needed (excluding null terminator).
/// If `out` is non-null, writes UTF-8 bytes and returns byte count.
/// Returns -1 on error.
///
/// Matches: `tjs_int TVPWideCharToUtf8String(const tjs_char *in, char *out)`
#[no_mangle]
pub unsafe extern "C" fn TVPWideCharToUtf8String(in_: *const u16, out: *mut u8) -> i32 {
    if in_.is_null() {
        return -1;
    }

    // Find length of input UTF-16 string (null terminated)
    let mut len: usize = 0;
    while unsafe { *in_.add(len) } != 0 {
        len += 1;
    }

    let utf16_slice = unsafe { std::slice::from_raw_parts(in_, len) };

    // Decode UTF-16 to Rust String
    let decoded = String::from_utf16(utf16_slice);
    let s = match decoded {
        Ok(s) => s,
        Err(_) => return -1,
    };

    let utf8_bytes = s.as_bytes();
    let count = utf8_bytes.len() as i32;

    if !out.is_null() {
        unsafe {
            std::ptr::copy_nonoverlapping(utf8_bytes.as_ptr(), out, utf8_bytes.len());
        }
    }

    count
}

/// Convert a UTF-8 string (null-terminated) to wide (UTF-16) string.
/// If `out` is null, returns the number of UTF-16 code units needed.
/// If `out` is non-null, writes UTF-16 code units and returns count.
/// Returns -1 on error.
///
/// Matches: `tjs_int TVPUtf8ToWideCharString(const char *in, tjs_char *out)`
#[no_mangle]
pub unsafe extern "C" fn TVPUtf8ToWideCharString(in_: *const u8, out: *mut u16) -> i32 {
    if in_.is_null() {
        return -1;
    }

    // Find null terminator
    let mut len: usize = 0;
    while unsafe { *in_.add(len) } != 0 {
        len += 1;
    }

    let utf8_slice = unsafe { std::slice::from_raw_parts(in_, len) };
    let s = match std::str::from_utf8(utf8_slice) {
        Ok(s) => s,
        Err(_) => return -1,
    };

    let utf16: Vec<u16> = s.encode_utf16().collect();
    let count = utf16.len() as i32;

    if !out.is_null() {
        unsafe {
            std::ptr::copy_nonoverlapping(utf16.as_ptr(), out, utf16.len());
        }
    }

    count
}

/// Convert a UTF-8 string with explicit length to wide (UTF-16) string.
/// If `out` is null, returns the number of UTF-16 code units needed.
/// If `out` is non-null, writes UTF-16 code units and returns count.
/// Returns -1 on error.
///
/// Matches: `tjs_int TVPUtf8ToWideCharString(const char *in, tjs_uint length, tjs_char *out)`
#[no_mangle]
pub unsafe extern "C" fn TVPUtf8ToWideCharStringWithLength(
    in_: *const u8,
    length: u32,
    out: *mut u16,
) -> i32 {
    if in_.is_null() {
        return -1;
    }

    let utf8_slice = unsafe { std::slice::from_raw_parts(in_, length as usize) };

    // Find actual length (stop at null or at specified length)
    let actual_len = utf8_slice.iter().position(|&b| b == 0).unwrap_or(length as usize);
    let utf8_slice = &utf8_slice[..actual_len];

    let s = match std::str::from_utf8(utf8_slice) {
        Ok(s) => s,
        Err(_) => return -1,
    };

    let utf16: Vec<u16> = s.encode_utf16().collect();
    let count = utf16.len() as i32;

    if !out.is_null() {
        unsafe {
            std::ptr::copy_nonoverlapping(utf16.as_ptr(), out, utf16.len());
        }
    }

    count
}

// ============================================================================
// GBK multibyte to Unicode — replaces gbk2unicode.c
// ============================================================================

/// Convert a GBK multibyte character to Unicode.
/// Returns number of bytes consumed (1 or 2), or -1 on error.
///
/// Matches: `int gbk_mbtowc(unsigned short *wc, const unsigned char *s)`
#[no_mangle]
pub unsafe extern "C" fn gbk_mbtowc(wc: *mut u16, s: *const u8) -> i32 {
    if wc.is_null() || s.is_null() {
        return -1;
    }

    let first = unsafe { *s };

    // ASCII range
    if first < 0x80 {
        unsafe { *wc = first as u16 };
        return 1;
    }

    // GBK double byte: lead byte 0x81-0xFE
    if first >= 0x81 {
        let second = unsafe { *s.add(1) };
        let input = [first, second];

        let (decoded, _, had_errors) = GBK.decode(&input);
        if had_errors {
            return -1;
        }

        // Get the first decoded character
        if let Some(ch) = decoded.chars().next() {
            let code = ch as u32;
            if code <= 0xFFFF {
                unsafe { *wc = code as u16 };
                return 2;
            }
        }
    }

    -1
}

// ============================================================================
// Shift-JIS multibyte to Unicode — replaces jis2unicode.c
// ============================================================================

/// Convert a Shift-JIS multibyte character to Unicode.
/// Returns number of bytes consumed (1 or 2), or -1 on error.
///
/// Matches: `int sjis_mbtowc(unsigned short *wc, const unsigned char *s)`
#[no_mangle]
pub unsafe extern "C" fn sjis_mbtowc(wc: *mut u16, s: *const u8) -> i32 {
    if wc.is_null() || s.is_null() {
        return -1;
    }

    let first = unsafe { *s };

    // ASCII range and half-width katakana (0xA1-0xDF)
    if first < 0x80 || (first >= 0xA1 && first <= 0xDF) {
        let input = [first];
        let (decoded, _, had_errors) = SHIFT_JIS.decode(&input);
        if had_errors {
            return -1;
        }
        if let Some(ch) = decoded.chars().next() {
            let code = ch as u32;
            if code <= 0xFFFF {
                unsafe { *wc = code as u16 };
                return 1;
            }
        }
        return -1;
    }

    // Double byte range: lead byte 0x81-0x9F, 0xE0-0xFC
    if (first >= 0x81 && first <= 0x9F) || (first >= 0xE0 && first <= 0xFC) {
        let second = unsafe { *s.add(1) };
        let input = [first, second];

        let (decoded, _, had_errors) = SHIFT_JIS.decode(&input);
        if had_errors {
            return -1;
        }

        if let Some(ch) = decoded.chars().next() {
            let code = ch as u32;
            if code <= 0xFFFF {
                unsafe { *wc = code as u16 };
                return 2;
            }
        }
    }

    -1
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_widechar_to_utf8_ascii() {
        let input: Vec<u16> = vec![0x48, 0x65, 0x6C, 0x6C, 0x6F, 0]; // "Hello\0"
        let mut output = vec![0u8; 16];
        let count =
            unsafe { TVPWideCharToUtf8String(input.as_ptr(), output.as_mut_ptr()) };
        assert_eq!(count, 5);
        assert_eq!(&output[..5], b"Hello");
    }

    #[test]
    fn test_widechar_to_utf8_cjk() {
        // U+4F60 = 你, U+597D = 好
        let input: Vec<u16> = vec![0x4F60, 0x597D, 0];
        let mut output = vec![0u8; 16];
        let count =
            unsafe { TVPWideCharToUtf8String(input.as_ptr(), output.as_mut_ptr()) };
        assert_eq!(count, 6); // 3 bytes each
        assert_eq!(&output[..6], "你好".as_bytes());
    }

    #[test]
    fn test_widechar_to_utf8_count_only() {
        let input: Vec<u16> = vec![0x4F60, 0x597D, 0];
        let count =
            unsafe { TVPWideCharToUtf8String(input.as_ptr(), std::ptr::null_mut()) };
        assert_eq!(count, 6);
    }

    #[test]
    fn test_utf8_to_widechar() {
        let input = b"Hello\0";
        let mut output = vec![0u16; 16];
        let count =
            unsafe { TVPUtf8ToWideCharString(input.as_ptr(), output.as_mut_ptr()) };
        assert_eq!(count, 5);
        assert_eq!(&output[..5], &[0x48, 0x65, 0x6C, 0x6C, 0x6F]);
    }

    #[test]
    fn test_utf8_to_widechar_cjk() {
        let input = "你好\0";
        let mut output = vec![0u16; 16];
        let count = unsafe {
            TVPUtf8ToWideCharString(input.as_ptr(), output.as_mut_ptr())
        };
        assert_eq!(count, 2);
        assert_eq!(&output[..2], &[0x4F60, 0x597D]);
    }

    #[test]
    fn test_utf8_to_widechar_with_length() {
        let input = "Hello World"; // no null terminator relied on
        let mut output = vec![0u16; 16];
        let count = unsafe {
            TVPUtf8ToWideCharStringWithLength(input.as_ptr(), 5, output.as_mut_ptr())
        };
        assert_eq!(count, 5);
        assert_eq!(&output[..5], &[0x48, 0x65, 0x6C, 0x6C, 0x6F]);
    }

    #[test]
    fn test_gbk_mbtowc_ascii() {
        let mut wc: u16 = 0;
        let input: [u8; 1] = [0x41]; // 'A'
        let result = unsafe { gbk_mbtowc(&mut wc, input.as_ptr()) };
        assert_eq!(result, 1);
        assert_eq!(wc, 0x41);
    }

    #[test]
    fn test_gbk_mbtowc_chinese() {
        let mut wc: u16 = 0;
        // GBK encoding of 中 is 0xD6D0
        let input: [u8; 2] = [0xD6, 0xD0];
        let result = unsafe { gbk_mbtowc(&mut wc, input.as_ptr()) };
        assert_eq!(result, 2);
        assert_eq!(wc, 0x4E2D); // Unicode for 中
    }

    #[test]
    fn test_sjis_mbtowc_ascii() {
        let mut wc: u16 = 0;
        let input: [u8; 1] = [0x41]; // 'A'
        let result = unsafe { sjis_mbtowc(&mut wc, input.as_ptr()) };
        assert_eq!(result, 1);
        assert_eq!(wc, 0x41);
    }

    #[test]
    fn test_sjis_mbtowc_katakana() {
        let mut wc: u16 = 0;
        // SJIS half-width katakana ア = 0xB1
        let input: [u8; 1] = [0xB1];
        let result = unsafe { sjis_mbtowc(&mut wc, input.as_ptr()) };
        assert_eq!(result, 1);
        assert_eq!(wc, 0xFF71); // Unicode half-width ア
    }

    #[test]
    fn test_sjis_mbtowc_kanji() {
        let mut wc: u16 = 0;
        // SJIS encoding of 漢 is 0x8ABF
        let input: [u8; 2] = [0x8A, 0xBF];
        let result = unsafe { sjis_mbtowc(&mut wc, input.as_ptr()) };
        assert_eq!(result, 2);
        assert_eq!(wc, 0x6F22); // Unicode for 漢
    }
}
