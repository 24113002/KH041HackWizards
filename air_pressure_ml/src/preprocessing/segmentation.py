"""
SwasthAI Air-Pressure ML - Respiratory Blow Segmentation Module
Detects REST, BLOW_START, ACTIVE_BLOW, PEAK, and BLOW_END across respiratory sessions.
"""

import numpy as np
import scipy.signal

class RespiratoryBlowSegmenter:
    def __init__(
        self,
        threshold_pct: float = 0.10,  # 10% of peak height for blow onset/offset
        min_peak_distance_sec: float = 1.0,
        min_prominence: float = 50.0,
        sampling_rate: float = 100.0
    ):
        self.threshold_pct = threshold_pct
        self.min_peak_distance_sec = min_peak_distance_sec
        self.min_prominence = min_prominence
        self.sampling_rate = sampling_rate

    def segment(self, delta_signal: np.ndarray) -> dict:
        """
        Segments the primary blow or dominant respiratory cycle in the delta signal.
        """
        delta = np.asarray(delta_signal, dtype=np.float64)
        n = len(delta)
        min_dist_samples = int(self.min_peak_distance_sec * self.sampling_rate)
        
        # Detect peaks
        peaks, props = scipy.signal.find_peaks(
            delta,
            distance=max(10, min_dist_samples),
            prominence=self.min_prominence,
            height=np.percentile(delta, 75)
        )

        if len(peaks) == 0:
            # Fallback: take global maximum
            peak_idx = int(np.argmax(delta))
            peak_val = float(delta[peak_idx])
            all_peaks = [peak_idx] if peak_val > 20.0 else []
        else:
            # Select dominant/highest peak for single-blow analysis or list all
            peak_idx = int(peaks[np.argmax(delta[peaks])])
            peak_val = float(delta[peak_idx])
            all_peaks = peaks.tolist()

        if peak_val <= 0:
            return {
                'has_blow': False,
                'blow_start_idx': 0,
                'blow_end_idx': n - 1,
                'peak_idx': 0,
                'peak_val': 0.0,
                'blow_duration_sec': 0.0,
                'rise_time_sec': 0.0,
                'fall_time_sec': 0.0,
                'time_to_peak_sec': 0.0,
                'all_peak_indices': []
            }

        # Onset threshold (10% of peak)
        onset_thresh = peak_val * self.threshold_pct

        # Search backward for blow start
        start_idx = 0
        for i in range(peak_idx, -1, -1):
            if delta[i] <= onset_thresh:
                start_idx = i
                break

        # Search forward for blow end
        end_idx = n - 1
        for i in range(peak_idx, n):
            if delta[i] <= onset_thresh:
                end_idx = i
                break

        # Timing durations
        dt = 1.0 / self.sampling_rate
        blow_duration = (end_idx - start_idx) * dt
        rise_time = (peak_idx - start_idx) * dt
        fall_time = (end_idx - peak_idx) * dt
        time_to_peak = peak_idx * dt

        return {
            'has_blow': True,
            'blow_start_idx': start_idx,
            'blow_end_idx': end_idx,
            'peak_idx': peak_idx,
            'peak_val': round(peak_val, 2),
            'blow_duration_sec': round(blow_duration, 3),
            'rise_time_sec': round(rise_time, 3),
            'fall_time_sec': round(fall_time, 3),
            'time_to_peak_sec': round(time_to_peak, 3),
            'all_peak_indices': all_peaks
        }
