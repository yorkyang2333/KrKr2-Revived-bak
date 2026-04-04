use std::collections::VecDeque;
use crate::ffi::{WaveSegment, WaveLabel};

pub struct WaveSegmentQueue_Rust {
    pub segments: VecDeque<WaveSegment>,
    pub labels: VecDeque<WaveLabel>,
}

impl WaveSegmentQueue_Rust {
    pub fn new() -> Box<Self> {
        Box::new(Self {
            segments: VecDeque::new(),
            labels: VecDeque::new(),
        })
    }

    pub fn clear(&mut self) {
        self.segments.clear();
        self.labels.clear();
    }

    pub fn enqueue_segment(&mut self, segment: &WaveSegment) {
        if let Some(last) = self.segments.back_mut() {
            if last.start + last.length == segment.start {
                let last_ratio = last.filtered_length as f64 / last.length as f64;
                let seg_ratio = segment.filtered_length as f64 / segment.length as f64;
                if (last_ratio - seg_ratio).abs() < f64::EPSILON {
                    last.filtered_length += segment.filtered_length;
                    last.length += segment.length;
                    return;
                }
            }
        }
        self.segments.push_back(segment.clone());
    }

    pub fn enqueue_label(&mut self, label: &WaveLabel) {
        self.labels.push_back(label.clone());
    }

    pub fn enqueue_queue(&mut self, queue: &WaveSegmentQueue_Rust) {
        let label_offset = self.get_filtered_length();
        for label in &queue.labels {
            let mut new_label = label.clone();
            new_label.offset += label_offset as i32;
            self.enqueue_label(&new_label);
        }
        for segment in &queue.segments {
            self.enqueue_segment(segment);
        }
    }

    pub fn dequeue(&mut self, dest: &mut WaveSegmentQueue_Rust, length: i64) {
        dest.clear();
        let mut remain = length;
        
        while let Some(mut front) = self.segments.pop_front() {
            if remain <= 0 {
                self.segments.push_front(front);
                break;
            }
            if front.filtered_length <= remain {
                remain -= front.filtered_length;
                dest.enqueue_segment(&front);
            } else {
                let newlength = ((front.length as f64 / front.filtered_length as f64) * remain as f64) as i64;
                if newlength > 0 {
                    dest.enqueue_segment(&WaveSegment {
                        start: front.start,
                        length: newlength,
                        filtered_length: remain,
                    });
                }
                
                front.start += newlength;
                front.length -= newlength;
                front.filtered_length -= remain;
                
                if front.length > 0 && front.filtered_length > 0 {
                    self.segments.push_front(front);
                }
                break;
            }
        }

        let mut labels_to_dequeue = 0;
        for label in &mut self.labels {
            let newoffset = label.offset as i64 - length;
            if newoffset < 0 {
                dest.enqueue_label(&WaveLabel {
                    position: label.position,
                    name: label.name.clone(),
                    offset: label.offset,
                });
                labels_to_dequeue += 1;
            } else {
                label.offset = newoffset as i32;
            }
        }

        for _ in 0..labels_to_dequeue {
            self.labels.pop_front();
        }
    }

    pub fn get_filtered_length(&self) -> i64 {
        self.segments.iter().map(|s| s.filtered_length).sum()
    }

    pub fn scale(&mut self, new_total_filtered_length: i64) {
        let total_length_was = self.get_filtered_length();
        if total_length_was == 0 { return; }

        let mut offset_was = 0;
        let mut offset_is = 0;

        for segment in &mut self.segments {
            let old_end = offset_was + segment.filtered_length;
            offset_was += segment.filtered_length;

            let ratio = old_end as f64 / total_length_was as f64;
            let new_end = (ratio * new_total_filtered_length as f64) as i64;

            segment.filtered_length = new_end - offset_is;
            offset_is += segment.filtered_length;
        }

        self.segments.retain(|s| s.filtered_length > 0 && s.length > 0);

        let ratio = new_total_filtered_length as f64 / total_length_was as f64;
        for label in &mut self.labels {
            label.offset = (label.offset as f64 * ratio) as i32;
        }
    }

    pub fn filtered_position_to_decode_position(&self, pos: i64) -> i64 {
        let mut offset_filtered = 0;

        for segment in &self.segments {
            if offset_filtered <= pos && pos < offset_filtered + segment.filtered_length {
                return segment.start + ((pos - offset_filtered) as f64 * (segment.length as f64 / segment.filtered_length as f64)) as i64;
            }
            offset_filtered += segment.filtered_length;
        }

        if pos < 0 || self.segments.is_empty() { return 0; }
        let last = self.segments.back().unwrap();
        last.start + last.length
    }
    
    pub fn get_segments_len(&self) -> usize {
        self.segments.len()
    }
    
    pub fn get_segment(&self, index: usize) -> WaveSegment {
        self.segments[index].clone()
    }
    
    pub fn get_labels_len(&self) -> usize {
        self.labels.len()
    }
    
    pub fn get_label(&self, index: usize) -> WaveLabel {
        self.labels[index].clone()
    }
}
