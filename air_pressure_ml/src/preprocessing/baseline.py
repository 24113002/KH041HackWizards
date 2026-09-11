"""
SwasthAI Air-Pressure ML - Resting Baseline Module
Computes resting baseline statistics and delta signals (raw - baseline) per session.
"""

import numpy as np

class BaselineEstimator:
    def __init__(self, rest_window_sec: float = 0.5, sampling_rate: float = 100.0):
        self.rest_window_sec = rest_window_sec
        self.sampling_rate = sampling_rate
        self.rest_samples = int(rest_window_sec * sampling_rate)

    def estimate_baseline(self, raw_signal: np.ndarray) -> dict:
        """
        Calculates baseline parameters independently for each trial/session.
        """
        raw = np.asarray(raw_signal, dtype=np.float64)
        n = len(raw)
        if n == 0:
            return {
                'baseline_mean': 0.0,
                'baseline_median': 0.0,
                'baseline_std': 0.0,
                'baseline_min': 0.0,
                'baseline_max': 0.0,
                'baseline_range': 0.0,
                'baseline_drift': 0.0,
                'stability_score': 0.0,
                'is_stable': False
            }

        k = min(self.rest_samples, n // 4) if n >= 4 else n
        if k < 5:
            # Fallback to lowest 10% percentile values
            low_thresh = np.percentile(raw, 10)
            rest_segment = raw[raw <= low_thresh]
            if len(rest_segment) == 0:
                rest_segment = raw[:k]
        else:
            rest_segment = raw[:k]

        b_mean = float(np.mean(rest_segment))
        b_median = float(np.median(rest_segment))
        b_std = float(np.std(rest_segment))
        b_min = float(np.min(rest_segment))
        b_max = float(np.max(rest_segment))
        b_range = b_max - b_min

        # Baseline drift: difference between starting rest and trailing end rest
        end_segment = raw[-k:] if k > 0 else rest_segment
        end_mean = float(np.mean(end_segment))
        drift = abs(end_mean - b_mean)

        # Baseline stability score (0.0 to 1.0)
        stability_score = float(np.clip(1.0 - (b_std / (abs(b_mean) + 1e-5)) * 10.0 - (drift / (abs(b_mean) + 1e-5)) * 5.0, 0.0, 1.0))
        is_stable = bool(stability_score >= 0.5 and b_std < max(50.0, abs(b_mean) * 0.05))

        return {
            'baseline_mean': round(b_mean, 2),
            'baseline_median': round(b_median, 2),
            'baseline_std': round(b_std, 4),
            'baseline_min': round(b_min, 2),
            'baseline_max': round(b_max, 2),
            'baseline_range': round(b_range, 2),
            'baseline_drift': round(drift, 2),
            'stability_score': round(stability_score, 4),
            'is_stable': is_stable
        }

    def compute_delta(self, raw_signal: np.ndarray, baseline_mean: float) -> np.ndarray:
        """
        Calculates baseline-corrected delta signal: delta = raw - baseline_mean
        """
        raw = np.asarray(raw_signal, dtype=np.float64)
        return raw - baseline_mean
