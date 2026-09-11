"""
SwasthAI Sound ML - Automated Hyperparameter Optimization with Optuna
"""

import os
import json
import optuna
import torch
from torch.utils.data import DataLoader
from ..models.cnn_model import RespiratoryCNN
from ..data.dataset import RespiratoryAudioDataset
from ..preprocessing.audio_transforms import AudioAugmentation
from ..training.train_final import compute_metrics

def run_optuna_tuning(
    splits_file: str = "sound_ml/data/splits/patient_splits.json",
    n_trials: int = 15,
    epochs_per_trial: int = 15,
    output_study_file: str = "sound_ml/outputs/experiments/optuna_study.json"
):
    optuna.logging.set_verbosity(optuna.logging.INFO)
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    
    with open(splits_file, 'r') as f:
        splits = json.load(f)
        
    train_recs = splits['train']
    val_recs = splits['val']
    
    train_labels = [r['label'] for r in train_recs]
    class_counts = torch.bincount(torch.tensor(train_labels), minlength=2)
    weights = (len(train_labels) / (2.0 * class_counts.float())).to(device)
    
    def objective(trial):
        # Sample hyperparameters
        base_filters = trial.suggest_categorical('base_filters', [16, 32])
        n_blocks = trial.suggest_int('n_blocks', 3, 4)
        dropout = trial.suggest_float('dropout', 0.20, 0.40, step=0.10)
        lr = trial.suggest_float('lr', 5e-4, 3e-3, log=True)
        weight_decay = trial.suggest_float('weight_decay', 1e-5, 1e-3, log=True)
        batch_size = trial.suggest_categorical('batch_size', [16, 32])
        
        # Build DataLoaders
        aug = AudioAugmentation()
        train_ds = RespiratoryAudioDataset(train_recs, is_train=True, augmentation=aug)
        val_ds = RespiratoryAudioDataset(val_recs, is_train=False)
        
        train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True)
        val_loader = DataLoader(val_ds, batch_size=batch_size, shuffle=False)
        
        model = RespiratoryCNN(
            in_channels=1,
            num_classes=2,
            base_filters=base_filters,
            n_blocks=n_blocks,
            dropout_rate=dropout
        ).to(device)
        
        criterion = torch.nn.CrossEntropyLoss(weight=weights)
        optimizer = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=weight_decay)
        
        best_val_f1 = 0.0
        for epoch in range(1, epochs_per_trial + 1):
            model.train()
            for batch in train_loader:
                x = batch['spectrogram'].to(device)
                y = batch['label'].to(device)
                optimizer.zero_grad()
                loss = criterion(model(x), y)
                loss.backward()
                optimizer.step()
                
            model.eval()
            val_preds, val_targets, val_probs = [], [], []
            with torch.no_grad():
                for batch in val_loader:
                    x = batch['spectrogram'].to(device)
                    y = batch['label'].to(device)
                    logits = model(x)
                    probs = torch.softmax(logits, dim=1)[:, 1].cpu().numpy()
                    preds = torch.argmax(logits, dim=1).cpu().numpy()
                    val_preds.extend(preds)
                    val_targets.extend(y.cpu().numpy())
                    val_probs.extend(probs)
                    
            m = compute_metrics(val_targets, val_preds, val_probs)
            val_f1 = m['f1']
            if val_f1 > best_val_f1:
                best_val_f1 = val_f1
                
            trial.report(val_f1, epoch)
            if trial.should_prune():
                raise optuna.exceptions.TrialPruned()
                
        return best_val_f1

    study = optuna.create_study(direction='maximize', pruner=optuna.pruners.MedianPruner(n_warmup_steps=5))
    study.optimize(objective, n_trials=n_trials)
    
    print("\n=== OPTUNA HYPERPARAMETER TUNING FINISHED ===")
    print(f"Best Trial Validation F1: {study.best_value:.4f}")
    print("Best Hyperparameters:")
    for k, v in study.best_params.items():
        print(f"  {k}: {v}")
        
    os.makedirs(os.path.dirname(output_study_file), exist_ok=True)
    with open(output_study_file, 'w') as f:
        json.dump({
            'best_value_f1': study.best_value,
            'best_params': study.best_params,
            'n_trials': len(study.trials)
        }, f, indent=2)
        
    return study.best_params

if __name__ == '__main__':
    run_optuna_tuning(n_trials=8, epochs_per_trial=10)
