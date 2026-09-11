"""
SwasthAI Air-Pressure ML - Respiratory Feature Extraction Module
Extracts 22 physiological, morphological, and spectral features from baseline-corrected pressure signals.
"""

import numpy as np
import scipy.signal
import scipy.stats
from ..preprocessing.filtering import RespiratoryFilter
from ..preprocessing.baseline import BaselineEstimator
from ..preprocessing.segmentation import RespiratoryBlowSegmenter
from ..preprocessing.signal_quality import PressureSignalQualityChecker

class RespiratoryFeatureExtractor:
    def __init__(self, sampling_rate: float = 100.0):
        self.sampling_rate = sampling_rate
        self.filter = RespiratoryFilter(cutoff_hz=5.0, sampling_rate=sampling_rate)
        self.baseline_est = BaselineEstimator(sampling_rate=sampling_rate)
        self.segmenter = RespiratoryBlowSegmenter(sampling_rate=sampling_rate)
        self.quality_checker = PressureSignalQualityChecker(sampling_rate=sampling_rate)

    def extract_features(self, raw_signal: np.ndarray) -> dict:
        raw = np.asarray(raw_signal, dtype=np.float64)
        
        # 1. Baseline Estimation
        b_info = self.baseline_est.estimate_baseline(raw)
        b_mean = b_info['baseline_mean']
        
        # 2. Filter & Baseline Correction
        filt_raw = self.filter.process(raw)
        delta = self.baseline_est.compute_delta(filt_raw, b_mean)
        
        # 3. Quality Check
        q_info = self.quality_checker.check_quality(raw, delta)
        if not q_info['is_valid']:
            return {
                'is_valid': False,
                'signal_quality': q_info['quality_rating'],
                'rejection_reason': q_info['rejection_reason'],
                'features': {}
            }

        # 4. Blow Segmentation
        seg_info = self.segmenter.segment(delta)
        
        # 5. Pressure & Delta Statistics
        peak_delta = float(np.max(delta))
        mean_delta = float(np.mean(delta))
        median_delta = float(np.median(delta))
        std_delta = float(np.std(delta))
        rms_delta = float(np.sqrt(np.mean(delta ** 2)))
        range_delta = float(np.ptp(delta))
        
        # 6. Derivative / Slope Features
        dt = 1.0 / self.sampling_rate
        grad = np.gradient(delta, dt)
        max_rise_rate = float(np.max(grad))
        max_fall_rate = float(np.min(grad))
        mean_rise_rate = float(np.mean(grad[grad > 0])) if np.sum(grad > 0) > 0 else 0.0
        derivative_std = float(np.std(grad))
        
        # 7. Area Features (Trapezoidal integration)
        auc_total = float(np.trapezoid(delta, dx=dt))
        auc_above_baseline = float(np.trapezoid(np.maximum(0.0, delta), dx=dt))
        
        # 8. Time Above Thresholds
        thresh_50 = peak_delta * 0.5
        time_above_50 = float(np.sum(delta >= thresh_50) * dt)
        
        # 9. Statistical & Shape Metrics
        skewness = float(scipy.stats.skew(delta))
        kurtosis = float(scipy.stats.kurtosis(delta))
        rise_time = max(0.001, seg_info['rise_time_sec'])
        fall_time = max(0.001, seg_info['fall_time_sec'])
        rise_to_fall_ratio = float(rise_time / fall_time)
        
        # 10. Frequency Domain Metrics
        nperseg = min(256, len(delta))
        freqs, psd = scipy.signal.welch(delta, fs=self.sampling_rate, nperseg=nperseg)
        dom_freq = float(freqs[np.argmax(psd)])
        spec_centroid = float(np.sum(freqs * psd) / (np.sum(psd) + 1e-9))
        psd_norm = psd / (np.sum(psd) + 1e-9)
        spec_entropy = float(-np.sum(psd_norm * np.log2(psd_norm + 1e-12)))

        features = {
            'baseline_mean': b_info['baseline_mean'],
            'baseline_std': b_info['baseline_std'],
            'baseline_drift': b_info['baseline_drift'],
            'baseline_stability': b_info['stability_score'],
            'peak_delta': round(peak_delta, 2),
            'mean_delta': round(mean_delta, 2),
            'median_delta': round(median_delta, 2),
            'std_delta': round(std_delta, 2),
            'rms_delta': round(rms_delta, 2),
            'range_delta': round(range_delta, 2),
            'rise_time_sec': round(seg_info['rise_time_sec'], 3),
            'fall_time_sec': round(seg_info['fall_time_sec'], 3),
            'blow_duration_sec': round(seg_info['blow_duration_sec'], 3),
            'time_to_peak_sec': round(seg_info['time_to_peak_sec'], 3),
            'time_above_50_pct_sec': round(time_above_50, 3),
            'max_rise_rate': round(max_rise_rate, 2),
            'max_fall_rate': round(max_fall_rate, 2),
            'mean_rise_rate': round(mean_rise_rate, 2),
            'derivative_std': round(derivative_std, 2),
            'auc_total': round(auc_total, 2),
            'auc_above_baseline': round(auc_above_baseline, 2),
            'skewness': round(skewness, 4),
            'kurtosis': round(kurtosis, 4),
            'rise_to_fall_ratio': round(rise_to_fall_ratio, 3),
            'dom_freq_hz': round(dom_freq, 3),
            'spec_centroid_hz': round(spec_centroid, 3),
            'spec_entropy': round(spec_entropy, 4),
            'signal_quality_score': q_info['quality_score']
        }

        return {
            'is_valid': True,
            'signal_quality': q_info['quality_rating'],
            'rejection_reason': None,
            'baseline_info': b_info,
            'segmentation_info': seg_info,
            'features': features
        }
