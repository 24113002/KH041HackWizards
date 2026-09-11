"""
SwasthAI SpO2 & PPG ML - PPG Preprocessing & Filtering Module
"""

import numpy as np
import scipy.signal

class PPGPreprocessor:
    def __init__(
        self,
        sampling_rate: float = 100.0,
        bandpass_low_hz: float = 0.5,
        bandpass_high_hz: float = 5.0,
        filter_order: int = 4
    ):
        self.sampling_rate = sampling_rate
        self.bandpass_low_hz = bandpass_low_hz
        self.bandpass_high_hz = bandpass_high_hz
        self.filter_order = filter_order

    def bandpass_filter(self, signal: np.ndarray) -> np.ndarray:
        """
        Applies zero-phase Butterworth bandpass filter (0.5 - 5.0 Hz).
        """
        signal = np.asarray(signal, dtype=np.float64)
        if len(signal) < 15:
            return signal
            
        nyquist = 0.5 * self.sampling_rate
        low = self.bandpass_low_hz / nyquist
        high = min(0.99, self.bandpass_high_hz / nyquist)
        
        sos = scipy.signal.butter(self.filter_order, [low, high], btype='bandpass', output='sos')
        filtered = scipy.signal.sosfiltfilt(sos, signal)
        return filtered

    def detrend(self, signal: np.ndarray) -> np.ndarray:
        """
        Removes low-frequency baseline wander using linear / polynomial detrending.
        """
        signal = np.asarray(signal, dtype=np.float64)
        return scipy.signal.detrend(signal)

    def normalize(self, signal: np.ndarray) -> np.ndarray:
        """
        Min-Max normalizes signal into [0, 1] range.
        """
        signal = np.asarray(signal, dtype=np.float64)
        ptp = np.ptp(signal)
        if ptp > 1e-8:
            return (signal - np.min(signal)) / ptp
        return signal - np.mean(signal)

    def preprocess_pair(self, red: np.ndarray, ir: np.ndarray) -> tuple:
        """
        Preprocesses raw RED and IR signals preserving both AC (filtered) and DC (lowpass baseline) components.
        """
        red_clean = np.nan_to_num(red, nan=0.0)
        ir_clean = np.nan_to_num(ir, nan=0.0)
        
        red_ac = self.bandpass_filter(red_clean)
        ir_ac = self.bandpass_filter(ir_clean)
        
        # DC component using lowpass smoothing (moving average or lowpass filter < 0.2 Hz)
        win = max(5, int(self.sampling_rate * 0.5))
        red_dc = np.convolve(red_clean, np.ones(win)/win, mode='same')
        ir_dc = np.convolve(ir_clean, np.ones(win)/win, mode='same')
        
        return {
            'red_raw': red_clean,
            'ir_raw': ir_clean,
            'red_ac': red_ac,
            'ir_ac': ir_ac,
            'red_dc': red_dc,
            'ir_dc': ir_dc
        }
