"""
SwasthAI Sound ML - Self-Supervised Pretraining Engine on Unlabelled Dataset 2
"""

import os
import glob
import json
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from tqdm import tqdm
from ..models.pretraining_autoencoder import MaskedSpectrogramAutoencoder
from ..data.dataset import UnlabelledAudioDataset

def train_unlabelled_autoencoder(
    unlabelled_dir: str = "dataset-lung sounds/unlabelled data",
    epochs: int = 10,
    batch_size: int = 16,
    lr: float = 0.001,
    output_checkpoint: str = "sound_ml/models/pretrained_autoencoder.pt"
):
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"=== SELF-SUPERVISED PRETRAINING (Device: {device}) ===")
    
    wav_files = sorted(glob.glob(os.path.join(unlabelled_dir, "*.wav")))
    print(f"Found {len(wav_files)} unlabelled audio files.")
    
    dataset = UnlabelledAudioDataset(wav_files, sample_rate=4000, target_duration_sec=5.0)
    loader = DataLoader(dataset, batch_size=batch_size, shuffle=True, drop_last=True)
    
    model = MaskedSpectrogramAutoencoder(in_channels=1, base_filters=16).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    criterion = nn.MSELoss()
    
    history = []
    
    for epoch in range(1, epochs + 1):
        model.train()
        total_loss = 0.0
        n_batches = 0
        
        for batch in loader:
            batch = batch.to(device)
            optimizer.zero_grad()
            recon = model(batch, mask_prob=0.30)
            loss = criterion(recon, batch)
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item()
            n_batches += 1
            
        avg_loss = total_loss / max(1, n_batches)
        history.append({'epoch': epoch, 'reconstruction_loss': avg_loss})
        print(f"Epoch [{epoch:02d}/{epochs:02d}] - Pretraining MAE Loss: {avg_loss:.5f}")
        
    os.makedirs(os.path.dirname(output_checkpoint), exist_ok=True)
    torch.save({
        'model_state_dict': model.state_dict(),
        'encoder_enc1': model.enc1.state_dict(),
        'encoder_enc2': model.enc2.state_dict(),
        'encoder_enc3': model.enc3.state_dict(),
        'history': history
    }, output_checkpoint)
    print(f"Saved pretrained representation model to: {output_checkpoint}")
    return model, history

if __name__ == '__main__':
    train_unlabelled_autoencoder(epochs=5)
