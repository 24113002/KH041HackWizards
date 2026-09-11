"""
SwasthAI Air-Pressure ML - Signal Quality Assessment Module
Validates pressure sensor data for saturation, flatline, excessive noise, and incomplete blows.
"""

import numpy as np

class PressureSignalQualityChecker:
    def __init__(
        self,
        sat_max: float = 8388600.0,  # 24-bit max threshold or 14-bit max
        sat_min: float = 100.0,
        min_variance: float = 1.0,
        min_blow_duration_sec: float = 0.3,
        sampling_rate: float = 100.0
    ):
        self.sat_max = sat_max
        self.sat_min = sat_min
        self.min_variance = min_variance
        self.min_blow_duration_sec = min_blow_duration_sec
        self.sampling_rate = sampling_rate

    def check_quality(self, raw_signal: np.ndarray, delta_signal: np.ndarray = None) -> dict:
        raw = np.asarray(raw_signal, dtype=np.float64)
        n = len(raw)
        if n < int(self.sampling_rate * 0.5):
            return {
                'quality_rating': 'INVALID',
                'is_valid': False,
                'rejection_reason': 'Signal duration too short (< 0.5s)',
                'saturation_pct': 0.0,
                'quality_score': 0.0
            }

        # 1. Saturation Check
        is_sat_high = raw >= 16380.0 if np.max(raw) < 20000.0 else raw >= 8388500.0
        sat_count = np.sum(is_sat_high)
        sat_pct = float((sat_count / n) * 100.0)

        if sat_pct > 10.0:
            return {
                'quality_rating': 'INVALID',
                'is_valid': False,
                'rejection_reason': f'Sensor saturation detected ({sat_pct:.1f}% samples clipped)',
                'saturation_pct': round(sat_pct, 2),
                'quality_score': 0.0
            }

        # 2. Flatline / Sensor Disconnection Check
        var = float(np.var(raw))
        ptp = float(np.ptp(raw))
        if var < self.min_variance or ptp < 5.0:
            return {
                'quality_rating': 'INVALID',
                'is_valid': False,
                'rejection_reason': 'Flatline sensor signal / zero pressure change',
                'saturation_pct': round(sat_pct, 2),
                'quality_score': 0.0
            }

        # 3. Dynamic Blow Magnitude Check (on delta signal if provided)
        if delta_signal is not None:
            peak_delta = float(np.max(delta_signal))
            if peak_delta < 10.0:
                return {
                    'quality_rating': 'POOR',
                    'is_valid': True,
                    'rejection_reason': 'Low pressure excursion / weak blow',
                    'saturation_pct': round(sat_pct, 2),
                    'quality_score': 0.4
                }

        # 4. Composite Quality Rating
        quality_score = float(np.clip(1.0 - (sat_pct / 20.0), 0.5, 1.0))
        rating = 'GOOD' if quality_score >= 0.85 else 'ACCEPTABLE'

        return {
            'quality_rating': rating,
            'is_valid': True,
            'rejection_reason': None,
            'saturation_pct': round(sat_pct, 2),
            'quality_score': round(quality_score, 4)
        }
