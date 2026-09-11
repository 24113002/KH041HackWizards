"""
SwasthAI Sound ML - Lightweight PyTorch CNN Architecture for Respiratory Audio
"""

import torch
import torch.nn as nn
import torch.nn.functional as F

class ConvBlock(nn.Module):
    def __init__(self, in_channels: int, out_channels: int, kernel_size: int = 3, stride: int = 1, pool: bool = True):
        super().__init__()
        self.conv = nn.Conv2d(in_channels, out_channels, kernel_size=kernel_size, stride=stride, padding=kernel_size//2, bias=False)
        self.bn = nn.BatchNorm2d(out_channels)
        self.relu = nn.ReLU(inplace=True)
        self.pool = nn.MaxPool2d(kernel_size=2, stride=2) if pool else nn.Identity()
        
    def forward(self, x):
        return self.pool(self.relu(self.bn(self.conv(x))))

class RespiratoryCNN(nn.Module):
    """
    Lightweight, mobile-deployable 2D CNN for Log-Mel Spectrogram classification.
    """
    def __init__(
        self,
        in_channels: int = 1,
        num_classes: int = 2,
        base_filters: int = 16,
        n_blocks: int = 4,
        dropout_rate: float = 0.30
    ):
        super().__init__()
        self.in_channels = in_channels
        self.num_classes = num_classes
        self.base_filters = base_filters
        
        # Feature Extraction Backbone
        blocks = []
        c_in = in_channels
        c_out = base_filters
        
        for i in range(n_blocks):
            pool = True
            blocks.append(ConvBlock(c_in, c_out, kernel_size=3, pool=pool))
            c_in = c_out
            if i < n_blocks - 1:
                c_out = min(128, c_out * 2)
                
        self.encoder = nn.Sequential(*blocks)
        self.global_pool = nn.AdaptiveAvgPool2d((1, 1))
        
        # Classifier Head
        self.classifier = nn.Sequential(
            nn.Dropout(p=dropout_rate),
            nn.Linear(c_in, 32),
            nn.ReLU(inplace=True),
            nn.Dropout(p=dropout_rate / 2.0),
            nn.Linear(32, num_classes)
        )
        
        # Saliency map gradient tracking for explainability (Grad-CAM)
        self.gradients = None
        self.activations = None
        
    def activations_hook(self, grad):
        self.gradients = grad
        
    def forward(self, x):
        # Extract features
        for name, module in self.encoder.named_children():
            x = module(x)
            
        # Hook last conv layer for Grad-CAM
        if x.requires_grad:
            h = x.register_hook(self.activations_hook)
            self.activations = x
            
        pooled = self.global_pool(x)
        flattened = torch.flatten(pooled, 1)
        logits = self.classifier(flattened)
        return logits
        
    def get_num_parameters(self) -> int:
        return sum(p.numel() for p in self.parameters() if p.requires_grad)
