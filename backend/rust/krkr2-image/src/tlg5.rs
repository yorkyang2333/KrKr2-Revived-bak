//! TLG5 decoder — lossless graphics compression designed for fast decoding.
//!
//! Ported from `tvpgl.cpp` (TVPTLG5DecompressSlide_c, TVPTLG5ComposeColors*)
//! and `LoadTLG.cpp` (TVPLoadTLG5).

use crate::stream::StreamReader;
use crate::TlgError;

/// LZSS sliding window decompression (modified variant used by TLG5/6).
///
/// Ported from `TVPTLG5DecompressSlide_c` in tvpgl.cpp.
/// Uses a 4096-byte circular text buffer for back-references.
pub fn lzss_decompress_slide(
    input: &[u8],
    output: &mut Vec<u8>,
    text: &mut [u8; 4096],
    initial_r: usize,
) -> usize {
    let mut r = initial_r;
    let mut flags: u32 = 0;
    let mut pos = 0;
    let in_len = input.len();

    while pos < in_len {
        flags >>= 1;
        if (flags & 0x100) == 0 {
            if pos >= in_len {
                break;
            }
            flags = input[pos] as u32 | 0xff00;
            pos += 1;

            // Fast path: if all 8 bits are literal (flags byte = 0xff),
            // and we have room, copy 8 bytes at once
            if flags == 0xff00 && r < (4096 - 8) && pos + 8 <= in_len {
                output.extend_from_slice(&input[pos..pos + 8]);
                text[r..r + 8].copy_from_slice(&input[pos..pos + 8]);
                r += 8;
                pos += 8;
                flags = 0;
                continue;
            }
        }

        if (flags & 1) != 0 {
            // Back-reference
            if pos + 2 > in_len {
                break;
            }
            let in16 = input[pos] as u16 | ((input[pos + 1] as u16) << 8);
            let mut mpos = (in16 & 0xFFF) as usize;
            let mut mlen = ((in16 >> 12) + 3) as usize;
            pos += 2;

            if mlen == 18 {
                if pos >= in_len {
                    break;
                }
                mlen += input[pos] as usize;
                pos += 1;
            }

            // Fast path for non-overlapping copies
            if (mpos + mlen) < 4096 && (r + mlen) < 4096 {
                output.extend_from_slice(&text[mpos..mpos + mlen]);
                text.copy_within(mpos..mpos + mlen, r);
                r += mlen;
                continue;
            }

            // Slow path for wrapping copies
            for _ in 0..mlen {
                let b = text[mpos];
                output.push(b);
                text[r] = b;
                mpos = (mpos + 1) & 0xFFF;
                r = (r + 1) & 0xFFF;
            }
        } else {
            // Literal byte
            if pos >= in_len {
                break;
            }
            let b = input[pos];
            pos += 1;
            output.push(b);
            text[r] = b;
            r = (r + 1) & 0xFFF;
        }
    }

    r
}

/// Compose colors for the first scanline with 3 color channels (RGB → BGRA).
/// This handles the delta-coding on the first line where there is no previous line.
#[inline]
fn compose_first_line_3(
    scanline: &mut [u8],
    outbuf: &[&[u8]; 3],
    offset: usize,
    width: usize,
) {
    let mut pr: u8 = 0;
    let mut pg: u8 = 0;
    let mut pb: u8 = 0;

    for x in 0..width {
        let r_delta = outbuf[0][offset + x];
        let g_delta = outbuf[1][offset + x];
        let b_delta = outbuf[2][offset + x];

        let g = g_delta;
        let b = b_delta.wrapping_add(g);
        let r = r_delta.wrapping_add(g);

        pb = pb.wrapping_add(b);
        pg = pg.wrapping_add(g);
        pr = pr.wrapping_add(r);

        let base = x * 4;
        scanline[base] = pb;     // B
        scanline[base + 1] = pg; // G
        scanline[base + 2] = pr; // R
        scanline[base + 3] = 0xff; // A
    }
}

/// Compose colors for the first scanline with 4 color channels (RGBA → BGRA).
#[inline]
fn compose_first_line_4(
    scanline: &mut [u8],
    outbuf: &[&[u8]; 4],
    offset: usize,
    width: usize,
) {
    let mut pr: u8 = 0;
    let mut pg: u8 = 0;
    let mut pb: u8 = 0;
    let mut pa: u8 = 0;

    for x in 0..width {
        let r_delta = outbuf[0][offset + x];
        let g_delta = outbuf[1][offset + x];
        let b_delta = outbuf[2][offset + x];
        let a_delta = outbuf[3][offset + x];

        let g = g_delta;
        let b = b_delta.wrapping_add(g);
        let r = r_delta.wrapping_add(g);

        pb = pb.wrapping_add(b);
        pg = pg.wrapping_add(g);
        pr = pr.wrapping_add(r);
        pa = pa.wrapping_add(a_delta);

        let base = x * 4;
        scanline[base] = pb;
        scanline[base + 1] = pg;
        scanline[base + 2] = pr;
        scanline[base + 3] = pa;
    }
}

/// Compose 3-channel colors with previous line reference (non-first lines).
/// Ported from TVPTLG5ComposeColors3To4_c in tvpgl.cpp.
#[inline]
fn compose_colors_3to4(
    scanline: &mut [u8],
    prevline: &[u8],
    buf: [&[u8]; 3],
    offset: usize,
    width: usize,
) {
    let mut pc = [0u8; 3];
    for x in 0..width {
        // buf layout: [0]=R channel, [1]=G channel, [2]=B channel
        // C++ code: c[2]=buf[0], c[1]=buf[1], c[0]=buf[2] then c[0]+=c[1], c[2]+=c[1]
        let c1 = buf[1][offset + x]; // G delta
        let c0 = buf[2][offset + x].wrapping_add(c1); // B+G delta
        let c2 = buf[0][offset + x].wrapping_add(c1); // R+G delta

        pc[0] = pc[0].wrapping_add(c0);
        pc[1] = pc[1].wrapping_add(c1);
        pc[2] = pc[2].wrapping_add(c2);

        let base = x * 4;
        scanline[base] = pc[0].wrapping_add(prevline[base]);         // B
        scanline[base + 1] = pc[1].wrapping_add(prevline[base + 1]); // G
        scanline[base + 2] = pc[2].wrapping_add(prevline[base + 2]); // R
        scanline[base + 3] = 0xff;                                    // A
    }
}

/// Compose 4-channel colors with previous line reference.
/// Ported from TVPTLG5ComposeColors4To4_c in tvpgl.cpp.
#[inline]
fn compose_colors_4to4(
    scanline: &mut [u8],
    prevline: &[u8],
    buf: [&[u8]; 4],
    offset: usize,
    width: usize,
) {
    let mut pc = [0u8; 4];
    for x in 0..width {
        let c1 = buf[1][offset + x]; // G
        let c0 = buf[2][offset + x].wrapping_add(c1); // B+G
        let c2 = buf[0][offset + x].wrapping_add(c1); // R+G
        let c3 = buf[3][offset + x]; // A

        pc[0] = pc[0].wrapping_add(c0);
        pc[1] = pc[1].wrapping_add(c1);
        pc[2] = pc[2].wrapping_add(c2);
        pc[3] = pc[3].wrapping_add(c3);

        let base = x * 4;
        scanline[base] = pc[0].wrapping_add(prevline[base]);
        scanline[base + 1] = pc[1].wrapping_add(prevline[base + 1]);
        scanline[base + 2] = pc[2].wrapping_add(prevline[base + 2]);
        scanline[base + 3] = pc[3].wrapping_add(prevline[base + 3]);
    }
}

/// Decode a TLG5 image from a stream reader.
/// Returns (width, height, colors, pixel_data) where pixel_data is BGRA.
pub fn decode_tlg5(reader: &mut StreamReader) -> Result<(i32, i32, i32, Vec<u8>), TlgError> {
    // Read header
    let mut mark = [0u8; 1];
    reader.read_exact(&mut mark)?;
    let colors = mark[0] as i32;

    let width = reader.read_i32_le()? as i32;
    let height = reader.read_i32_le()? as i32;
    let blockheight = reader.read_i32_le()? as i32;

    if colors != 3 && colors != 4 {
        return Err(TlgError::UnsupportedColorType(colors));
    }

    if width <= 0 || height <= 0 || blockheight <= 0 {
        return Err(TlgError::InvalidDimensions(width, height));
    }

    let blockcount = ((height - 1) / blockheight) + 1;

    // Skip block size section
    reader.skip(blockcount as u64 * 4)?;

    // Allocate output
    let stride = width as usize * 4;
    let mut pixels = vec![0u8; stride * height as usize];

    // Allocate working buffers
    let buf_size = (blockheight as usize) * (width as usize);
    let mut outbufs: Vec<Vec<u8>> = (0..colors as usize)
        .map(|_| vec![0u8; buf_size + 16])
        .collect();
    let mut text = [0u8; 4096];
    let mut r = 0usize;

    let mut first_line = true;

    for y_blk in (0..height).step_by(blockheight as usize) {
        // Read and decompress each channel
        for c in 0..colors as usize {
            let mut flag = [0u8; 1];
            reader.read_exact(&mut flag)?;
            let size = reader.read_i32_le()? as usize;

            if flag[0] == 0 {
                // LZSS compressed
                let mut inbuf = vec![0u8; size];
                reader.read_exact(&mut inbuf)?;
                outbufs[c].clear();
                r = lzss_decompress_slide(&inbuf, &mut outbufs[c], &mut text, r);
            } else {
                // Raw data
                outbufs[c].resize(size, 0);
                reader.read_exact(&mut outbufs[c])?;
            }
        }

        // Compose colors and store
        let y_lim = std::cmp::min(y_blk + blockheight, height) as usize;
        let mut offsets = vec![0usize; colors as usize];
        let w = width as usize;

        for y in y_blk as usize..y_lim {
            let line_start = y * stride;
            let scanline = &mut pixels[line_start..line_start + stride];

            if first_line {
                match colors {
                    3 => {
                        let bufs: [&[u8]; 3] = [&outbufs[0], &outbufs[1], &outbufs[2]];
                        compose_first_line_3(scanline, &bufs, offsets[0], w);
                    }
                    4 => {
                        let bufs: [&[u8]; 4] =
                            [&outbufs[0], &outbufs[1], &outbufs[2], &outbufs[3]];
                        compose_first_line_4(scanline, &bufs, offsets[0], w);
                    }
                    _ => unreachable!(),
                }
                first_line = false;
            } else {
                let prev_start = (y - 1) * stride;
                // Need to split pixels to avoid borrow conflict
                let (before, after) = pixels.split_at_mut(line_start);
                let prevline = &before[prev_start..prev_start + stride];
                let scanline = &mut after[..stride];

                match colors {
                    3 => {
                        let bufs: [&[u8]; 3] = [&outbufs[0], &outbufs[1], &outbufs[2]];
                        compose_colors_3to4(scanline, prevline, bufs, offsets[0], w);
                    }
                    4 => {
                        let bufs: [&[u8]; 4] =
                            [&outbufs[0], &outbufs[1], &outbufs[2], &outbufs[3]];
                        compose_colors_4to4(scanline, prevline, bufs, offsets[0], w);
                    }
                    _ => unreachable!(),
                }
            }

            for c in 0..colors as usize {
                offsets[c] += w;
            }
        }
    }

    Ok((width, height, colors, pixels))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lzss_all_literals() {
        // In this LZSS variant: flag bit=0 → literal, bit=1 → back-reference
        // Flag byte 0x00 → all 8 bits are 0 → all 8 following bytes are literals
        let input = [0x00u8, b'A', b'B', b'C', b'D', b'E', b'F', b'G', b'H'];
        let mut output = Vec::new();
        let mut text = [0u8; 4096];
        lzss_decompress_slide(&input, &mut output, &mut text, 0);
        assert_eq!(&output, b"ABCDEFGH");
    }

    #[test]
    fn test_lzss_empty_input() {
        let input: [u8; 0] = [];
        let mut output = Vec::new();
        let mut text = [0u8; 4096];
        let r = lzss_decompress_slide(&input, &mut output, &mut text, 0);
        assert_eq!(output.len(), 0);
        assert_eq!(r, 0);
    }

    #[test]
    fn test_lzss_text_buffer_updated() {
        // After decompressing literals, the text buffer should reflect them
        let input = [0x00u8, b'X', b'Y', b'Z', 0, 0, 0, 0, 0];
        let mut output = Vec::new();
        let mut text = [0u8; 4096];
        let r = lzss_decompress_slide(&input, &mut output, &mut text, 0);
        assert_eq!(text[0], b'X');
        assert_eq!(text[1], b'Y');
        assert_eq!(text[2], b'Z');
        assert_eq!(r, 8); // 8 bytes written to text buffer
    }
}

