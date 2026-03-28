//! TLG6 decoder — high compression ratio lossless/near-lossless graphics.
//!
//! Ported from `tvpgl.cpp` (Golomb decoding, MED/AVG filters, chroma decode)
//! and `LoadTLG.cpp` (TVPLoadTLG6).
//!
//! TLG6 uses Golomb-Rice entropy coding, 16 chroma correlation filters,
//! and MED (Median Edge Detector) / AVG predictors for spatial prediction.

use crate::stream::StreamReader;
use crate::tlg5::lzss_decompress_slide;
use crate::TlgError;

const TLG6_W_BLOCK_SIZE: usize = 8;
const TLG6_H_BLOCK_SIZE: usize = 8;

const GOLOMB_N_COUNT: usize = 4;
const LEADING_ZERO_TABLE_BITS: usize = 12;
const LEADING_ZERO_TABLE_SIZE: usize = 1 << LEADING_ZERO_TABLE_BITS;

/// Pre-computed Golomb compressed table values (tuned by W.Dee, 2004/03/25).
const GOLOMB_COMPRESSED: [[i16; 9]; GOLOMB_N_COUNT] = [
    [3, 7, 15, 27, 63, 108, 223, 448, 130],
    [3, 5, 13, 24, 51, 95, 192, 384, 257],
    [2, 5, 12, 21, 39, 86, 155, 320, 384],
    [2, 3, 9, 18, 33, 61, 129, 258, 511],
];

/// Lazily-initialized tables for TLG6 Golomb decoding.
struct GolombTables {
    leading_zero: [u8; LEADING_ZERO_TABLE_SIZE],
    bit_length: [[u8; GOLOMB_N_COUNT]; GOLOMB_N_COUNT * 2 * 128],
}

impl GolombTables {
    fn new() -> Self {
        let mut t = GolombTables {
            leading_zero: [0; LEADING_ZERO_TABLE_SIZE],
            bit_length: [[0; GOLOMB_N_COUNT]; GOLOMB_N_COUNT * 2 * 128],
        };
        t.init_leading_zero_table();
        t.init_golomb_table();
        t
    }

    /// Initialize leading zero count table.
    /// Entry i = position of first set bit + 1 (0 if no bit set within range).
    fn init_leading_zero_table(&mut self) {
        for i in 0..LEADING_ZERO_TABLE_SIZE {
            let mut cnt = 0u8;
            let mut j = 1usize;
            while j != LEADING_ZERO_TABLE_SIZE && (i & j) == 0 {
                j <<= 1;
                cnt += 1;
            }
            cnt += 1;
            if j == LEADING_ZERO_TABLE_SIZE {
                cnt = 0;
            }
            self.leading_zero[i] = cnt;
        }
    }

    /// Initialize Golomb bit-length table from compressed data.
    fn init_golomb_table(&mut self) {
        for n in 0..GOLOMB_N_COUNT {
            let mut a = 0usize;
            for i in 0..9 {
                let count = GOLOMB_COMPRESSED[n][i] as usize;
                for _ in 0..count {
                    self.bit_length[a][n] = i as u8;
                    a += 1;
                }
            }
            debug_assert_eq!(a, GOLOMB_N_COUNT * 2 * 128);
        }
    }
}

// Use std::sync::LazyLock for thread-safe lazy initialization
use std::sync::LazyLock;
static GOLOMB: LazyLock<GolombTables> = LazyLock::new(GolombTables::new);

/// Fetch 32 bits from a byte slice at the given byte+bit offset (little-endian).
#[inline(always)]
fn fetch_32bits(pool: &[u8], byte_pos: usize) -> u32 {
    if byte_pos + 4 <= pool.len() {
        u32::from_le_bytes([
            pool[byte_pos],
            pool[byte_pos + 1],
            pool[byte_pos + 2],
            pool[byte_pos + 3],
        ])
    } else {
        // Fallback for edge case (near end of buffer)
        let mut val = 0u32;
        for i in 0..4 {
            if byte_pos + i < pool.len() {
                val |= (pool[byte_pos + i] as u32) << (i * 8);
            }
        }
        val
    }
}

/// Decode Golomb-coded values for the first color channel.
/// The first channel fills 32-bit pixels (clearing upper bytes).
///
/// Ported from TVPTLG6DecodeGolombValuesForFirst_c.
fn decode_golomb_values_for_first(pixelbuf: &mut [u32], pixel_count: usize, bit_pool: &[u8]) {
    let tables = &*GOLOMB;
    let mut n = GOLOMB_N_COUNT as i32 - 1;
    let mut a = 0usize;
    let mut bit_pos = 1usize;
    let mut byte_pos = 0usize;
    let zero_init = if bit_pool.first().map_or(false, |b| b & 1 != 0) {
        0u8
    } else {
        1u8
    };
    let mut zero = zero_init;
    let mut pix_idx = 0usize;
    let limit = pixel_count;

    while pix_idx < limit {
        // Get running count via unary coding
        let count;
        {
            let t = fetch_32bits(bit_pool, byte_pos) >> bit_pos;
            let mut b = tables.leading_zero[t as usize & (LEADING_ZERO_TABLE_SIZE - 1)] as usize;
            let mut bit_count = b;
            while b == 0 {
                bit_count += LEADING_ZERO_TABLE_BITS;
                bit_pos += LEADING_ZERO_TABLE_BITS;
                byte_pos += bit_pos >> 3;
                bit_pos &= 7;
                let t2 = fetch_32bits(bit_pool, byte_pos) >> bit_pos;
                b = tables.leading_zero[t2 as usize & (LEADING_ZERO_TABLE_SIZE - 1)] as usize;
                bit_count += b;
            }
            bit_pos += b;
            byte_pos += bit_pos >> 3;
            bit_pos &= 7;

            bit_count -= 1;
            count = (1usize << bit_count)
                + ((fetch_32bits(bit_pool, byte_pos) >> bit_pos) as usize
                    & ((1 << bit_count) - 1));
            bit_pos += bit_count;
            byte_pos += bit_pos >> 3;
            bit_pos &= 7;
        }

        if zero != 0 {
            // Zero run
            for _ in 0..count {
                if pix_idx >= limit {
                    break;
                }
                pixelbuf[pix_idx] = 0;
                pix_idx += 1;
            }
            zero ^= 1;
        } else {
            // Non-zero values (Golomb coded)
            for _ in 0..count {
                if pix_idx >= limit {
                    break;
                }
                let k = tables.bit_length[a][n as usize] as usize;

                let t = fetch_32bits(bit_pool, byte_pos) >> bit_pos;
                let bit_count;
                let b;
                if t != 0 {
                    let mut b2 = tables.leading_zero
                        [t as usize & (LEADING_ZERO_TABLE_SIZE - 1)]
                        as usize;
                    let mut bc = b2;
                    while b2 == 0 {
                        bc += LEADING_ZERO_TABLE_BITS;
                        bit_pos += LEADING_ZERO_TABLE_BITS;
                        byte_pos += bit_pos >> 3;
                        bit_pos &= 7;
                        let t2 = fetch_32bits(bit_pool, byte_pos) >> bit_pos;
                        b2 = tables.leading_zero
                            [t2 as usize & (LEADING_ZERO_TABLE_SIZE - 1)]
                            as usize;
                        bc += b2;
                    }
                    bc -= 1;
                    bit_count = bc;
                    b = b2;
                } else {
                    byte_pos += 5;
                    bit_count = bit_pool.get(byte_pos.wrapping_sub(1)).copied().unwrap_or(0)
                        as usize;
                    bit_pos = 0;
                    b = 0;
                }

                let v_raw =
                    (bit_count << k) + ((fetch_32bits(bit_pool, byte_pos) >> b) as usize & ((1 << k) - 1));
                let sign = ((v_raw & 1) as i32) - 1; // -1 if odd, 0 if even
                let v = v_raw >> 1;
                a += v;
                pixelbuf[pix_idx] = ((v as i32 ^ sign) + sign + 1) as u8 as u32;
                pix_idx += 1;

                bit_pos += b;
                bit_pos += k;
                byte_pos += bit_pos >> 3;
                bit_pos &= 7;

                n -= 1;
                if n < 0 {
                    a >>= 1;
                    n = GOLOMB_N_COUNT as i32 - 1;
                }
            }
            zero ^= 1;
        }
    }
}

/// Decode Golomb-coded values for non-first color channels.
/// Only writes one byte per pixel at the channel offset.
///
/// Ported from TVPTLG6DecodeGolombValues_c.
fn decode_golomb_values(pixelbuf: &mut [u8], channel: usize, pixel_count: usize, bit_pool: &[u8]) {
    let tables = &*GOLOMB;
    let mut n = GOLOMB_N_COUNT as i32 - 1;
    let mut a = 0usize;
    let mut bit_pos = 1usize;
    let mut byte_pos = 0usize;
    let zero_init = if bit_pool.first().map_or(false, |b| b & 1 != 0) {
        0u8
    } else {
        1u8
    };
    let mut zero = zero_init;
    let mut pix_idx = 0usize;
    let limit = pixel_count;

    while pix_idx < limit {
        let count;
        {
            let t = fetch_32bits(bit_pool, byte_pos) >> bit_pos;
            let mut b = tables.leading_zero[t as usize & (LEADING_ZERO_TABLE_SIZE - 1)] as usize;
            let mut bit_count = b;
            while b == 0 {
                bit_count += LEADING_ZERO_TABLE_BITS;
                bit_pos += LEADING_ZERO_TABLE_BITS;
                byte_pos += bit_pos >> 3;
                bit_pos &= 7;
                let t2 = fetch_32bits(bit_pool, byte_pos) >> bit_pos;
                b = tables.leading_zero[t2 as usize & (LEADING_ZERO_TABLE_SIZE - 1)] as usize;
                bit_count += b;
            }
            bit_pos += b;
            byte_pos += bit_pos >> 3;
            bit_pos &= 7;
            bit_count -= 1;
            count = (1usize << bit_count)
                + ((fetch_32bits(bit_pool, byte_pos) >> bit_pos) as usize
                    & ((1 << bit_count) - 1));
            bit_pos += bit_count;
            byte_pos += bit_pos >> 3;
            bit_pos &= 7;
        }

        if zero != 0 {
            for _ in 0..count {
                if pix_idx >= limit {
                    break;
                }
                pixelbuf[pix_idx * 4 + channel] = 0;
                pix_idx += 1;
            }
            zero ^= 1;
        } else {
            for _ in 0..count {
                if pix_idx >= limit {
                    break;
                }
                let k = tables.bit_length[a][n as usize] as usize;
                let t = fetch_32bits(bit_pool, byte_pos) >> bit_pos;
                let bit_count;
                let b;
                if t != 0 {
                    let mut b2 = tables.leading_zero
                        [t as usize & (LEADING_ZERO_TABLE_SIZE - 1)]
                        as usize;
                    let mut bc = b2;
                    while b2 == 0 {
                        bc += LEADING_ZERO_TABLE_BITS;
                        bit_pos += LEADING_ZERO_TABLE_BITS;
                        byte_pos += bit_pos >> 3;
                        bit_pos &= 7;
                        let t2 = fetch_32bits(bit_pool, byte_pos) >> bit_pos;
                        b2 = tables.leading_zero
                            [t2 as usize & (LEADING_ZERO_TABLE_SIZE - 1)]
                            as usize;
                        bc += b2;
                    }
                    bc -= 1;
                    bit_count = bc;
                    b = b2;
                } else {
                    byte_pos += 5;
                    bit_count =
                        bit_pool.get(byte_pos.wrapping_sub(1)).copied().unwrap_or(0) as usize;
                    bit_pos = 0;
                    b = 0;
                }

                let v_raw = (bit_count << k)
                    + ((fetch_32bits(bit_pool, byte_pos) >> b) as usize & ((1 << k) - 1));
                let sign = ((v_raw & 1) as i32) - 1;
                let v = v_raw >> 1;
                a += v;
                pixelbuf[pix_idx * 4 + channel] = ((v as i32 ^ sign) + sign + 1) as u8;
                pix_idx += 1;

                bit_pos += b;
                bit_pos += k;
                byte_pos += bit_pos >> 3;
                bit_pos &= 7;

                n -= 1;
                if n < 0 {
                    a >>= 1;
                    n = GOLOMB_N_COUNT as i32 - 1;
                }
            }
            zero ^= 1;
        }
    }
}

// =========================================================================
// MED / AVG pixel predictors
// =========================================================================

/// Create a mask where each byte is 0xFF if the corresponding byte in a > b.
#[inline(always)]
fn make_gt_mask(a: u32, b: u32) -> u32 {
    let tmp2 = !b;
    let tmp = ((a & tmp2).wrapping_add(((a ^ tmp2) >> 1) & 0x7f7f7f7f)) & 0x80808080;
    ((tmp >> 7).wrapping_add(0x7f7f7f7f)) ^ 0x7f7f7f7f
}

/// Add two packed-byte values without overflow between bytes.
#[inline(always)]
fn packed_bytes_add(a: u32, b: u32) -> u32 {
    let tmp = (((a & b) << 1).wrapping_add((a ^ b) & 0xfefefefe)) & 0x01010100;
    a.wrapping_add(b).wrapping_sub(tmp)
}

/// Median Edge Detector on packed BGRA pixels.
#[inline(always)]
fn med2(a: u32, b: u32, c: u32) -> u32 {
    let aa_gt_bb = make_gt_mask(a, b);
    let a_xor_b_and_mask = (a ^ b) & aa_gt_bb;
    let aa = a_xor_b_and_mask ^ a;
    let bb = a_xor_b_and_mask ^ b;
    let n = make_gt_mask(c, bb);
    let nn = make_gt_mask(aa, c);
    let m = !(n | nn);
    (n & aa) | (nn & bb) | ((bb & m).wrapping_sub(c & m).wrapping_add(aa & m))
}

/// MED predictor + delta.
#[inline(always)]
fn med(a: u32, b: u32, c: u32, v: u32) -> u32 {
    packed_bytes_add(med2(a, b, c), v)
}

/// Average of two packed pixels.
#[inline(always)]
fn avg_packed(x: u32, y: u32) -> u32 {
    ((x & y).wrapping_add(((x ^ y) & 0xfefefefe) >> 1)).wrapping_add((x ^ y) & 0x01010101)
}

/// AVG predictor + delta.
#[inline(always)]
fn avg(a: u32, b: u32, _c: u32, v: u32) -> u32 {
    packed_bytes_add(avg_packed(a, b), v)
}

// =========================================================================
// Chroma filter types (16 variants × 2 predictor modes = 32 cases)
// =========================================================================

/// Extract BGRA components from a pixel value in the interleaved buffer.
#[inline(always)]
fn extract_bgra(pixel: u32) -> (i8, i8, i8, i8) {
    let b = (pixel & 0xff) as i8;
    let g = ((pixel >> 8) & 0xff) as i8;
    let r = ((pixel >> 16) & 0xff) as i8;
    let a = ((pixel >> 24) & 0xff) as i8;
    (b, g, r, a)
}

/// Pack BGRA components into a 32-bit pixel value for the predictor.
#[inline(always)]
fn pack_filter(b: i8, g: i8, r: i8, a: i8) -> u32 {
    (r as u8 as u32) | ((g as u8 as u32) << 8) | ((b as u8 as u32) << 16) | ((a as u8 as u32) << 24)
}

/// Decode one line using a specific chroma filter type.
/// `filter_type` encodes both the chroma correlation filter (bits 1+) and
/// the predictor mode (bit 0: 0=MED, 1=AVG).
fn decode_filter_block(
    prevline: &[u32],
    curline: &mut [u32],
    start: usize,
    w: usize,
    in_buf: &[u32],
    in_start: usize,
    step: i32,
    filter_type: u8,
    initial_p: u32,
    initial_up: u32,
) {
    let mut p = initial_p;
    let mut up = initial_up;
    let predictor = filter_type & 1; // 0 = med, 1 = avg
    let filter = filter_type >> 1;

    let mut in_idx = in_start;
    for i in 0..w {
        let u = prevline[start + i];
        let pixel = in_buf[in_idx];
        let (ib, ig, ir, ia) = extract_bgra(pixel);

        // Apply chroma correlation filter
        let (fb, fg, fr) = match filter {
            0 => (ib, ig, ir),
            1 => (ib.wrapping_add(ig), ig, ir.wrapping_add(ig)),
            2 => (ib, ig.wrapping_add(ib), ir.wrapping_add(ib).wrapping_add(ig)),
            3 => (
                ib.wrapping_add(ir).wrapping_add(ig),
                ig.wrapping_add(ir),
                ir,
            ),
            4 => (
                ib.wrapping_add(ir),
                ig.wrapping_add(ib).wrapping_add(ir),
                ir.wrapping_add(ib).wrapping_add(ir).wrapping_add(ig),
            ),
            5 => (ib.wrapping_add(ir), ig.wrapping_add(ib).wrapping_add(ir), ir),
            6 => (ib.wrapping_add(ig), ig, ir),
            7 => (ib, ig.wrapping_add(ib), ir),
            8 => (ib, ig, ir.wrapping_add(ig)),
            9 => (
                ib.wrapping_add(ig).wrapping_add(ir).wrapping_add(ib),
                ig.wrapping_add(ir).wrapping_add(ib),
                ir.wrapping_add(ib),
            ),
            10 => (ib.wrapping_add(ir), ig.wrapping_add(ir), ir),
            11 => (ib, ig.wrapping_add(ib), ir.wrapping_add(ib)),
            12 => (ib, ig.wrapping_add(ir).wrapping_add(ib), ir.wrapping_add(ib)),
            13 => (
                ib.wrapping_add(ig),
                ig.wrapping_add(ir).wrapping_add(ib).wrapping_add(ig),
                ir.wrapping_add(ib).wrapping_add(ig),
            ),
            14 => (
                ib.wrapping_add(ig).wrapping_add(ir),
                ig.wrapping_add(ir),
                ir.wrapping_add(ib).wrapping_add(ig).wrapping_add(ir),
            ),
            15 => (
                ib,
                ig.wrapping_add(ib << 1),
                ir.wrapping_add(ib << 1),
            ),
            _ => (ib, ig, ir),
        };

        let v = pack_filter(fb, fg, fr, ia);

        p = if predictor == 0 {
            med(p, u, up, v)
        } else {
            avg(p, u, up, v)
        };

        up = u;
        curline[start + i] = p;
        in_idx = (in_idx as i64 + step as i64) as usize;
    }
}

/// Decode a TLG6 image from a stream reader.
pub fn decode_tlg6(
    reader: &mut StreamReader,
    palettized: bool,
) -> Result<(i32, i32, i32, Vec<u8>), TlgError> {
    // Force Golomb table initialization
    let _tables = &*GOLOMB;

    // Read header
    let mut buf = [0u8; 4];
    reader.read_exact(&mut buf)?;

    let colors = buf[0] as i32;
    if colors != 1 && colors != 3 && colors != 4 {
        return Err(TlgError::UnsupportedColorType(colors));
    }
    if buf[1] != 0 {
        return Err(TlgError::Format("data flag must be zero".into()));
    }
    if buf[2] != 0 {
        return Err(TlgError::Format("unsupported color type".into()));
    }
    if buf[3] != 0 {
        return Err(TlgError::Format("unsupported external golomb table".into()));
    }

    let width = reader.read_i32_le()? as i32;
    let height = reader.read_i32_le()? as i32;
    let max_bit_length = reader.read_i32_le()? as i32;

    if width <= 0 || height <= 0 {
        return Err(TlgError::InvalidDimensions(width, height));
    }

    let w = width as usize;
    let h = height as usize;

    // Compute block counts
    let x_block_count = (w - 1) / TLG6_W_BLOCK_SIZE + 1;
    let _y_block_count = (h - 1) / TLG6_H_BLOCK_SIZE + 1;
    let main_count = w / TLG6_W_BLOCK_SIZE;
    let fraction = w - main_count * TLG6_W_BLOCK_SIZE;

    // Allocate buffers
    let bit_pool_size = max_bit_length as usize / 8 + 5;
    let mut bit_pool = vec![0u8; bit_pool_size];
    let mut pixelbuf = vec![0u32; w * TLG6_H_BLOCK_SIZE + 1];
    let mut pixelbuf_bytes: Vec<u8>; // byte-level view for channel decoding

    // Read and decompress filter types via LZSS
    let filter_inbuf_size = reader.read_i32_le()? as usize;
    let mut filter_inbuf = vec![0u8; filter_inbuf_size];
    reader.read_exact(&mut filter_inbuf)?;

    let mut lzss_text = [0u8; 4096];
    // Initialize LZSS text (TLG6 uses a special pattern)
    {
        let text_as_u32: &mut [u32] =
            unsafe { std::slice::from_raw_parts_mut(lzss_text.as_mut_ptr() as *mut u32, 1024) };
        let mut idx = 0;
        let mut i: u32 = 0;
        while i < 32u32.wrapping_mul(0x01010101) {
            let mut j: u32 = 0;
            while j < 16u32.wrapping_mul(0x01010101) {
                if idx + 1 < 1024 {
                    text_as_u32[idx] = i;
                    text_as_u32[idx + 1] = j;
                }
                idx += 2;
                j = j.wrapping_add(0x01010101);
            }
            i = i.wrapping_add(0x01010101);
        }
    }

    let mut filter_types = Vec::new();
    lzss_decompress_slide(&filter_inbuf, &mut filter_types, &mut lzss_text, 0);

    // Initialize zeroline (virtual y=-1 line)
    let initial_pixel = if colors == 3 { 0xff000000u32 } else { 0x00000000u32 };
    let zeroline = vec![initial_pixel; w];

    // Output pixel buffer (BGRA)
    let stride = w * 4;
    let mut pixels = vec![0u8; stride * h];

    // Allocate temp lines for palettized mode
    let mut tmpline: [Vec<u32>; 2] = [Vec::new(), Vec::new()];

    let mut prevline_buf = zeroline.clone();

    for y in (0..h).step_by(TLG6_H_BLOCK_SIZE) {
        let ylim = std::cmp::min(y + TLG6_H_BLOCK_SIZE, h);
        let pixel_count = (ylim - y) * w;

        // Decode Golomb values for each color channel
        for c in 0..colors as usize {
            let raw_bit_length = reader.read_i32_le()? as u32;
            let method = (raw_bit_length >> 30) & 3;
            let bit_length = (raw_bit_length & 0x3fffffff) as usize;

            let byte_length = (bit_length + 7) / 8;
            if byte_length > bit_pool.len() {
                bit_pool.resize(byte_length + 8, 0);
            }
            reader.read_exact(&mut bit_pool[..byte_length])?;

            match method {
                0 => {
                    if c == 0 && colors != 1 {
                        if pixelbuf.len() < pixel_count {
                            pixelbuf.resize(pixel_count, 0);
                        }
                        decode_golomb_values_for_first(
                            &mut pixelbuf[..pixel_count],
                            pixel_count,
                            &bit_pool,
                        );
                    } else {
                        // Need byte-level access to pixelbuf for channel writes
                        pixelbuf_bytes = unsafe {
                            std::slice::from_raw_parts_mut(
                                pixelbuf.as_mut_ptr() as *mut u8,
                                pixelbuf.len() * 4,
                            )
                        }
                        .to_vec();
                        decode_golomb_values(
                            &mut pixelbuf_bytes,
                            c,
                            pixel_count,
                            &bit_pool,
                        );
                        // Copy back
                        unsafe {
                            std::ptr::copy_nonoverlapping(
                                pixelbuf_bytes.as_ptr(),
                                pixelbuf.as_mut_ptr() as *mut u8,
                                std::cmp::min(pixelbuf_bytes.len(), pixelbuf.len() * 4),
                            );
                        }
                    }
                }
                _ => {
                    return Err(TlgError::Format("unsupported entropy coding method".into()));
                }
            }
        }

        // Decode each line in this block
        let ft_base = (y / TLG6_H_BLOCK_SIZE) * x_block_count;

        for yy in y..ylim {
            let mut curline = vec![0u32; w];

            let dir = (yy & 1) ^ 1;
            let oddskip = ((ylim - yy - 1) as i32) - ((yy - y) as i32);
            let step: i32 = if dir & 1 != 0 { 1 } else { -1 };

            // Main blocks
            if main_count > 0 {
                let ww = if w < TLG6_W_BLOCK_SIZE {
                    w
                } else {
                    TLG6_W_BLOCK_SIZE
                };
                let pix_start = ww * (yy - y);

                for i in 0..main_count {
                    let block_w_actual = std::cmp::min(TLG6_W_BLOCK_SIZE, w - i * TLG6_W_BLOCK_SIZE);
                    let ft_idx = ft_base + i;
                    let ft = *filter_types.get(ft_idx).unwrap_or(&0);

                    let block_start = i * TLG6_W_BLOCK_SIZE;
                    let (init_p, init_up) = if block_start > 0 {
                        (curline[block_start - 1], prevline_buf[block_start - 1])
                    } else if i == 0 {
                        (initial_pixel, initial_pixel)
                    } else {
                        (curline[block_start - 1], prevline_buf[block_start - 1])
                    };

                    let skipblockbytes = (ylim - y) * TLG6_W_BLOCK_SIZE;
                    let mut in_start = pix_start + skipblockbytes * i;
                    if step == -1 {
                        in_start += block_w_actual - 1;
                    }
                    if i & 1 != 0 {
                        in_start = (in_start as i64 + oddskip as i64 * block_w_actual as i64) as usize;
                    }

                    decode_filter_block(
                        &prevline_buf,
                        &mut curline,
                        block_start,
                        block_w_actual,
                        &pixelbuf,
                        in_start,
                        step,
                        ft,
                        init_p,
                        init_up,
                    );
                }
            }

            // Fraction block (last partial block)
            if main_count != x_block_count {
                let block_start = main_count * TLG6_W_BLOCK_SIZE;
                let _block_w_actual = w - block_start;
                let ww = std::cmp::min(fraction, TLG6_W_BLOCK_SIZE);

                for i in main_count..x_block_count {
                    let cur_block_start = i * TLG6_W_BLOCK_SIZE;
                    let cur_w = std::cmp::min(TLG6_W_BLOCK_SIZE, w - cur_block_start);
                    let ft_idx = ft_base + i;
                    let ft = *filter_types.get(ft_idx).unwrap_or(&0);

                    let (init_p, init_up) = if cur_block_start > 0 {
                        (curline[cur_block_start - 1], prevline_buf[cur_block_start - 1])
                    } else {
                        (initial_pixel, initial_pixel)
                    };

                    let skipblockbytes = (ylim - y) * TLG6_W_BLOCK_SIZE;
                    let pix_ww = std::cmp::min(ww, TLG6_W_BLOCK_SIZE);
                    let mut in_start = pix_ww * (yy - y) + skipblockbytes * i;
                    if step == -1 {
                        in_start += cur_w - 1;
                    }
                    if i & 1 != 0 {
                        in_start = (in_start as i64 + oddskip as i64 * cur_w as i64) as usize;
                    }

                    decode_filter_block(
                        &prevline_buf,
                        &mut curline,
                        cur_block_start,
                        cur_w,
                        &pixelbuf,
                        in_start,
                        step,
                        ft,
                        init_p,
                        init_up,
                    );
                }
            }

            // Write to output pixels
            if !palettized {
                let line_start = yy * stride;
                for x in 0..w {
                    let pixel = curline[x];
                    let base = line_start + x * 4;
                    // TLG6 outputs in native packed format (BGRA on LE)
                    pixels[base] = (pixel & 0xff) as u8;
                    pixels[base + 1] = ((pixel >> 8) & 0xff) as u8;
                    pixels[base + 2] = ((pixel >> 16) & 0xff) as u8;
                    pixels[base + 3] = ((pixel >> 24) & 0xff) as u8;
                }
            } else {
                if tmpline[0].is_empty() {
                    tmpline[0] = vec![0u32; w];
                    tmpline[1] = vec![0u32; w];
                }
                tmpline[yy & 1].copy_from_slice(&curline);
                // For palettized, extract luminance (red channel → single byte)
                let line_start = yy * stride;
                for x in 0..w {
                    let pixel = curline[x];
                    let lumi = (pixel & 0xFF) as u8;
                    let base = line_start + x * 4;
                    pixels[base] = lumi;
                    pixels[base + 1] = lumi;
                    pixels[base + 2] = lumi;
                    pixels[base + 3] = 0xff;
                }
            }

            prevline_buf.copy_from_slice(&curline);
        }
    }

    Ok((width, height, colors, pixels))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_golomb_tables_initialized() {
        let tables = &*GOLOMB;
        // Leading zero table: entry 1 should be 1 (bit 0 is set → 0 leading zeros + 1 = 1)
        assert_eq!(tables.leading_zero[1], 1);
        // Entry 0 should be 0 (no bit set)
        assert_eq!(tables.leading_zero[0], 0);
        // Entry 2 should be 2 (bit 1 is first set → 1 leading zero + 1 = 2)
        assert_eq!(tables.leading_zero[2], 2);
    }

    #[test]
    fn test_med_predictor() {
        // MED(a,a,a) with zero delta should return a
        let a = 0x80808080u32;
        let result = med(a, a, a, 0);
        assert_eq!(result, a);
    }

    #[test]
    fn test_packed_bytes_add() {
        assert_eq!(packed_bytes_add(0x01010101, 0x01010101), 0x02020202);
        // Overflow within a byte should not carry to next byte
        assert_eq!(packed_bytes_add(0xFF000000, 0x01000000), 0x00000000);
    }
}
