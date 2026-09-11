"""
SwasthAI Sound ML - PyTorch Dataset Classes
"""

import os
import torch
from torch.utils.data import Dataset
import numpy as np
from ..preprocessing.audio_transforms import load_audio_wav, AudioAugmentation
from ..preprocessing.spectrogram import LogMelSpectrogramExtractor

class RespiratoryAudioDataset(Dataset):
    """
    PyTorch Dataset for Labelled Respiratory Sound Recordings.
    """
    def __init__(
        self,
        records: list,
        sample_rate: int = 4000,
        target_duration_sec: float = 5.0,
        n_fft: int = 512,
        hop_length: int = 128,
        n_mels: int = 64,
        f_min: float = 50.0,
        f_max: float = 2000.0,
        is_train: bool = False,
        augmentation: AudioAugmentation = None
    ):
        self.records = records
        self.sample_rate = sample_rate
        self.target_duration_sec = target_duration_sec
        self.is_train = is_train
        self.augmentation = augmentation if (is_train and augmentation) else None
        
        self.extractor = LogMelSpectrogramExtractor(
            sample_rate=sample_rate,
            n_fft=n_fft,
            hop_length=hop_length,
            n_mels=n_mels,
            f_min=f_min,
            f_max=f_max
        )
        
    def __len__(self):
        return len(self.records)
        
    def __getitem__(self, idx):
        rec = self.records[idx]
        file_path = rec['file_path']
        label = rec['label']
        
        # 1. Load Audio
        audio = load_audio_wav(file_path, self.sample_rate, self.target_duration_sec)
        
        # 2. Waveform Augmentation (Train only)
        if self.augmentation:
            audio = self.augmentation.augment_waveform(audio)
            
        waveform_tensor = torch.from_numpy(audio).float()
        
        # 3. Log-Mel Spectrogram Extraction
        with torch.no_grad():
            spec = self.extractor(waveform_tensor) # [1, 1, n_mels, time_steps]
            spec = spec.squeeze(0) # [1, n_mels, time_steps]
            
        # 4. Spectrogram Augmentation (Train only)
        if self.augmentation:
            spec = self.augmentation.augment_spectrogram(spec)
            
        return {
            'spectrogram': spec,
            'label': torch.tensor(label, dtype=torch.long),
            'patient_id': rec.get('patient_id', ''),
            'file_name': rec.get('file_name', '')
        }

class UnlabelledAudioDataset(Dataset):
    """
    PyTorch Dataset for Unlabelled Audio Files (Dataset 2 - ICBHI pretraining).
    """
    def __init__(
        self,
        audio_paths: list,
        sample_rate: int = 4000,
        target_duration_sec: float = 5.0,
        n_fft: int = 512,
        hop_length: int = 128,
        n_mels: int = 64
    ):
        self.audio_paths = audio_paths
        self.sample_rate = sample_rate
        self.target_duration_sec = target_duration_sec
        self.extractor = LogMelSpectrogramExtractor(
            sample_rate=sample_rate,
            n_fft=n_fft,
            hop_length=hop_length,
            n_mels=n_mels
        )
        
    def __len__(self):
        return len(self.audio_paths)
        
    def __getitem__(self, idx):
        path = self.audio_paths[idx]
        audio = load_audio_wav(path, self.sample_rate, self.target_duration_sec)
        waveform_tensor = torch.from_numpy(audio).float()
        with torch.no_grad():
            spec = self.extractor(waveform_tensor).squeeze(0)
        return spec
