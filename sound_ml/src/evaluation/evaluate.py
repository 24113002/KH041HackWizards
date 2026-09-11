"""
SwasthAI Sound ML - Comprehensive Evaluation Suite & Loss Curve Visualizer
"""

import os
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import torch
from torch.utils.data import DataLoader
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    balanced_accuracy_score, roc_auc_score, average_precision_score,
    confusion_matrix, roc_curve, precision_recall_curve
)
from ..models.cnn_model import RespiratoryCNN
from ..data.dataset import RespiratoryAudioDataset
from ..models.baseline import ClassicalMLBaseline

def evaluate_all(
    splits_file: str = "sound_ml/data/splits/patient_splits.json",
    model_checkpoint: str = "sound_ml/models/sound_model_best.pt",
    history_file: str = "sound_ml/outputs/experiments/training_history.json",
    figures_dir: str = "sound_ml/outputs/figures",
    reports_dir: str = "sound_ml/outputs/reports"
):
    os.makedirs(figures_dir, exist_ok=True)
    os.makedirs(reports_dir, exist_ok=True)
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    
    with open(splits_file, 'r') as f:
        splits = json.load(f)
        
    train_recs = splits['train']
    val_recs = splits['val']
    test_recs = splits['test']
    
    # -------------------------------------------------------------
    # 1. EVALUATE CLASSICAL BASELINE
    # -------------------------------------------------------------
    print("=== EVALUATING CLASSICAL BASELINE (Random Forest & SVM) ===")
    rf_baseline = ClassicalMLBaseline(model_type='rf')
    X_train, y_train = rf_baseline.extract_dataset_features(train_recs)
    X_test, y_test = rf_baseline.extract_dataset_features(test_recs)
    
    rf_baseline.train(X_train, y_train)
    rf_metrics, rf_preds, rf_probs = rf_baseline.evaluate(X_test, y_test)
    print(f"Random Forest Test F1: {rf_metrics['f1']:.4f}, Accuracy: {rf_metrics['accuracy']:.4f}")
    
    # -------------------------------------------------------------
    # 2. EVALUATE DEEP LEARNING MODEL (PyTorch CNN)
    # -------------------------------------------------------------
    print("\n=== EVALUATING PYTORCH RESPIRATORY CNN ===")
    val_ds = RespiratoryAudioDataset(val_recs, is_train=False)
    val_loader = DataLoader(val_ds, batch_size=16, shuffle=False)
    test_ds = RespiratoryAudioDataset(test_recs, is_train=False)
    test_loader = DataLoader(test_ds, batch_size=16, shuffle=False)
    
    ckpt = torch.load(model_checkpoint, map_location=device, weights_only=False)
    hp = ckpt.get('hyperparameters', {})
    
    model = RespiratoryCNN(
        in_channels=1,
        num_classes=2,
        base_filters=hp.get('base_filters', 16),
        n_blocks=hp.get('n_blocks', 4),
        dropout_rate=hp.get('dropout', 0.30)
    ).to(device)
    model.load_state_dict(ckpt['model_state_dict'])
    model.eval()
    
    # Validation probabilities for threshold optimization
    val_targets, val_probs = [], []
    with torch.no_grad():
        for batch in val_loader:
            x = batch['spectrogram'].to(device)
            y = batch['label'].to(device)
            logits = model(x)
            probs = torch.softmax(logits, dim=1)[:, 1].cpu().numpy()
            val_targets.extend(y.cpu().numpy())
            val_probs.extend(probs)
            
    val_targets = np.array(val_targets)
    val_probs = np.array(val_probs)
    
    # Search optimal threshold on Validation Set ONLY (maximize balanced accuracy / F1)
    best_threshold = 0.5
    best_val_score = -1.0
    for th in np.linspace(0.2, 0.85, 66):
        th_preds = (val_probs >= th).astype(int)
        score = balanced_accuracy_score(val_targets, th_preds) + f1_score(val_targets, th_preds, zero_division=0)
        if score > best_val_score:
            best_val_score = score
            best_threshold = float(th)
            
    print(f"Optimal Decision Threshold locked on Validation Set: {best_threshold:.4f} (Default: 0.5000)")
    
    test_targets, test_probs = [], []
    with torch.no_grad():
        for batch in test_loader:
            x = batch['spectrogram'].to(device)
            y = batch['label'].to(device)
            logits = model(x)
            probs = torch.softmax(logits, dim=1)[:, 1].cpu().numpy()
            test_targets.extend(y.cpu().numpy())
            test_probs.extend(probs)
            
    test_targets = np.array(test_targets)
    test_probs = np.array(test_probs)
    test_preds = (test_probs >= best_threshold).astype(int)
    
    # Calculate detailed clinical & ML metrics
    acc = accuracy_score(test_targets, test_preds)
    prec = precision_score(test_targets, test_preds, zero_division=0)
    rec = recall_score(test_targets, test_preds, zero_division=0) # Sensitivity
    f1 = f1_score(test_targets, test_preds, zero_division=0)
    bal_acc = balanced_accuracy_score(test_targets, test_preds)
    
    # Specificity = TN / (TN + FP)
    cm = confusion_matrix(test_targets, test_preds)
    tn, fp, fn, tp = cm.ravel() if cm.size == 4 else (0, 0, 0, 0)
    spec = tn / (tn + fp) if (tn + fp) > 0 else 0.0
    
    roc_auc = roc_auc_score(test_targets, test_probs) if len(np.unique(test_targets)) > 1 else 0.5
    pr_auc = average_precision_score(test_targets, test_probs) if len(np.unique(test_targets)) > 1 else 0.5
    
    cnn_metrics = {
        'accuracy': float(acc),
        'precision': float(prec),
        'recall_sensitivity': float(rec),
        'specificity': float(spec),
        'f1': float(f1),
        'balanced_accuracy': float(bal_acc),
        'roc_auc': float(roc_auc),
        'pr_auc': float(pr_auc),
        'true_positives': int(tp),
        'true_negatives': int(tn),
        'false_positives': int(fp),
        'false_negatives': int(fn),
        'total_test_samples': len(test_targets),
        'num_parameters': model.get_num_parameters()
    }
    
    print("\n--- Test Set Performance Metrics ---")
    for k, v in cnn_metrics.items():
        print(f"  {k}: {v}")
        
    # -------------------------------------------------------------
    # 3. GENERATE REQUESTED PLOTS
    # -------------------------------------------------------------
    
    # PLOT 1: LOSS PROGRESSION CURVE (Epochs vs Training & Validation Error / Loss)
    if os.path.exists(history_file):
        with open(history_file, 'r') as f:
            hist = json.load(f)
            
        epochs = hist['epochs']
        train_loss = hist['train_loss']
        val_loss = hist['val_loss']
        
        plt.figure(figsize=(10, 6), dpi=300)
        plt.plot(epochs, train_loss, 'o-', color='#1E88E5', linewidth=2.5, markersize=5, label='Training Loss (Cross-Entropy Error)')
        plt.plot(epochs, val_loss, 's-', color='#E53935', linewidth=2.5, markersize=5, label='Validation Loss (Generalization Error)')
        
        # Best validation loss point
        min_val_idx = np.argmin(val_loss)
        plt.scatter([epochs[min_val_idx]], [val_loss[min_val_idx]], color='#D81B60', s=120, zorder=5, label=f'Min Val Loss ({val_loss[min_val_idx]:.4f})')
        
        plt.title('SwasthAI Sound Model — Prediction Error (Loss) vs Training Progression', fontsize=14, fontweight='bold', pad=15)
        plt.xlabel('Training Time (Epochs)', fontsize=12, fontweight='bold')
        plt.ylabel('Prediction Error / Loss (Cross-Entropy)', fontsize=12, fontweight='bold')
        plt.grid(True, linestyle='--', alpha=0.5)
        plt.legend(fontsize=11, loc='upper right', framealpha=0.95)
        plt.tight_layout()
        
        loss_plot_path = os.path.join(figures_dir, "loss_progression_curve.png")
        plt.savefig(loss_plot_path)
        plt.close()
        print(f"\n[SAVED GRAPH] Loss Progression Curve: {loss_plot_path}")
        
        # Also plot Metrics curve (F1 and Accuracy over epochs)
        plt.figure(figsize=(10, 6), dpi=300)
        plt.plot(epochs, hist['train_f1'], 'o-', color='#00897B', label='Train F1-Score')
        plt.plot(epochs, hist['val_f1'], 's-', color='#FB8C00', label='Validation F1-Score')
        plt.plot(epochs, hist['val_acc'], '^--', color='#5E35B1', label='Validation Accuracy')
        plt.title('Training & Validation F1-Score / Accuracy Progression', fontsize=14, fontweight='bold', pad=15)
        plt.xlabel('Epochs', fontsize=12, fontweight='bold')
        plt.ylabel('Score (0.0 - 1.0)', fontsize=12, fontweight='bold')
        plt.grid(True, linestyle='--', alpha=0.5)
        plt.legend(fontsize=11, loc='lower right')
        plt.tight_layout()
        metrics_plot_path = os.path.join(figures_dir, "metric_progression_curve.png")
        plt.savefig(metrics_plot_path)
        plt.close()
        
    # PLOT 2: CONFUSION MATRIX
    plt.figure(figsize=(7, 6), dpi=300)
    plt.imshow(cm, interpolation='nearest', cmap=plt.cm.Blues)
    plt.title('Confusion Matrix — Test Set (Holdout Subjects)', fontsize=13, fontweight='bold')
    plt.colorbar()
    tick_marks = np.arange(2)
    plt.xticks(tick_marks, ['Normal (0)', 'Pathological (1)'], fontsize=11)
    plt.yticks(tick_marks, ['Normal (0)', 'Pathological (1)'], fontsize=11)
    
    thresh = cm.max() / 2.
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            plt.text(j, i, format(cm[i, j], 'd'),
                     ha="center", va="center",
                     color="white" if cm[i, j] > thresh else "black",
                     fontsize=14, fontweight='bold')
                     
    plt.ylabel('True Clinical Category', fontsize=12, fontweight='bold')
    plt.xlabel('Model Predicted Category', fontsize=12, fontweight='bold')
    plt.tight_layout()
    cm_plot_path = os.path.join(figures_dir, "confusion_matrix.png")
    plt.savefig(cm_plot_path)
    plt.close()
    
    # PLOT 3: ROC & PR CURVES
    fpr, tpr, _ = roc_curve(test_targets, test_probs)
    pr_prec, pr_rec, _ = precision_recall_curve(test_targets, test_probs)
    
    fig, axes = plt.subplots(1, 2, figsize=(14, 6), dpi=300)
    
    # ROC
    axes[0].plot(fpr, tpr, color='#1E88E5', lw=2.5, label=f'PyTorch CNN (AUC = {roc_auc:.3f})')
    axes[0].plot([0, 1], [0, 1], color='gray', lw=1.5, linestyle='--')
    axes[0].set_title('Receiver Operating Characteristic (ROC)', fontsize=13, fontweight='bold')
    axes[0].set_xlabel('False Positive Rate (1 - Specificity)', fontsize=11)
    axes[0].set_ylabel('True Positive Rate (Sensitivity / Recall)', fontsize=11)
    axes[0].legend(loc="lower right", fontsize=11)
    axes[0].grid(True, linestyle='--', alpha=0.5)
    
    # PR
    axes[1].plot(pr_rec, pr_prec, color='#00897B', lw=2.5, label=f'Precision-Recall (PR-AUC = {pr_auc:.3f})')
    axes[1].set_title('Precision-Recall Curve', fontsize=13, fontweight='bold')
    axes[1].set_xlabel('Recall (Sensitivity)', fontsize=11)
    axes[1].set_ylabel('Precision (Positive Predictive Value)', fontsize=11)
    axes[1].legend(loc="lower left", fontsize=11)
    axes[1].grid(True, linestyle='--', alpha=0.5)
    
    plt.tight_layout()
    roc_pr_plot_path = os.path.join(figures_dir, "roc_pr_curves.png")
    plt.savefig(roc_pr_plot_path)
    plt.close()
    
    # -------------------------------------------------------------
    # 4. SAVE REPORTS & COMPARISONS
    # -------------------------------------------------------------
    comparison_table = [
        {
            'Model': 'Classical ML (Random Forest)',
            'Features': 'Spectral Centroid, Flatness, Energy, ZCR',
            'Parameters': '~15k',
            'Test_Accuracy': rf_metrics['accuracy'],
            'Test_Precision': rf_metrics['precision'],
            'Test_Recall': rf_metrics['recall'],
            'Test_F1': rf_metrics['f1'],
            'ROC_AUC': rf_metrics['roc_auc']
        },
        {
            'Model': 'PyTorch Respiratory CNN',
            'Features': 'Log-Mel Spectrogram (64 mels, 4kHz)',
            'Parameters': f"{cnn_metrics['num_parameters']:,}",
            'Test_Accuracy': cnn_metrics['accuracy'],
            'Test_Precision': cnn_metrics['precision'],
            'Test_Recall': cnn_metrics['recall_sensitivity'],
            'Test_F1': cnn_metrics['f1'],
            'ROC_AUC': cnn_metrics['roc_auc']
        }
    ]
    with open(os.path.join(reports_dir, "model_comparison.json"), 'w') as f:
        json.dump(comparison_table, f, indent=2)
        
    with open(os.path.join(reports_dir, "evaluation_metrics.json"), 'w') as f:
        json.dump(cnn_metrics, f, indent=2)
        
    # Error Analysis
    error_cases = []
    for i, rec in enumerate(test_recs):
        true_lbl = test_targets[i]
        pred_lbl = test_preds[i]
        prob = float(test_probs[i])
        if true_lbl != pred_lbl:
            error_cases.append({
                'patient_id': rec['patient_id'],
                'file_name': rec['file_name'],
                'diagnosis': rec['diagnosis'],
                'sound_type': rec['sound_type'],
                'true_label': int(true_lbl),
                'predicted_label': int(pred_lbl),
                'predicted_abnormal_prob': prob,
                'error_type': 'False Positive' if (true_lbl == 0 and pred_lbl == 1) else 'False Negative'
            })
            
    with open(os.path.join(reports_dir, "error_analysis.json"), 'w') as f:
        json.dump(error_cases, f, indent=2)
        
    print(f"Total Test Error Cases: {len(error_cases)} / {len(test_targets)}")
    return cnn_metrics, comparison_table

if __name__ == '__main__':
    evaluate_all()
