"""
SwasthAI Air-Pressure ML - Filtering & Conditioning Module
Applies zero-phase lowpass Butterworth filtering and median filtering to preserve respiratory morphology.
"""

import numpy as np
import scipy.signal

class RespiratoryFilter:
    def __init__(self, cutoff_hz: float = 5.0, order: int = 3, sampling_rate: float = 100.0):
        self.cutoff_hz = cutoff_hz
        self.order = order
        self.sampling_rate = sampling_rate
        self._init_filter()

    def _init_filter(self):
        nyquist = 0.5 * self.sampling_rate
        norm_cutoff = min(0.99, self.cutoff_hz / nyquist)
        self.sos = scipy.signal.butter(self.order, norm_cutoff, btype='lowpass', output='sos')

    def lowpass_filter(self, signal: np.ndarray) -> np.ndarray:
        """
        Applies zero-phase forward-backward Butterworth lowpass filtering.
        """
        signal = np.asarray(signal, dtype=np.float64)
        if len(signal) < 15:
            return signal
        return scipy.signal.sosfiltfilt(self.sos, signal)

    def median_filter(self, signal: np.ndarray, kernel_size: int = 5) -> np.ndarray:
        """
        Removes impulse noise / single-sample ADC spikes.
        """
        if kernel_size % 2 == 0:
            kernel_size += 1
        return scipy.signal.medfilt(signal, kernel_size=kernel_size)

    def process(self, signal: np.ndarray) -> np.ndarray:
        """
        Complete filter pipeline: median filter followed by zero-phase lowpass.
        """
        cleaned = self.median_filter(signal)
        return self.lowpass_filter(cleaned)
