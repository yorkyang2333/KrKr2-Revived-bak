pub mod segment_queue;
pub mod ring_buffer;

pub use segment_queue::{WaveSegmentQueue_Rust};
pub use ring_buffer::AudioRingBuffer;

#[cxx::bridge(namespace = "krkr2::audio")]
pub mod ffi {
    #[derive(Clone, Debug)]
    pub struct WaveSegment {
        pub start: i64,
        pub length: i64,
        pub filtered_length: i64,
    }

    #[derive(Clone, Debug)]
    pub struct WaveLabel {
        pub position: i64,
        pub name: String,
        pub offset: i32,
    }

    pub struct WaveFormat {
        pub samples_per_sec: u32,
        pub channels: u32,
        pub bits_per_sample: u32,
        pub bytes_per_sample: u32,
        pub total_samples: u64,
        pub total_time: u64,
        pub speaker_config: u32,
        pub is_float: bool,
        pub seekable: bool,
    }

    extern "Rust" {
        type WaveSegmentQueue_Rust;

        fn create_wave_segment_queue() -> Box<WaveSegmentQueue_Rust>;
        
        fn clear(self: &mut WaveSegmentQueue_Rust);
        
        fn enqueue_segment(self: &mut WaveSegmentQueue_Rust, segment: &WaveSegment);
        fn enqueue_label(self: &mut WaveSegmentQueue_Rust, label: &WaveLabel);
        
        fn enqueue_queue(self: &mut WaveSegmentQueue_Rust, queue: &WaveSegmentQueue_Rust);
        
        fn dequeue(self: &mut WaveSegmentQueue_Rust, dest: &mut WaveSegmentQueue_Rust, length: i64);
        
        fn get_filtered_length(self: &WaveSegmentQueue_Rust) -> i64;
        
        fn scale(self: &mut WaveSegmentQueue_Rust, new_total_filtered_length: i64);
        
        fn filtered_position_to_decode_position(self: &WaveSegmentQueue_Rust, pos: i64) -> i64;
        
        fn get_segments_len(self: &WaveSegmentQueue_Rust) -> usize;
        fn get_segment(self: &WaveSegmentQueue_Rust, index: usize) -> WaveSegment;
        
        fn get_labels_len(self: &WaveSegmentQueue_Rust) -> usize;
        fn get_label(self: &WaveSegmentQueue_Rust, index: usize) -> WaveLabel;
    }


    struct BufferSlice {
        ptr: *mut f32,
        len: usize,
    }

    struct BufferPointers {
        p1: BufferSlice,
        p2: BufferSlice,
    }

    extern "Rust" {
        type RingBufferF32_Rust;

        fn create_ring_buffer_f32(size: usize) -> Box<RingBufferF32_Rust>;
        fn get_size(self: &RingBufferF32_Rust) -> usize;
        fn get_write_pos(self: &RingBufferF32_Rust) -> usize;
        fn get_read_pos(self: &RingBufferF32_Rust) -> usize;
        fn get_data_size(self: &RingBufferF32_Rust) -> usize;
        fn get_free_size(self: &RingBufferF32_Rust) -> usize;

        // Structured returns instead of callbacks to avoid capture issues in C++
        fn get_read_pointers(self: &RingBufferF32_Rust, readsize: usize, offset: isize) -> BufferPointers;
        fn advance_read_pos(self: &mut RingBufferF32_Rust, advance: usize);
        fn get_first(self: &RingBufferF32_Rust) -> f32;
        fn get_at(self: &RingBufferF32_Rust, n: usize) -> f32;

        fn get_write_pointers(self: &mut RingBufferF32_Rust, writesize: usize, offset: isize) -> BufferPointers;
        fn advance_write_pos(self: &mut RingBufferF32_Rust, advance: usize);
        fn advance_write_pos_with_discard(self: &mut RingBufferF32_Rust, advance: usize);
        unsafe fn get_last(self: &mut RingBufferF32_Rust) -> *mut f32;
    }
    
    // Audio Decoder Trait FFI
    extern "Rust" {
        type AudioDecoder_Rust;
        
        fn get_format(self: &mut AudioDecoder_Rust) -> WaveFormat;
        unsafe fn render(self: &mut AudioDecoder_Rust, buf: *mut u8, buf_len_bytes: usize, buf_sample_len: u32, rendered: &mut u32) -> bool;
        fn set_position(self: &mut AudioDecoder_Rust, sample_pos: u64) -> bool;
        
        fn create_audio_decoder() -> Box<AudioDecoder_Rust>;
    }
}

pub fn create_wave_segment_queue() -> Box<WaveSegmentQueue_Rust> {
    WaveSegmentQueue_Rust::new()
}

pub struct RingBufferF32_Rust {
    inner: AudioRingBuffer<f32>,
}

impl RingBufferF32_Rust {
    pub fn new(size: usize) -> Self {
        Self { inner: AudioRingBuffer::new(size) }
    }
    pub fn get_size(&self) -> usize { self.inner.get_size() }
    pub fn get_write_pos(&self) -> usize { self.inner.get_write_pos() }
    pub fn get_read_pos(&self) -> usize { self.inner.get_read_pos() }
    pub fn get_data_size(&self) -> usize { self.inner.get_data_size() }
    pub fn get_free_size(&self) -> usize { self.inner.get_free_size() }

    pub fn get_read_pointers(&self, readsize: usize, offset: isize) -> ffi::BufferPointers {
        let (p1, p2) = self.inner.get_read_pointers(readsize, offset);
        ffi::BufferPointers {
            p1: ffi::BufferSlice { ptr: p1.as_ptr() as *mut f32, len: p1.len() },
            p2: ffi::BufferSlice { ptr: p2.as_ptr() as *mut f32, len: p2.len() },
        }
    }

    pub fn advance_read_pos(&mut self, advance: usize) { self.inner.advance_read_pos(advance); }
    pub fn get_first(&self) -> f32 { self.inner.get_first() }
    pub fn get_at(&self, n: usize) -> f32 { self.inner.get_at(n) }

    pub fn get_write_pointers(&mut self, writesize: usize, offset: isize) -> ffi::BufferPointers {
        let (p1, p2) = self.inner.get_write_pointers_mut(writesize, offset);
        ffi::BufferPointers {
            p1: ffi::BufferSlice { ptr: p1.as_mut_ptr(), len: p1.len() },
            p2: ffi::BufferSlice { ptr: p2.as_mut_ptr(), len: p2.len() },
        }
    }

    pub fn advance_write_pos(&mut self, advance: usize) { self.inner.advance_write_pos(advance); }
    pub fn advance_write_pos_with_discard(&mut self, advance: usize) { self.inner.advance_write_pos_with_discard(advance); }

    pub unsafe fn get_last(&mut self) -> *mut f32 { self.inner.get_last() as *mut f32 }
}

pub fn create_ring_buffer_f32(size: usize) -> Box<RingBufferF32_Rust> {
    Box::new(RingBufferF32_Rust::new(size))
}

pub struct AudioDecoder_Rust { }

impl AudioDecoder_Rust {
    pub fn get_format(&mut self) -> ffi::WaveFormat {
        ffi::WaveFormat {
            samples_per_sec: 44100, channels: 2, bits_per_sample: 16, bytes_per_sample: 4, 
            total_samples: 0xFFFFFFFF, total_time: 0xFFFFFFFF, speaker_config: 0, is_float: false, seekable: true,
        }
    }
    
    pub unsafe fn render(&mut self, buf: *mut u8, buf_len: usize, buf_sample_len: u32, rendered: &mut u32) -> bool {
        let size_needed = (buf_sample_len * 4) as usize;
        let actual_size = std::cmp::min(size_needed, buf_len);
        std::ptr::write_bytes(buf, 0, actual_size);
        *rendered = (actual_size / 4) as u32;
        true
    }
    
    pub fn set_position(&mut self, _sample_pos: u64) -> bool {
        true
    }
}

pub fn create_audio_decoder() -> Box<AudioDecoder_Rust> {
    Box::new(AudioDecoder_Rust {})
}
