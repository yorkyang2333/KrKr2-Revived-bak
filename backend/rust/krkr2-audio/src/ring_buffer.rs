use std::slice;

pub struct AudioRingBuffer<T: Copy> {
    buffer: Vec<T>,
    size: usize,
    write_pos: usize,
    read_pos: usize,
    data_size: usize,
}

impl<T: Copy + Default> AudioRingBuffer<T> {
    pub fn new(size: usize) -> Self {
        Self {
            buffer: vec![T::default(); size],
            size,
            write_pos: 0,
            read_pos: 0,
            data_size: 0,
        }
    }

    pub fn get_size(&self) -> usize { self.size }
    pub fn get_write_pos(&self) -> usize { self.write_pos }
    pub fn get_read_pos(&self) -> usize { self.read_pos }
    pub fn get_data_size(&self) -> usize { self.data_size }
    pub fn get_free_size(&self) -> usize { self.size - self.data_size }

    pub fn get_read_pointers(&self, readsize: usize, offset: isize) -> (&[T], &[T]) {
        let mut pos = (self.read_pos as isize + offset) as usize;
        while pos >= self.size { pos -= self.size; }

        if readsize + pos > self.size {
            let p1size = self.size - pos;
            let p1 = &self.buffer[pos..pos + p1size];
            let p2size = readsize - p1size;
            let p2 = &self.buffer[0..p2size];
            (p1, p2)
        } else {
            let p1 = &self.buffer[pos..pos + readsize];
            (p1, &[])
        }
    }

    pub fn advance_read_pos(&mut self, advance: usize) {
        self.read_pos += advance;
        if self.read_pos >= self.size {
            self.read_pos -= self.size;
        }
        self.data_size -= advance;
    }

    pub fn get_first(&self) -> T {
        self.buffer[self.read_pos]
    }

    pub fn get_at(&self, n: usize) -> T {
        let mut pos = self.read_pos + n;
        while pos >= self.size { pos -= self.size; }
        self.buffer[pos]
    }

    pub fn get_write_pointers_mut(&mut self, writesize: usize, offset: isize) -> (&mut [T], &mut [T]) {
        let mut pos = (self.write_pos as isize + offset) as usize;
        while pos >= self.size { pos -= self.size; }

        if writesize + pos > self.size {
            let p1size = self.size - pos;
            let p2size = writesize - p1size;
            // Since we need to return two mutable slices, we split the buffer
            let (part1, part2) = self.buffer.split_at_mut(pos);
            let p1 = &mut part2[0..p1size];
            let p2 = &mut part1[0..p2size];
            (p1, p2)
        } else {
            let p1 = &mut self.buffer[pos..pos + writesize];
            (p1, &mut [])
        }
    }

    pub fn advance_write_pos(&mut self, advance: usize) {
        self.write_pos += advance;
        if self.write_pos >= self.size {
            self.write_pos -= self.size;
        }
        self.data_size += advance;
    }

    pub fn advance_write_pos_with_discard(&mut self, advance: usize) {
        self.write_pos += advance;
        if self.write_pos >= self.size {
            self.write_pos -= self.size;
        }
        self.data_size += advance;
        if self.data_size > self.size {
            let overflow = self.data_size - self.size;
            self.advance_read_pos(overflow);
        }
    }

    pub fn get_last(&mut self) -> &mut T {
        &mut self.buffer[self.write_pos]
    }
}
