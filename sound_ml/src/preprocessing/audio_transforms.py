"""
SwasthAI Sound ML - Audio Loading, Normalization, Resampling & Augmentation
"""

import os
import wave
import numpy as np
import scipy.signal
import torch

def load_audio_wav(file_path: str, target_sr: int = 4000, target_duration_sec: float = 5.0) -> np.ndarray:
    """
    Loads a WAV file, converts to mono, resamples to target_sr, and pads/crops to fixed duration.
    """
    with wave.open(file_path, 'rb') as wf:
        n_channels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        orig_sr = wf.getframerate()
        n_frames = wf.getnframes()
        raw_bytes = wf.readframes(n_frames)
        
    # Convert byte buffer to float32 numpy array
    if sampwidth == 2:
        dtype = np.int16
    elif sampwidth == 3:
        # 24-bit PCM
        a = np.frombuffer(raw_bytes, dtype=np.uint8)
        b = np.zeros(len(a) // 3, dtype=np.int32)
        b = (a[0::3].astype(np.int32) << 8) | (a[1::3].astype(np.int32) << 16) | (a[2::3].astype(np.int32) << 24)
        audio = (b / (2**31)).astype(np.float32)
        dtype = None
    elif sampwidth == 1:
        dtype = np.uint8
    else:
        dtype = np.int16
        
    if dtype is not None:
        audio = np.frombuffer(raw_bytes, dtype=dtype).astype(np.float32)
        if dtype == np.int16:
            audio = audio / 32768.0
        elif dtype == np.uint8:
            audio = (audio - 128.0) / 128.0
            
    # Handle multi-channel to mono
    if n_channels > 1:
        audio = audio.reshape(-1, n_channels).mean(axis=1)
        
    # Resample if sample rate doesn't match
    if orig_sr != target_sr and orig_sr > 0:
        num_target_samples = int(round(len(audio) * float(target_sr) / orig_sr))
        audio = scipy.signal.resample(audio, num_target_samples)
        
    # Amplitude normalization (peak normalize to max 0.95)
    max_val = np.max(np.abs(audio))
    if max_val > 1e-6:
        audio = audio / max_val * 0.95
        
    # Fixed duration cropping / padding
    target_samples = int(round(target_sr * target_duration_sec))
    if len(audio) < target_samples:
        pad_width = target_samples - len(audio)
        audio = np.pad(audio, (0, pad_width), mode='constant')
    elif len(audio) > target_samples:
        audio = audio[:target_samples]
        
    return audio.astype(np.float32)

class AudioAugmentation:
    """
    Training-time data augmentations for respiratory sound waveforms and spectrograms.
    """
    def __init__(
        self,
        time_shift_pct: float = 0.10,
        amplitude_scale_range: tuple = (0.85, 1.15),
        freq_mask_param: int = 8,
        time_mask_param: int = 16,
        noise_snr_db: float = 30.0
    ):
        self.time_shift_pct = time_shift_pct
        self.amplitude_scale_range = amplitude_scale_range
        self.freq_mask_param = freq_mask_param
        self.time_mask_param = time_mask_param
        self.noise_snr_db = noise_snr_db
        
    def augment_waveform(self, audio: np.ndarray) -> np.ndarray:
        # 1. Random Time Shift
        if np.random.rand() > 0.5:
            shift_max = int(len(audio) * self.time_shift_pct)
            shift = np.random.randint(-shift_max, shift_max)
            audio = np.roll(audio, shift)
            
        # 2. Amplitude Scaling
        if np.random.rand() > 0.5:
            scale = np.random.uniform(self.amplitude_scale_range[0], self.amplitude_scale_range[1])
            audio = audio * scale
            
        # 3. Additive Gaussian White Noise
        if np.random.rand() > 0.5:
            signal_power = np.mean(audio ** 2)
            if signal_power > 1e-7:
                snr_linear = 10 ** (self.noise_snr_db / 10.0)
                noise_power = signal_power / snr_linear
                noise = np.random.normal(0, np.sqrt(noise_power), len(audio))
                audio = audio + noise
                
        return audio.astype(np.float32)
        
    def augment_spectrogram(self, spec: torch.Tensor) -> torch.Tensor:
        """
        SpecAugment (Frequency and Time masking on spectrogram tensor [C, Freq, Time]).
        """
        spec = spec.clone()
        c, f, t = spec.shape
        
        # Frequency masking
        if np.random.rand() > 0.5 and self.freq_mask_param > 0:
            f_mask = np.random.randint(0, self.freq_mask_param)
            f0 = np.random.randint(0, max(1, f - f_mask))
            spec[:, f0:f0 + f_mask, :] = 0.0
            
        # Time masking
        if np.random.rand() > 0.5 and self.time_mask_param > 0:
            t_mask = np.random.randint(0, self.time_mask_param)
            t0 = np.random.randint(0, max(1, t - t_mask))
            spec[:, :, t0:t0 + t_mask] = 0.0
            
        return spec
