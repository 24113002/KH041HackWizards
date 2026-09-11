"""
SwasthAI SpO2 & PPG ML - Signal Quality Assessment Module
Evaluates PPG signal usability, saturation, baseline drift, and pulse prominence.
"""

import numpy as np
import scipy.signal

class SignalQualityChecker:
    def __init__(
        self,
        saturation_max: float = 262140.0,
        saturation_min: float = 1000.0,
        min_valid_samples_pct: float = 0.85,
        min_snr_db: float = 5.0
    ):
        self.saturation_max = saturation_max
        self.saturation_min = saturation_min
        self.min_valid_samples_pct = min_valid_samples_pct
        self.min_snr_db = min_snr_db

    def check_quality(self, signal: np.ndarray, sr: float = 100.0) -> dict:
        """
        Evaluates a 1D PPG signal window (RED or IR) and returns quality metrics & rating.
        """
        if signal is None or len(signal) == 0:
            return {
                'quality_rating': 'INVALID',
                'is_valid': False,
                'saturation_pct': 100.0,
                'invalid_pct': 100.0,
                'snr_db': -99.0,
                'quality_score': 0.0,
                'rejection_reason': 'Empty or null signal array'
            }

        signal = np.asarray(signal, dtype=np.float64)
        n = len(signal)
        
        # 1. Saturation Check (ADC Max Saturation or Sensor Detachment Floor)
        is_sat_high = signal >= self.saturation_max
        is_sat_low = signal <= self.saturation_min
        sat_count = np.sum(is_sat_high | is_sat_low)
        sat_pct = (sat_count / n) * 100.0
        
        # 2. NaN / Inf Check
        nan_count = np.sum(np.isnan(signal) | np.isinf(signal))
        invalid_pct = (nan_count / n) * 100.0
        
        if sat_pct > 15.0:
            return {
                'quality_rating': 'INVALID',
                'is_valid': False,
                'saturation_pct': round(sat_pct, 2),
                'invalid_pct': round(invalid_pct, 2),
                'snr_db': -99.0,
                'quality_score': 0.0,
                'rejection_reason': f'Signal saturation exceeded threshold ({sat_pct:.1f}% saturated)'
            }
            
        if invalid_pct > (100.0 - self.min_valid_samples_pct * 100.0):
            return {
                'quality_rating': 'INVALID',
                'is_valid': False,
                'saturation_pct': round(sat_pct, 2),
                'invalid_pct': round(invalid_pct, 2),
                'snr_db': -99.0,
                'quality_score': 0.0,
                'rejection_reason': 'Excessive invalid / NaN samples'
            }

        # 3. Variance & Dynamic Range Check
        variance = float(np.var(signal))
        dynamic_range = float(np.ptp(signal))
        
        if variance < 1e-7 or dynamic_range < 1e-5:
            return {
                'quality_rating': 'INVALID',
                'is_valid': False,
                'saturation_pct': round(sat_pct, 2),
                'invalid_pct': round(invalid_pct, 2),
                'snr_db': -99.0,
                'quality_score': 0.0,
                'rejection_reason': 'Flatline signal / zero variance'
            }

        # 4. Signal-to-Noise Ratio (Pulsatile Band 0.5 - 4.0 Hz vs High-Frequency / Motion Noise)
        try:
            sig_ac = signal - np.mean(signal)
            sos_band = scipy.signal.butter(4, [0.5, 4.0], btype='bandpass', fs=sr, output='sos')
            pulsatile = scipy.signal.sosfiltfilt(sos_band, sig_ac)
            residual_noise = sig_ac - pulsatile
            
            p_signal = np.mean(pulsatile ** 2)
            p_noise = np.mean(residual_noise ** 2) + 1e-9
            snr_db = float(10.0 * np.log10(p_signal / p_noise))
        except Exception:
            snr_db = 0.0

        # 5. Composite Signal Quality Score (0.0 to 1.0)
        # Higher score = clearer pulsatile morphology
        quality_score = float(np.clip(0.5 + (snr_db / 30.0) - (sat_pct / 50.0), 0.0, 1.0))
        
        if snr_db >= 10.0 and sat_pct < 2.0:
            rating = 'GOOD'
        elif snr_db >= 5.0 and sat_pct < 10.0:
            rating = 'ACCEPTABLE'
        elif snr_db >= 0.0:
            rating = 'POOR'
        else:
            rating = 'INVALID'

        return {
            'quality_rating': rating,
            'is_valid': rating != 'INVALID',
            'saturation_pct': round(sat_pct, 2),
            'invalid_pct': round(invalid_pct, 2),
            'snr_db': round(snr_db, 2),
            'quality_score': round(quality_score, 4),
            'rejection_reason': None if rating != 'INVALID' else 'Low SNR / poor pulsatile signal'
        }
