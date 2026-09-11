"""
SwasthAI SpO2 & PPG ML - Classical R-Ratio Baseline & Pulse Oximetry Engine
Implements classical pulse oximetry calculation for ESP32 + MAX30102 hardware.
"""

import numpy as np
import scipy.signal

class ClassicalPulseOximeter:
    def __init__(self, sampling_rate: float = 100.0):
        self.sampling_rate = sampling_rate

    def calculate_spo2(self, red: np.ndarray, ir: np.ndarray) -> dict:
        """
        Classical AC/DC R-Ratio SpO2 calculation.
        R = (AC_RED / DC_RED) / (AC_IR / DC_IR)
        SpO2 = 110.0 - 25.0 * R
        """
        red = np.asarray(red, dtype=np.float64)
        ir = np.asarray(ir, dtype=np.float64)
        
        # 1. DC components
        dc_red = float(np.mean(red))
        dc_ir = float(np.mean(ir))
        
        if dc_red < 100 or dc_ir < 100:
            return {
                'status': 'INVALID_SIGNAL',
                'spo2': None,
                'r_ratio': None,
                'heart_rate_bpm': None,
                'reason': 'Insufficient signal amplitude / DC baseline'
            }
            
        # 2. AC components using 0.5 - 5 Hz bandpass
        nyq = 0.5 * self.sampling_rate
        sos = scipy.signal.butter(4, [0.5/nyq, min(0.99, 4.5/nyq)], btype='bandpass', output='sos')
        ac_red_filt = scipy.signal.sosfiltfilt(sos, red)
        ac_ir_filt = scipy.signal.sosfiltfilt(sos, ir)
        
        ac_red = float(np.sqrt(np.mean(ac_red_filt ** 2)))
        ac_ir = float(np.sqrt(np.mean(ac_ir_filt ** 2)))
        
        ac_dc_red = ac_red / dc_red
        ac_dc_ir = ac_ir / dc_ir
        
        if ac_dc_ir > 1e-6:
            r_ratio = ac_dc_red / ac_dc_ir
            spo2 = float(np.clip(110.0 - 25.0 * r_ratio, 70.0, 100.0))
        else:
            r_ratio = None
            spo2 = None
            
        # 3. Heart Rate (BPM) from IR pulsatile peaks
        peaks, _ = scipy.signal.find_peaks(ac_ir_filt, distance=int(0.4 * self.sampling_rate), prominence=0.15*np.ptp(ac_ir_filt))
        if len(peaks) >= 2:
            ibi = np.mean(np.diff(peaks)) / self.sampling_rate
            hr_bpm = float(np.clip(60.0 / ibi, 40.0, 180.0))
        else:
            hr_bpm = None
            
        return {
            'status': 'SUCCESS' if spo2 is not None else 'INVALID_SIGNAL',
            'spo2': round(spo2, 1) if spo2 is not None else None,
            'r_ratio': round(r_ratio, 4) if r_ratio is not None else None,
            'heart_rate_bpm': round(hr_bpm, 1) if hr_bpm is not None else None,
            'ac_red': round(ac_red, 2),
            'dc_red': round(dc_red, 2),
            'ac_ir': round(ac_ir, 2),
            'dc_ir': round(dc_ir, 2)
        }
