"""
SwasthAI Sound ML - Automated PyTorch Pipeline Tests
"""

import os
import unittest
import numpy as np
import torch
from sound_ml.src.preprocessing.audio_transforms import load_audio_wav, AudioAugmentation
from sound_ml.src.preprocessing.spectrogram import LogMelSpectrogramExtractor
from sound_ml.src.models.cnn_model import RespiratoryCNN
from sound_ml.src.models.pretraining_autoencoder import MaskedSpectrogramAutoencoder
from sound_ml.src.models.baseline import extract_classical_features

class TestSoundMLPipeline(unittest.TestCase):
    def test_audio_transforms_and_spectrogram(self):
        # Create dummy sine wave audio
        sr = 4000
        t = np.linspace(0, 5.0, int(sr * 5.0), endpoint=False)
        dummy_audio = 0.5 * np.sin(2 * np.pi * 200 * t).astype(np.float32)
        
        # Test Spectrogram Extractor
        extractor = LogMelSpectrogramExtractor(sample_rate=sr, n_fft=512, hop_length=128, n_mels=64)
        tensor_audio = torch.from_numpy(dummy_audio).float()
        spec = extractor(tensor_audio)
        
        self.assertEqual(spec.dim(), 4) # [1, 1, 64, 157]
        self.assertEqual(spec.shape[1], 1)
        self.assertEqual(spec.shape[2], 64)
        
    def test_respiratory_cnn_forward(self):
        model = RespiratoryCNN(in_channels=1, num_classes=2, base_filters=16, n_blocks=4)
        dummy_spec = torch.randn(2, 1, 64, 157)
        logits = model(dummy_spec)
        self.assertEqual(logits.shape, (2, 2))
        
    def test_masked_autoencoder_forward(self):
        mae = MaskedSpectrogramAutoencoder(in_channels=1, base_filters=16)
        dummy_spec = torch.randn(2, 1, 64, 157)
        recon = mae(dummy_spec, mask_prob=0.3)
        self.assertEqual(recon.shape, dummy_spec.shape)
        
    def test_classical_feature_extractor(self):
        sr = 4000
        t = np.linspace(0, 5.0, int(sr * 5.0), endpoint=False)
        dummy_audio = 0.5 * np.sin(2 * np.pi * 200 * t).astype(np.float32)
        feats = extract_classical_features(dummy_audio, sr)
        self.assertGreater(len(feats), 15)
        self.assertFalse(np.isnan(feats).any())

if __name__ == '__main__':
    unittest.main()
