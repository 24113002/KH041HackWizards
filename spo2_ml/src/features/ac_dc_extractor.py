"""
SwasthAI SpO2 & PPG ML - AC/DC Separation & Classical R-Ratio Extraction Module
"""

import numpy as np
import scipy.signal

class ACDCExtractor:
    def __init__(self, sampling_rate: float = 100.0):
        self.sampling_rate = sampling_rate

    def compute_ac_dc(self, raw_signal: np.ndarray, ac_signal: np.ndarray) -> dict:
        """
        Calculates AC RMS, DC mean, and AC/DC ratio for a single PPG channel.
        """
        raw_signal = np.asarray(raw_signal, dtype=np.float64)
        ac_signal = np.asarray(ac_signal, dtype=np.float64)
        
        # DC is mean baseline absorption
        dc = float(np.mean(raw_signal))
        # AC is RMS of the bandpass pulsatile component
        ac = float(np.sqrt(np.mean(ac_signal ** 2)))
        
        # AC/DC Modulation index
        if abs(dc) > 1e-5:
            ac_dc_ratio = float(ac / abs(dc))
        else:
            ac_dc_ratio = 0.0
            
        return {
            'dc': dc,
            'ac': ac,
            'ac_dc_ratio': ac_dc_ratio
        }

    def compute_r_ratio(self, red_dict: dict, ir_dict: dict) -> dict:
        """
        Calculates the classical Optical Modulation Ratio R:
        R = (AC_RED / DC_RED) / (AC_IR / DC_IR)
        """
        ac_dc_red = red_dict['ac_dc_ratio']
        ac_dc_ir = ir_dict['ac_dc_ratio']
        
        if ac_dc_ir > 1e-6 and ac_dc_red > 1e-6:
            r_ratio = float(ac_dc_red / ac_dc_ir)
        else:
            r_ratio = np.nan
            
        # Classical empirical SpO2 calibration curve (MAX30102 standard calibration)
        # SpO2 = 110.0 - 25.0 * R  (linear)
        # SpO2 = -45.060 * R^2 + 30.354 * R + 94.845 (quadratic)
        if not np.isnan(r_ratio) and 0.2 <= r_ratio <= 2.5:
            spo2_linear = float(np.clip(110.0 - 25.0 * r_ratio, 70.0, 100.0))
            spo2_quad = float(np.clip(-45.060 * (r_ratio**2) + 30.354 * r_ratio + 94.845, 70.0, 100.0))
        else:
            spo2_linear = np.nan
            spo2_quad = np.nan
            
        return {
            'r_ratio': r_ratio,
            'spo2_estimated_linear': spo2_linear,
            'spo2_estimated_quad': spo2_quad
        }
