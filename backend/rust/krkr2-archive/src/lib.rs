use std::collections::HashMap;
use std::io::{Read, Write};
use std::sync::{Arc, Mutex};
use flate2::read::ZlibDecoder;

#[cxx::bridge(namespace = "krkr2::archive")]
pub mod ffi {
    struct Xp3ItemInfo {
        name: String,
        org_size: u64,
        arc_size: u64,
        file_hash: u32,
    }

    #[namespace = "krkr2::bridge"]
    unsafe extern "C++" {
        include!("krkr2_bridge_glue.h");
        type BinaryStreamWrapper;
        fn seek(self: &BinaryStreamWrapper, offset: i64, whence: i32) -> u64;
        fn read_buffer(self: &BinaryStreamWrapper, buf: &mut [u8]);
        fn read_i64_le(self: &BinaryStreamWrapper) -> u64;
        fn read(self: &BinaryStreamWrapper, buf: &mut [u8]) -> u32;
    }

    extern "Rust" {
        type Xp3Archive;
        // Opens the archive and parses the index
        fn open_xp3_archive(
            stream: UniquePtr<BinaryStreamWrapper>,
            offset: u64,
            name: String,
        ) -> Result<Box<Xp3Archive>>;

        // Accessors for info
        fn get_count(self: &Xp3Archive) -> u32;
        fn get_item_info(self: &Xp3Archive, idx: u32) -> Result<Xp3ItemInfo>;

        // Creates a read stream for a particular file index
        type Xp3Stream;
        fn create_stream_by_index(
            self: &Xp3Archive,
            idx: u32,
            stream: UniquePtr<BinaryStreamWrapper>,
        ) -> Result<Box<Xp3Stream>>;

        fn read(self: &mut Xp3Stream, buf: &mut [u8]) -> u32;
        fn seek(self: &mut Xp3Stream, offset: i64, whence: i32) -> u64;
    }
}

const TVP_XP3_INDEX_ENCODE_METHOD_MASK: u8 = 0x07;
const TVP_XP3_INDEX_ENCODE_RAW: u8 = 0;
const TVP_XP3_INDEX_ENCODE_ZLIB: u8 = 1;
const TVP_XP3_INDEX_CONTINUE: u8 = 0x80;

const TVP_XP3_SEGM_ENCODE_METHOD_MASK: u32 = 0x07;
const TVP_XP3_SEGM_ENCODE_RAW: u32 = 0;
const TVP_XP3_SEGM_ENCODE_ZLIB: u32 = 1;

const TVP_SEGCACHE_ONE_LIMIT: usize = 1024 * 1024;
const TVP_SEGCACHE_TOTAL_LIMIT: usize = 1024 * 1024;

#[derive(Clone)]
struct Xp3Segment {
    start: u64,
    offset: u64,
    org_size: u64,
    arc_size: u64,
    is_compressed: bool,
}

struct Xp3Item {
    name: String,
    file_hash: u32,
    org_size: u64,
    arc_size: u64,
    segments: Vec<Xp3Segment>,
}

// Global segment cache to share uncompressed segments across streams
lazy_static::lazy_static! {
    static ref SEGMENT_CACHE: Mutex<SegmentCache> = Mutex::new(SegmentCache::new());
}

struct SegmentCache {
    cache: HashMap<String, Arc<Vec<u8>>>,
    total_bytes: usize,
}

impl SegmentCache {
    fn new() -> Self {
        SegmentCache {
            cache: HashMap::new(),
            total_bytes: 0,
        }
    }

    fn key(archive_name: &str, storage_idx: u32, segment_idx: usize) -> String {
        format!("{}_{}_{}", archive_name, storage_idx, segment_idx)
    }

    fn get(&self, key: &str) -> Option<Arc<Vec<u8>>> {
        self.cache.get(key).cloned()
    }

    fn insert(&mut self, key: String, data: Vec<u8>) {
        if data.len() >= TVP_SEGCACHE_ONE_LIMIT {
            return;
        }

        self.total_bytes += data.len();
        self.cache.insert(key, Arc::new(data));

        while self.total_bytes > TVP_SEGCACHE_TOTAL_LIMIT {
            // Very naive eviction: just remove the first element until under limit
            // Wait, we can't easily pop arbitrary without cloning keys or using a proper LRU. 
            // Let's just clear the hashmap if it gets too full to keep it simple, 
            // since this is just a quick optimization cache.
            self.total_bytes = 0;
            self.cache.clear();
            break;
        }
    }
}

pub struct Xp3Archive {
    items: Vec<Xp3Item>,
    name: String,
}

impl Xp3Archive {
    pub fn get_count(&self) -> u32 {
        self.items.len() as u32
    }

    pub fn get_item_info(&self, idx: u32) -> Result<ffi::Xp3ItemInfo, String> {
        let item = self.items.get(idx as usize).ok_or("Index out of bounds")?;
        Ok(ffi::Xp3ItemInfo {
            name: item.name.clone(),
            org_size: item.org_size,
            arc_size: item.arc_size,
            file_hash: item.file_hash,
        })
    }

    pub fn create_stream_by_index(
        &self,
        idx: u32,
        stream: cxx::UniquePtr<ffi::BinaryStreamWrapper>,
    ) -> Result<Box<Xp3Stream>, String> {
        let item = self.items.get(idx as usize).ok_or("Index out of bounds")?;
        
        Ok(Box::new(Xp3Stream {
            stream,
            segments: item.segments.clone(),
            org_size: item.org_size,
            archive_name: self.name.clone(),
            storage_index: idx,
            cur_pos: 0,
            cur_segment_idx: 0,
            segment_opened: false,
            segment_data: None,
        }))
    }
}

pub struct Xp3Stream {
    stream: cxx::UniquePtr<ffi::BinaryStreamWrapper>,
    segments: Vec<Xp3Segment>,
    org_size: u64,
    archive_name: String,
    storage_index: u32,
    
    cur_pos: u64,
    cur_segment_idx: usize,
    segment_opened: bool,
    segment_data: Option<Arc<Vec<u8>>>,
}

impl Xp3Stream {
    fn ensure_segment(&mut self) -> Result<(), String> {
        if self.segment_opened {
            return Ok(());
        }

        let seg = &self.segments[self.cur_segment_idx];

        if !seg.is_compressed {
            let offset_in_seg = self.cur_pos - seg.offset;
            self.stream.seek((seg.start + offset_in_seg) as i64, 0); // SEEK_SET
            self.segment_data = None;
        } else {
            let cache_key = SegmentCache::key(&self.archive_name, self.storage_index, self.cur_segment_idx);
            
            let cached_segment = SEGMENT_CACHE.lock().unwrap().get(&cache_key);
            
            // Check cache
            if let Some(cached) = cached_segment {
                self.segment_data = Some(cached);
            } else {
                // Read and uncompress
                self.stream.seek(seg.start as i64, 0);
                
                let mut comp_data = vec![0u8; seg.arc_size as usize];
                self.stream.read_buffer(&mut comp_data);
                
                let mut decoder = ZlibDecoder::new(&comp_data[..]);
                let mut uncompressed = Vec::with_capacity(seg.org_size as usize);
                decoder.read_to_end(&mut uncompressed).map_err(|e| format!("Zlib decode error: {}", e))?;
                
                if uncompressed.len() as u64 != seg.org_size {
                    return Err("Uncompressed size mismatch".into());
                }

                let uncompressed = Arc::new(uncompressed);
                if seg.org_size >= TVP_SEGCACHE_ONE_LIMIT as u64 {
                    self.segment_data = Some(uncompressed);
                } else {
                    let mut lock = SEGMENT_CACHE.lock().unwrap();
                    lock.insert(cache_key.clone(), (*uncompressed).clone());
                    self.segment_data = Some(uncompressed);
                }
            }
        }

        self.segment_opened = true;
        Ok(())
    }

    fn open_next_segment(&mut self) -> bool {
        if self.cur_segment_idx + 1 >= self.segments.len() {
            return false;
        }
        self.cur_segment_idx += 1;
        self.segment_opened = false;
        let seg = &self.segments[self.cur_segment_idx];
        self.cur_pos = seg.offset;
        self.ensure_segment().is_ok()
    }

    fn seek_to_position(&mut self, pos: u64) {
        if self.cur_pos == pos {
            return;
        }

        // Binary search to find containing segment
        let mut idx = 0;
        for (i, seg) in self.segments.iter().enumerate() {
            if pos >= seg.offset && pos < seg.offset + seg.org_size {
                idx = i;
                break;
            } else if pos == seg.offset + seg.org_size && i == self.segments.len() - 1 {
                // End of stream
                idx = i;
                break;
            }
        }

        self.cur_segment_idx = idx;
        self.segment_opened = false;
        self.cur_pos = pos;
    }

    pub fn read(&mut self, buf: &mut [u8]) -> u32 {
        if self.ensure_segment().is_err() {
            return 0;
        }

        let mut write_size = 0;
        let mut read_rem = buf.len();

        while read_rem > 0 {
            let seg = &self.segments[self.cur_segment_idx];
            let offset_in_seg = self.cur_pos - seg.offset;
            let seg_rem = seg.org_size - offset_in_seg;

            if seg_rem == 0 {
                if !self.open_next_segment() {
                    break;
                }
                continue;
            }

            let one_size = std::cmp::min(read_rem as u64, seg_rem) as usize;

            if seg.is_compressed {
                // Copy from uncompressed buffer
                if let Some(ref data) = self.segment_data {
                    let src = &data[offset_in_seg as usize .. offset_in_seg as usize + one_size];
                    buf[write_size .. write_size + one_size].copy_from_slice(src);
                } else {
                    break; // Error state
                }
            } else {
                // Read directly from stream
                let mut temp = vec![0u8; one_size];
                self.stream.read_buffer(&mut temp);
                buf[write_size .. write_size + one_size].copy_from_slice(&temp);
            }

            write_size += one_size;
            read_rem -= one_size;
            self.cur_pos += one_size as u64;
        }

        write_size as u32
    }

    pub fn seek(&mut self, offset: i64, whence: i32) -> u64 {
        let newpos = match whence {
            0 => offset, // SEEK_SET
            1 => self.cur_pos as i64 + offset, // SEEK_CUR
            2 => self.org_size as i64 + offset, // SEEK_END
            _ => return self.cur_pos,
        };

        if newpos >= 0 && newpos <= self.org_size as i64 {
            self.seek_to_position(newpos as u64);
        }
        self.cur_pos
    }
}

pub fn open_xp3_archive(
    stream: cxx::UniquePtr<ffi::BinaryStreamWrapper>,
    offset: u64,
    name: String,
) -> Result<Box<Xp3Archive>, String> {
    
    // Create a parser
    stream.seek((11 + offset) as i64, 0);

    let mut items = Vec::new();

    loop {
        let index_ofs = stream.read_i64_le();
        stream.seek((index_ofs + offset) as i64, 0);

        let mut flag_buf = [0u8; 1];
        stream.read_buffer(&mut flag_buf);
        let index_flag = flag_buf[0];

        let index_data = match index_flag & TVP_XP3_INDEX_ENCODE_METHOD_MASK {
            TVP_XP3_INDEX_ENCODE_ZLIB => {
                let compressed_size = stream.read_i64_le();
                let r_index_size = stream.read_i64_le();
                
                let mut compressed = vec![0u8; compressed_size as usize];
                stream.read_buffer(&mut compressed);

                let mut decoder = ZlibDecoder::new(&compressed[..]);
                let mut index_data = Vec::with_capacity(r_index_size as usize);
                decoder.read_to_end(&mut index_data).map_err(|e| format!("Zlib decode error: {}", e))?;
                
                index_data
            }
            TVP_XP3_INDEX_ENCODE_RAW => {
                let r_index_size = stream.read_i64_le();
                let mut index_data = vec![0u8; r_index_size as usize];
                stream.read_buffer(&mut index_data);
                index_data
            }
            _ => return Err("Unknown encode method".into()),
        };

        // Parse chunks from index_data
        let mut ch_file_start = 0;
        let mut ch_file_size = index_data.len();

        while let Some((file_start, file_size)) = find_chunk(&index_data, b"File", ch_file_start, ch_file_size) {
            
            // Find info subchunk
            let (info_start, _info_size) = find_chunk(&index_data, b"info", file_start, file_size)
                .ok_or("No info chunk")?;
                
            let _flags = read_i32(&index_data[info_start..]);
            let org_size = read_i64(&index_data[info_start + 4..]);
            let arc_size = read_i64(&index_data[info_start + 12..]);
            let name_len = read_i16(&index_data[info_start + 20..]) as usize;
            
            // utf16 decoding
            let name_bytes = &index_data[info_start + 22 .. info_start + 22 + name_len * 2];
            let name_u16: Vec<u16> = name_bytes.chunks_exact(2)
                .map(|c| u16::from_le_bytes([c[0], c[1]]))
                .collect();
            let parsed_name = String::from_utf16_lossy(&name_u16);
            let parsed_name = parsed_name.replace('\\', "/"); // normalize quickly

            // Find segm subchunk
            let (segm_start, segm_size) = find_chunk(&index_data, b"segm", file_start, file_size)
                .ok_or("No segm chunk")?;

            let segment_count = segm_size / 28;
            let mut segments = Vec::with_capacity(segment_count);
            let mut offset_in_archive = 0;

            for i in 0..segment_count {
                let pos_base = segm_start + i * 28;
                let flags = read_i32(&index_data[pos_base..]) as u32;
                
                let is_compressed = match flags & TVP_XP3_SEGM_ENCODE_METHOD_MASK {
                    TVP_XP3_SEGM_ENCODE_RAW => false,
                    TVP_XP3_SEGM_ENCODE_ZLIB => true,
                    _ => return Err("Unknown segm encode method".into()),
                };

                let seg_start = read_i64(&index_data[pos_base + 4..]) as u64 + offset;
                let seg_org_size = read_i64(&index_data[pos_base + 12..]) as u64;
                let seg_arc_size = read_i64(&index_data[pos_base + 20..]) as u64;

                segments.push(Xp3Segment {
                    start: seg_start,
                    offset: offset_in_archive,
                    org_size: seg_org_size,
                    arc_size: seg_arc_size,
                    is_compressed,
                });
                
                offset_in_archive += seg_org_size;
            }

            // Find adlr subchunk
            let (adlr_start, _) = find_chunk(&index_data, b"adlr", file_start, file_size)
                .ok_or("No adlr chunk")?;
                
            let file_hash = read_i32(&index_data[adlr_start..]) as u32;

            items.push(Xp3Item {
                name: parsed_name,
                file_hash,
                org_size: org_size as u64,
                arc_size: arc_size as u64,
                segments,
            });

            ch_file_start = file_start + file_size;
            ch_file_size = index_data.len() - ch_file_start;
        }

        if (index_flag & TVP_XP3_INDEX_CONTINUE) == 0 {
            break;
        }
    }

    // Sort by name
    items.sort_by(|a, b| a.name.cmp(&b.name));

    Ok(Box::new(Xp3Archive { items, name }))
}

fn find_chunk(data: &[u8], name: &[u8; 4], mut start: usize, size: usize) -> Option<(usize, usize)> {
    let mut pos = 0;
    while pos < size {
        if start + 12 > data.len() {
            return None;
        }
        
        let found = &data[start .. start + 4] == name;
        start += 4;
        
        let size_chunk = read_i64(&data[start..]) as usize;
        start += 8;
        
        if found {
            return Some((start, size_chunk));
        }
        
        start += size_chunk;
        pos += size_chunk + 12;
    }
    None
}

fn read_i16(data: &[u8]) -> i16 {
    i16::from_le_bytes([data[0], data[1]])
}

fn read_i32(data: &[u8]) -> i32 {
    i32::from_le_bytes([data[0], data[1], data[2], data[3]])
}

fn read_i64(data: &[u8]) -> i64 {
    let mut arr = [0u8; 8];
    arr.copy_from_slice(&data[0..8]);
    i64::from_le_bytes(arr)
}
