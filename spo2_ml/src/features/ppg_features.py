"""
SwasthAI SpO2 & PPG ML - Comprehensive PPG Feature Extractor
Extracts statistical, morphological, frequency-domain, and relational PPG features.
"""

import numpy as np
import scipy.signal
import scipy.stats

class PPGFeatureExtractor:
    def __init__(self, sampling_rate: float = 100.0):
        self.sampling_rate = sampling_rate

    def extract_statistical_features(self, signal: np.ndarray, prefix: str = "") -> dict:
        signal = np.asarray(signal, dtype=np.float64)
        mean_val = float(np.mean(signal))
        std_val = float(np.std(signal))
        median_val = float(np.median(signal))
        min_val = float(np.min(signal))
        max_val = float(np.max(signal))
        ptp_val = float(max_val - min_val)
        rms_val = float(np.sqrt(np.mean(signal ** 2)))
        var_val = float(np.var(signal))
        skew_val = float(scipy.stats.skew(signal)) if std_val > 1e-6 else 0.0
        kurt_val = float(scipy.stats.kurtosis(signal)) if std_val > 1e-6 else 0.0
        q75, q25 = np.percentile(signal, [75, 25])
        iqr_val = float(q75 - q25)
        
        p = f"{prefix}_" if prefix else ""
        return {
            f"{p}mean": mean_val,
            f"{p}std": std_val,
            f"{p}median": median_val,
            f"{p}min": min_val,
            f"{p}max": max_val,
            f"{p}ptp": ptp_val,
            f"{p}rms": rms_val,
            f"{p}variance": var_val,
            f"{p}skewness": skew_val,
            f"{p}kurtosis": kurt_val,
            f"{p}iqr": iqr_val
        }

    def extract_morphology_features(self, signal: np.ndarray, prefix: str = "") -> dict:
        signal = np.asarray(signal, dtype=np.float64)
        min_dist = max(5, int(0.4 * self.sampling_rate)) # Max 150 BPM
        prominence = max(0.01, 0.15 * np.ptp(signal))
        
        peaks, props = scipy.signal.find_peaks(signal, distance=min_dist, prominence=prominence, width=2)
        n_peaks = len(peaks)
        
        p = f"{prefix}_" if prefix else ""
        if n_peaks >= 2:
            ibis = np.diff(peaks) / float(self.sampling_rate) # in seconds
            ibi_mean = float(np.mean(ibis))
            ibi_std = float(np.std(ibis))
            bpm = float(60.0 / ibi_mean) if ibi_mean > 0 else 0.0
            
            peak_heights = signal[peaks]
            amp_mean = float(np.mean(peak_heights))
            amp_std = float(np.std(peak_heights))
        else:
            ibi_mean = 0.0
            ibi_std = 0.0
            bpm = 0.0
            amp_mean = 0.0
            amp_std = 0.0
            
        return {
            f"{p}pulse_count": n_peaks,
            f"{p}pulse_rate_bpm": bpm,
            f"{p}pulse_interval_mean": ibi_mean,
            f"{p}pulse_interval_std": ibi_std,
            f"{p}pulse_amplitude_mean": amp_mean,
            f"{p}pulse_amplitude_std": amp_std
        }

    def extract_frequency_features(self, signal: np.ndarray, prefix: str = "") -> dict:
        signal = np.asarray(signal, dtype=np.float64)
        n = len(signal)
        fft_vals = np.fft.rfft(signal)
        fft_mag = np.abs(fft_vals)
        freqs = np.fft.rfftfreq(n, d=1.0/self.sampling_rate)
        
        # Energy & Power
        power = fft_mag ** 2
        total_power = float(np.sum(power)) + 1e-9
        
        # Dominant Frequency
        if len(power) > 1:
            dom_idx = np.argmax(power[1:]) + 1 # skip DC bin
            dom_freq = float(freqs[dom_idx])
        else:
            dom_freq = 0.0
            
        # Spectral Centroid
        centroid = float(np.sum(freqs * power) / total_power)
        
        # Spectral Entropy
        prob = power / total_power
        prob = prob[prob > 1e-12]
        spectral_entropy = float(-np.sum(prob * np.log2(prob)))
        
        p = f"{prefix}_" if prefix else ""
        return {
            f"{p}dominant_freq_hz": dom_freq,
            f"{p}spectral_centroid_hz": centroid,
            f"{p}spectral_energy": total_power,
            f"{p}spectral_entropy": spectral_entropy
        }

    def extract_relational_features(self, red: np.ndarray, ir: np.ndarray) -> dict:
        red = np.asarray(red, dtype=np.float64)
        ir = np.asarray(ir, dtype=np.float64)
        
        # Correlation
        if np.std(red) > 1e-6 and np.std(ir) > 1e-6:
            corr = float(np.corrcoef(red, ir)[0, 1])
            cov = float(np.cov(red, ir)[0, 1])
        else:
            corr = 0.0
            cov = 0.0
            
        # Ratio
        mean_red = np.mean(red)
        mean_ir = np.mean(ir)
        red_ir_ratio = float(mean_red / mean_ir) if abs(mean_ir) > 1e-6 else 1.0
        
        return {
            'red_ir_correlation': corr,
            'red_ir_covariance': cov,
            'red_ir_ratio': red_ir_ratio
        }
