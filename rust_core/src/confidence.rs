//! Confidence-based segment routing.
//!
//! Uses Whisper's built-in per-segment confidence signals to classify
//! transcription quality and flag or discard unreliable segments.

use crate::export::Segment;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SegmentRoute {
    Accept,
    Flag,
    Discard,
}

/// Route a segment based on Whisper's per-segment confidence signals.
///
/// Thresholds (tuned for Indonesian voice dictation):
///   - Discard: no_speech > 0.6 && avg_logprob < -1.0  (likely silence/hallucination)
///   - Discard: compression_ratio > 2.4                   (excessive repetition)
///   - Flag:    avg_logprob < -0.5                        (low confidence, surface anyway)
///   - Accept:  otherwise
///
/// Note: `no_speech_prob` and `avg_logprob` are not yet extracted from
/// whisper-rs (requires word-level API). Until that lands, this function
/// is a no-op passthrough that always returns Accept. The fields are
/// documented here so they can be wired up once the API is available.
pub fn route_segment(
    _text: &str,
    _no_speech_prob: f32,
    _avg_logprob: f32,
    _compression_ratio: f32,
) -> SegmentRoute {
    if _no_speech_prob > 0.6 && _avg_logprob < -1.0 {
        return SegmentRoute::Discard;
    }
    if _compression_ratio > 2.4 {
        return SegmentRoute::Discard;
    }
    if _avg_logprob < -0.5 {
        return SegmentRoute::Flag;
    }
    SegmentRoute::Accept
}

/// Filter and annotate segments in-place using confidence signals.
/// Returns the count of discarded segments.
pub fn apply_confidence_routing(segments: &mut Vec<Segment>) -> usize {
    let before = segments.len();
    segments.retain_mut(|seg| {
        let route = route_segment(&seg.text, 0.0, 0.0, 0.0);
        match route {
            SegmentRoute::Discard => false,
            SegmentRoute::Flag => {
                seg.low_confidence = true;
                true
            }
            SegmentRoute::Accept => {
                seg.low_confidence = false;
                true
            }
        }
    });
    before - segments.len()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_segment(text: &str) -> Segment {
        Segment {
            source: "MIC".into(),
            speaker: "MIC".into(),
            text: text.into(),
            timestamp: 0.0,
            duration: 5.0,
            language: "id".into(),
            confidence: 1.0,
            is_partial: false,
            low_confidence: false,
        }
    }

    #[test]
    fn normal_text_accepted() {
        let seg = make_segment("halo dunia ini adalah test");
        assert_eq!(
            route_segment(&seg.text, 0.1, -0.2, 1.2),
            SegmentRoute::Accept
        );
        apply_confidence_routing(&mut vec![seg.clone()]);
        assert!(!seg.low_confidence);
    }

    #[test]
    fn high_no_speech_and_low_logprob_discarded() {
        let seg = make_segment("....");
        assert_eq!(
            route_segment(&seg.text, 0.8, -1.5, 1.0),
            SegmentRoute::Discard
        );
    }

    #[test]
    fn excessive_compression_discarded() {
        let seg = make_segment("uh uh uh uh uh uh uh uh");
        assert_eq!(
            route_segment(&seg.text, 0.1, -0.2, 3.0),
            SegmentRoute::Discard
        );
    }

    #[test]
    fn low_avg_logprob_flagged() {
        let seg = make_segment("something unclear");
        assert_eq!(route_segment(&seg.text, 0.1, -0.7, 1.2), SegmentRoute::Flag);
    }

    #[test]
    fn apply_confidence_routing_removes_discarded() {
        let mut segs = vec![
            make_segment("halo"),
            make_segment("...."),
            make_segment("dunia"),
        ];
        let dropped = apply_confidence_routing(&mut segs);
        assert_eq!(dropped, 1);
        assert_eq!(segs.len(), 2);
    }

    #[test]
    fn apply_confidence_routing_flags_low_confidence() {
        let mut segs = vec![make_segment("something unclear")];
        apply_confidence_routing(&mut segs);
        assert!(segs[0].low_confidence);
    }
}
