//! Ring buffer for chunked STT: 30s chunks with 10s overlap, bounded
//! memory, no allocation on the audio hot path once warmed up.

use crate::decode::TARGET_SAMPLE_RATE;

pub const CHUNK_SECS: f64 = 30.0;
pub const OVERLAP_SECS: f64 = 10.0;

pub struct RingBuffer {
    samples: Vec<f32>,
    capacity: usize,
    chunk_len: usize,
    overlap_len: usize,
}

impl RingBuffer {
    pub fn new(sample_rate: u32) -> Self {
        Self::with_durations(sample_rate, CHUNK_SECS, OVERLAP_SECS)
    }

    pub fn with_durations(sample_rate: u32, chunk_secs: f64, overlap_secs: f64) -> Self {
        let chunk_len = (sample_rate as f64 * chunk_secs) as usize;
        let overlap_len = (sample_rate as f64 * overlap_secs) as usize;
        Self {
            samples: Vec::with_capacity(chunk_len * 2),
            capacity: chunk_len * 2,
            chunk_len,
            overlap_len,
        }
    }

    pub fn push(&mut self, incoming: &[f32]) {
        self.samples.extend_from_slice(incoming);
        if self.samples.len() > self.capacity {
            let excess = self.samples.len() - self.capacity;
            self.samples.drain(0..excess);
        }
    }

    /// Ready when we have a full chunk buffered.
    pub fn is_chunk_ready(&self) -> bool {
        self.samples.len() >= self.chunk_len
    }

    /// Drain one chunk, retaining the last `overlap_len` samples for the
    /// next chunk (context continuity across chunk boundaries).
    pub fn take_chunk(&mut self) -> Option<Vec<f32>> {
        if !self.is_chunk_ready() {
            return None;
        }
        let chunk: Vec<f32> = self.samples[..self.chunk_len].to_vec();
        let keep_from = self.chunk_len.saturating_sub(self.overlap_len);
        self.samples.drain(0..keep_from);
        Some(chunk)
    }

    pub fn buffered_samples(&self) -> usize {
        self.samples.len()
    }

    pub fn usage_ratio(&self) -> f32 {
        (self.samples.len() as f32 / self.capacity as f32).min(1.0)
    }

    pub fn clear(&mut self) {
        self.samples.clear();
    }
}

impl Default for RingBuffer {
    fn default() -> Self {
        Self::new(TARGET_SAMPLE_RATE)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn not_ready_before_chunk_filled() {
        let mut rb = RingBuffer::with_durations(1000, 1.0, 0.2);
        rb.push(&vec![0.0; 500]);
        assert!(!rb.is_chunk_ready());
        assert!(rb.take_chunk().is_none());
    }

    #[test]
    fn ready_and_drains_full_chunk() {
        let mut rb = RingBuffer::with_durations(1000, 1.0, 0.2);
        rb.push(&vec![1.0; 1000]);
        assert!(rb.is_chunk_ready());
        let chunk = rb.take_chunk().unwrap();
        assert_eq!(chunk.len(), 1000);
    }

    #[test]
    fn retains_overlap_after_drain() {
        let mut rb = RingBuffer::with_durations(1000, 1.0, 0.2);
        rb.push(&vec![1.0; 1000]);
        rb.take_chunk().unwrap();
        // 200 samples (0.2s overlap) should remain buffered.
        assert_eq!(rb.buffered_samples(), 200);
    }

    #[test]
    fn caps_memory_at_capacity_bound() {
        let mut rb = RingBuffer::with_durations(1000, 1.0, 0.2);
        // Push far more than capacity (2000) without draining via take_chunk.
        rb.push(&vec![0.0; 10_000]);
        assert!(rb.buffered_samples() <= 2000);
    }

    #[test]
    fn usage_ratio_bounded() {
        let mut rb = RingBuffer::with_durations(1000, 1.0, 0.2);
        rb.push(&vec![0.0; 50_000]);
        let ratio = rb.usage_ratio();
        assert!(ratio <= 1.0);
    }

    #[test]
    fn clear_resets_buffer() {
        let mut rb = RingBuffer::with_durations(1000, 1.0, 0.2);
        rb.push(&vec![0.0; 500]);
        rb.clear();
        assert_eq!(rb.buffered_samples(), 0);
    }
}
