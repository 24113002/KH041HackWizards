"""
SwasthAI Sound ML - Log-Mel Spectrogram Transformation Module
"""

import torch
import torch.nn as nn
import torchaudio.transforms as T
import numpy as np

class LogMelSpectrogramExtractor(nn.Module):
    """
    Extracts Log-Mel Spectrograms from 1D audio waveform tensors.
    """
    def __init__(
        self,
        sample_rate: int = 4000,
        n_fft: int = 512,
        hop_length: int = 128,
        n_mels: int = 64,
        f_min: float = 50.0,
        f_max: float = 2000.0,
        top_db: float = 80.0
    ):
        super().__init__()
        self.sample_rate = sample_rate
        self.n_fft = n_fft
        self.hop_length = hop_length
        self.n_mels = n_mels
        self.f_min = f_min
        self.f_max = f_max
        self.top_db = top_db
        
        self.mel_spectrogram = T.MelSpectrogram(
            sample_rate=sample_rate,
            n_fft=n_fft,
            win_length=n_fft,
            hop_length=hop_length,
            f_min=f_min,
            f_max=f_max,
            n_mels=n_mels,
            power=2.0
        )
        self.amplitude_to_db = T.AmplitudeToDB(top_db=top_db)
        
    def forward(self, waveform: torch.Tensor) -> torch.Tensor:
        """
        Input: waveform of shape [Batch, Samples] or [Samples]
        Output: Log-Mel Spectrogram of shape [Batch, 1, n_mels, time_steps]
        """
        if waveform.dim() == 1:
            waveform = waveform.unsqueeze(0)
            
        mel_spec = self.mel_spectrogram(waveform)
        log_mel_spec = self.amplitude_to_db(mel_spec)
        
        # Instance standard scaling per spectrogram
        mean = log_mel_spec.mean(dim=(-2, -1), keepdim=True)
        std = log_mel_spec.std(dim=(-2, -1), keepdim=True) + 1e-6
        norm_spec = (log_mel_spec - mean) / std
        
        if norm_spec.dim() == 3:
            norm_spec = norm_spec.unsqueeze(1) # [Batch, 1, n_mels, time_steps]
            
        return norm_spec
