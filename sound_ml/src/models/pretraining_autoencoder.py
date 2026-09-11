"""
SwasthAI Sound ML - Self-Supervised Masked Spectrogram Autoencoder (MAE) for Dataset 2
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from .cnn_model import ConvBlock

class MaskedSpectrogramAutoencoder(nn.Module):
    """
    Self-Supervised Autoencoder that learns respiratory representations from unlabelled audio.
    """
    def __init__(self, in_channels: int = 1, base_filters: int = 16):
        super().__init__()
        
        # Encoder (mirrors RespiratoryCNN backbone)
        self.enc1 = ConvBlock(in_channels, base_filters, pool=True)     # [B, 16, F/2, T/2]
        self.enc2 = ConvBlock(base_filters, base_filters*2, pool=True)  # [B, 32, F/4, T/4]
        self.enc3 = ConvBlock(base_filters*2, base_filters*4, pool=True)# [B, 64, F/8, T/8]
        
        # Bottleneck
        self.bottleneck = nn.Sequential(
            nn.Conv2d(base_filters*4, base_filters*4, kernel_size=3, padding=1),
            nn.BatchNorm2d(base_filters*4),
            nn.ReLU(inplace=True)
        )
        
        # Decoder (Reconstructs original spectrogram)
        self.dec3 = nn.Sequential(
            nn.ConvTranspose2d(base_filters*4, base_filters*2, kernel_size=2, stride=2),
            nn.BatchNorm2d(base_filters*2),
            nn.ReLU(inplace=True)
        )
        self.dec2 = nn.Sequential(
            nn.ConvTranspose2d(base_filters*2, base_filters, kernel_size=2, stride=2),
            nn.BatchNorm2d(base_filters),
            nn.ReLU(inplace=True)
        )
        self.dec1 = nn.Sequential(
            nn.ConvTranspose2d(base_filters, in_channels, kernel_size=2, stride=2),
            nn.Identity()
        )
        
    def forward(self, x, mask_prob: float = 0.30):
        # Apply random time-frequency masking during self-supervised training
        if self.training and mask_prob > 0:
            mask = (torch.rand_like(x) > mask_prob).float()
            x_masked = x * mask
        else:
            x_masked = x
            
        e1 = self.enc1(x_masked)
        e2 = self.enc2(e1)
        e3 = self.enc3(e2)
        
        b = self.bottleneck(e3)
        
        d3 = self.dec3(b)
        d2 = self.dec2(d3)
        recon = self.dec1(d2)
        
        # Match target shape if slight dimension mismatch due to odd pooling
        if recon.shape != x.shape:
            recon = F.interpolate(recon, size=x.shape[-2:], mode='bilinear', align_corners=False)
            
        return recon
