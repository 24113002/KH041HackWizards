"""
SwasthAI Sound ML - Full PyTorch Training & Checkpointing Engine
"""

import os
import json
import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
from ..models.cnn_model import RespiratoryCNN
from ..data.dataset import RespiratoryAudioDataset
from ..preprocessing.audio_transforms import AudioAugmentation

def compute_metrics(y_true, y_pred, y_prob=None):
    acc = accuracy_score(y_true, y_pred)
    prec = precision_score(y_true, y_pred, zero_division=0)
    rec = recall_score(y_true, y_pred, zero_division=0)
    f1 = f1_score(y_true, y_pred, zero_division=0)
    roc_auc = roc_auc_score(y_true, y_prob) if (y_prob is not None and len(np.unique(y_true)) > 1) else 0.5
    return {
        'accuracy': float(acc),
        'precision': float(prec),
        'recall': float(rec),
        'f1': float(f1),
        'roc_auc': float(roc_auc)
    }

def train_model(
    splits_file: str = "sound_ml/data/splits/patient_splits.json",
    pretrained_weights_path: str = None,
    epochs: int = 40,
    batch_size: int = 16,
    lr: float = 0.001,
    weight_decay: float = 1e-4,
    base_filters: int = 16,
    n_blocks: int = 4,
    dropout: float = 0.30,
    output_dir: str = "sound_ml/models",
    history_output_file: str = "sound_ml/outputs/experiments/training_history.json"
):
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Device: {device.type.lower()}")
    
    # Load Splits
    with open(splits_file, 'r') as f:
        splits = json.load(f)
        
    train_recs = splits['train']
    val_recs = splits['val']
    test_recs = splits['test']
    
    # Calculate class weights for loss balancing
    train_labels = [r['label'] for r in train_recs]
    class_counts = np.bincount(train_labels, minlength=2)
    total_samples = len(train_labels)
    class_weights = total_samples / (2.0 * np.maximum(class_counts, 1))
    weights_tensor = torch.tensor(class_weights, dtype=torch.float).to(device)
    print(f"Class distribution: {dict(enumerate(class_counts))}, Loss weights: {class_weights}")
    
    # Build Datasets
    aug = AudioAugmentation()
    train_ds = RespiratoryAudioDataset(train_recs, is_train=True, augmentation=aug)
    val_ds = RespiratoryAudioDataset(val_recs, is_train=False)
    test_ds = RespiratoryAudioDataset(test_recs, is_train=False)
    
    train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True, drop_last=False)
    val_loader = DataLoader(val_ds, batch_size=batch_size, shuffle=False)
    test_loader = DataLoader(test_ds, batch_size=batch_size, shuffle=False)
    
    # Build Model
    model = RespiratoryCNN(
        in_channels=1,
        num_classes=2,
        base_filters=base_filters,
        n_blocks=n_blocks,
        dropout_rate=dropout
    ).to(device)
    
    # Transfer Pretrained Weights if available
    if pretrained_weights_path and os.path.exists(pretrained_weights_path):
        print(f"Loading self-supervised pretrained encoder from {pretrained_weights_path}...")
        ckpt = torch.load(pretrained_weights_path, map_location=device, weights_only=False)
        if 'encoder_enc1' in ckpt and len(model.encoder) >= 1:
            try:
                model.encoder[0].load_state_dict(ckpt['encoder_enc1'], strict=False)
                if len(model.encoder) >= 2 and 'encoder_enc2' in ckpt:
                    model.encoder[1].load_state_dict(ckpt['encoder_enc2'], strict=False)
                if len(model.encoder) >= 3 and 'encoder_enc3' in ckpt:
                    model.encoder[2].load_state_dict(ckpt['encoder_enc3'], strict=False)
                print("Pretrained weights successfully transferred to CNN encoder!")
            except Exception as e:
                print(f"Partial weight transfer warning: {e}")
                
    criterion = nn.CrossEntropyLoss(weight=weights_tensor)
    optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=weight_decay)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs, eta_min=1e-6)
    
    best_val_f1 = -1.0
    best_epoch = 0
    history = {
        'epochs': [],
        'train_loss': [],
        'val_loss': [],
        'train_f1': [],
        'val_f1': [],
        'train_acc': [],
        'val_acc': []
    }
    
    best_model_path = os.path.join(output_dir, "sound_model_best.pt")
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(os.path.dirname(history_output_file), exist_ok=True)
    
    print("\n--- Starting PyTorch Training Loop ---")
    for epoch in range(1, epochs + 1):
        # 1. Training Phase
        model.train()
        train_loss_sum = 0.0
        train_preds, train_targets, train_probs = [], [], []
        
        for batch in train_loader:
            x = batch['spectrogram'].to(device)
            y = batch['label'].to(device)
            
            optimizer.zero_grad()
            logits = model(x)
            loss = criterion(logits, y)
            loss.backward()
            optimizer.step()
            
            train_loss_sum += loss.item() * len(y)
            probs = torch.softmax(logits, dim=1)[:, 1].detach().cpu().numpy()
            preds = torch.argmax(logits, dim=1).detach().cpu().numpy()
            
            train_preds.extend(preds)
            train_targets.extend(y.cpu().numpy())
            train_probs.extend(probs)
            
        scheduler.step()
        
        train_loss = train_loss_sum / len(train_recs)
        train_m = compute_metrics(train_targets, train_preds, train_probs)
        
        # 2. Validation Phase
        model.eval()
        val_loss_sum = 0.0
        val_preds, val_targets, val_probs = [], [], []
        
        with torch.no_grad():
            for batch in val_loader:
                x = batch['spectrogram'].to(device)
                y = batch['label'].to(device)
                logits = model(x)
                loss = criterion(logits, y)
                
                val_loss_sum += loss.item() * len(y)
                probs = torch.softmax(logits, dim=1)[:, 1].cpu().numpy()
                preds = torch.argmax(logits, dim=1).cpu().numpy()
                
                val_preds.extend(preds)
                val_targets.extend(y.cpu().numpy())
                val_probs.extend(probs)
                
        val_loss = val_loss_sum / len(val_recs)
        val_m = compute_metrics(val_targets, val_preds, val_probs)
        
        history['epochs'].append(epoch)
        history['train_loss'].append(float(train_loss))
        history['val_loss'].append(float(val_loss))
        history['train_f1'].append(float(train_m['f1']))
        history['val_f1'].append(float(val_m['f1']))
        history['train_acc'].append(float(train_m['accuracy']))
        history['val_acc'].append(float(val_m['accuracy']))
        
        print(f"Epoch [{epoch:02d}/{epochs:02d}] "
              f"Train Loss: {train_loss:.4f} | Val Loss: {val_loss:.4f} | "
              f"Train F1: {train_m['f1']:.3f} | Val F1: {val_m['f1']:.3f} | Val Acc: {val_m['accuracy']:.3f}")
              
        # Checkpointing best model by Validation F1
        if val_m['f1'] > best_val_f1:
            best_val_f1 = val_m['f1']
            best_epoch = epoch
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'val_metrics': val_m,
                'hyperparameters': {
                    'base_filters': base_filters,
                    'n_blocks': n_blocks,
                    'dropout': dropout,
                    'lr': lr,
                    'weight_decay': weight_decay
                }
            }, best_model_path)
            
    print(f"\nBest Validation F1: {best_val_f1:.4f} achieved at Epoch {best_epoch}")
    print(f"Best model checkpoint saved to: {best_model_path}")
    
    # Save training history JSON
    with open(history_output_file, 'w') as f:
        json.dump(history, f, indent=2)
        
    # Save configs and metadata
    labels_config = {
        '0': 'Normal',
        '1': 'Pathological_Respiratory_Sound'
    }
    with open(os.path.join(output_dir, "labels.json"), 'w') as f:
        json.dump(labels_config, f, indent=2)
        
    prep_config = {
        'sample_rate': 4000,
        'target_duration_sec': 5.0,
        'n_fft': 512,
        'hop_length': 128,
        'n_mels': 64,
        'f_min': 50,
        'f_max': 2000
    }
    with open(os.path.join(output_dir, "preprocessing.json"), 'w') as f:
        json.dump(prep_config, f, indent=2)
        
    return model, history, best_val_f1
