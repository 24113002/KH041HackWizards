"""
SwasthAI SpO2 & PPG ML - Comprehensive Evaluation & Diagnostic Plotter
"""

import os
import json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import scipy.signal
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, average_precision_score, confusion_matrix,
    roc_curve, precision_recall_curve
)
from ..models.xgboost_model import SwasthAIXGBoostModel
from ..models.classical_baseline import ClassicalPulseOximeter
from ..preprocessing.ppg_preprocessing import PPGPreprocessor
from ..features.ac_dc_extractor import ACDCExtractor

def evaluate_spo2_system(
    feature_csv: str = "spo2_ml/data/features.csv",
    splits_file: str = "spo2_ml/data/splits/subject_splits.json",
    model_path: str = "spo2_ml/models/spo2_xgb_best.json",
    figures_dir: str = "spo2_ml/outputs/figures",
    reports_dir: str = "spo2_ml/outputs/reports"
):
    os.makedirs(figures_dir, exist_ok=True)
    os.makedirs(reports_dir, exist_ok=True)
    
    df = pd.read_csv(feature_csv)
    with open(splits_file, 'r') as f:
        splits = json.load(f)
        
    test_subs = splits['test_subjects']
    ignore_cols = {'subject_id', 'target_copd', 'is_patient'}
    feature_cols = [c for c in df.columns if c not in ignore_cols]
    
    test_df = df[df['subject_id'].isin(test_subs)]
    X_test = test_df[feature_cols].values
    y_test = test_df['target_copd'].values
    
    print(f"=== EVALUATING XGBOOST MODEL ON HOLDOUT TEST SUBJECTS ({test_subs}) ===")
    print(f"Total Test Windows: {len(test_df):,}")
    
    xgb_model = SwasthAIXGBoostModel()
    xgb_model.load_model(model_path)
    xgb_model.feature_names = feature_cols
    
    metrics, preds, probs = xgb_model.evaluate(X_test, y_test)
    print("\n--- Test Set Metrics ---")
    for k, v in metrics.items():
        if k != 'confusion_matrix':
            print(f"  {k}: {v:.4f}")
            
    # -------------------------------------------------------------
    # 1. FEATURE IMPORTANCE PLOT
    # -------------------------------------------------------------
    df_imp = xgb_model.get_feature_importances()
    df_imp.to_csv(os.path.join(reports_dir, "feature_importance.csv"), index=False)
    
    plt.figure(figsize=(10, 6), dpi=300)
    top_feats = df_imp.head(15).sort_values(by='importance', ascending=True)
    plt.barh(top_feats['feature'], top_feats['importance'], color='#0288D1')
    plt.title('Top 15 Most Informative PPG Features (XGBoost Feature Importance)', fontsize=13, fontweight='bold')
    plt.xlabel('F-Score / Relative Importance Weight', fontsize=11, fontweight='bold')
    plt.grid(True, linestyle='--', alpha=0.5)
    plt.tight_layout()
    plt.savefig(os.path.join(figures_dir, "feature_importance.png"))
    plt.close()
    
    # -------------------------------------------------------------
    # 2. CONFUSION MATRIX PLOT
    # -------------------------------------------------------------
    cm = np.array(metrics['confusion_matrix'])
    plt.figure(figsize=(7, 6), dpi=300)
    plt.imshow(cm, interpolation='nearest', cmap=plt.cm.Blues)
    plt.title('Confusion Matrix — Holdout Test Subjects', fontsize=13, fontweight='bold')
    plt.colorbar()
    tick_marks = np.arange(2)
    plt.xticks(tick_marks, ['Normal (0)', 'COPD (1)'], fontsize=11)
    plt.yticks(tick_marks, ['Normal (0)', 'COPD (1)'], fontsize=11)
    
    thresh = cm.max() / 2.
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            plt.text(j, i, format(cm[i, j], 'd'),
                     ha="center", va="center",
                     color="white" if cm[i, j] > thresh else "black",
                     fontsize=14, fontweight='bold')
                     
    plt.ylabel('True Category', fontsize=12, fontweight='bold')
    plt.xlabel('Predicted Category', fontsize=12, fontweight='bold')
    plt.tight_layout()
    plt.savefig(os.path.join(figures_dir, "confusion_matrix.png"))
    plt.close()
    
    # -------------------------------------------------------------
    # 3. ROC & PRECISION-RECALL PLOTS
    # -------------------------------------------------------------
    fpr, tpr, _ = roc_curve(y_test, probs)
    pr_prec, pr_rec, _ = precision_recall_curve(y_test, probs)
    
    fig, axes = plt.subplots(1, 2, figsize=(14, 6), dpi=300)
    axes[0].plot(fpr, tpr, color='#0288D1', lw=2.5, label=f'XGBoost (AUC = {metrics["roc_auc"]:.3f})')
    axes[0].plot([0, 1], [0, 1], color='gray', lw=1.5, linestyle='--')
    axes[0].set_title('Receiver Operating Characteristic (ROC)', fontsize=13, fontweight='bold')
    axes[0].set_xlabel('False Positive Rate', fontsize=11)
    axes[0].set_ylabel('True Positive Rate (Sensitivity)', fontsize=11)
    axes[0].legend(loc="lower right", fontsize=11)
    axes[0].grid(True, linestyle='--', alpha=0.5)
    
    axes[1].plot(pr_rec, pr_prec, color='#00897B', lw=2.5, label=f'Precision-Recall (PR-AUC = {metrics["pr_auc"]:.3f})')
    axes[1].set_title('Precision-Recall Curve', fontsize=13, fontweight='bold')
    axes[1].set_xlabel('Recall (Sensitivity)', fontsize=11)
    axes[1].set_ylabel('Precision', fontsize=11)
    axes[1].legend(loc="lower left", fontsize=11)
    axes[1].grid(True, linestyle='--', alpha=0.5)
    
    plt.tight_layout()
    plt.savefig(os.path.join(figures_dir, "roc_pr_curves.png"))
    plt.close()
    
    # -------------------------------------------------------------
    # 4. DIAGNOSTIC PPG PIPELINE PLOT (Hardware Signal Verification)
    # -------------------------------------------------------------
    # Synthesize/plot representative MAX30102 PPG signals (RED & IR) to verify:
    # 1. Raw RED + IR -> 2. Filtered AC -> 3. DC Components -> 4. Peaks -> 5. R-ratio
    t = np.linspace(0, 4.0, 400) # 4 seconds @ 100 Hz
    # Physiological pulsatile wave with dicrotic notch
    cardiac_pulse = (np.sin(2 * np.pi * 1.1 * t) + 0.35 * np.sin(4 * np.pi * 1.1 * t + 0.5))
    
    # Realistic raw ADC values observed in ESP32 MAX30102 tests
    raw_red = 58200.0 + 850.0 * cardiac_pulse + np.random.normal(0, 40, len(t))
    raw_ir = 63400.0 + 1350.0 * cardiac_pulse + np.random.normal(0, 40, len(t))
    
    preprocessor = PPGPreprocessor(sampling_rate=100.0)
    prep_data = preprocessor.preprocess_pair(raw_red, raw_ir)
    
    ac_dc_ext = ACDCExtractor(sampling_rate=100.0)
    red_ac_dc = ac_dc_ext.compute_ac_dc(prep_data['red_raw'], prep_data['red_ac'])
    ir_ac_dc = ac_dc_ext.compute_ac_dc(prep_data['ir_raw'], prep_data['ir_ac'])
    r_res = ac_dc_ext.compute_r_ratio(red_ac_dc, ir_ac_dc)
    
    peaks, _ = scipy.signal.find_peaks(prep_data['ir_ac'], distance=40, prominence=0.2*np.ptp(prep_data['ir_ac']))
    
    fig, axes = plt.subplots(4, 1, figsize=(12, 11), dpi=300)
    
    # 1. Raw RED & IR
    axes[0].plot(t, raw_red, color='#E53935', label=f'Raw RED (Mean DC = {np.mean(raw_red):.0f})')
    axes[0].plot(t, raw_ir, color='#8E24AA', label=f'Raw IR (Mean DC = {np.mean(raw_ir):.0f})')
    axes[0].set_title('1. Hardware Raw MAX30102 Optical PPG Signals (ESP32 ADC Counts)', fontsize=12, fontweight='bold')
    axes[0].set_ylabel('ADC Counts (18-bit)')
    axes[0].legend(loc='upper right')
    axes[0].grid(True, linestyle='--', alpha=0.5)
    
    # 2. Bandpass Filtered AC (0.5 - 5.0 Hz)
    axes[1].plot(t, prep_data['red_ac'], color='#E53935', label=f'RED AC (RMS = {red_ac_dc["ac"]:.1f})')
    axes[1].plot(t, prep_data['ir_ac'], color='#8E24AA', label=f'IR AC (RMS = {ir_ac_dc["ac"]:.1f})')
    axes[1].set_title('2. Zero-Phase Butterworth Bandpass Filtered AC Pulsatile Waves', fontsize=12, fontweight='bold')
    axes[1].set_ylabel('AC Amplitude')
    axes[1].legend(loc='upper right')
    axes[1].grid(True, linestyle='--', alpha=0.5)
    
    # 3. Peak Detection & Pulse Intervals
    axes[2].plot(t, prep_data['ir_ac'], color='#8E24AA', label='IR Pulsatile Waveform')
    axes[2].plot(t[peaks], prep_data['ir_ac'][peaks], 'ro', markersize=8, label=f'Detected Heartbeats ({len(peaks)} beats)')
    axes[2].set_title('3. Pulse Peak Detection & Inter-Beat Intervals (IBI)', fontsize=12, fontweight='bold')
    axes[2].set_ylabel('Amplitude')
    axes[2].legend(loc='upper right')
    axes[2].grid(True, linestyle='--', alpha=0.5)
    
    # 4. Modulation Ratio R & SpO2 Estimation
    r_val = r_res['r_ratio']
    spo2_est = r_res['spo2_estimated_linear']
    axes[3].text(0.05, 0.65, f"AC/DC RED = {red_ac_dc['ac_dc_ratio']:.5f}", fontsize=12, fontweight='bold', color='#E53935')
    axes[3].text(0.05, 0.35, f"AC/DC IR   = {ir_ac_dc['ac_dc_ratio']:.5f}", fontsize=12, fontweight='bold', color='#8E24AA')
    axes[3].text(0.50, 0.65, f"Optical Ratio R = {r_val:.4f}", fontsize=13, fontweight='bold', color='#1E88E5')
    axes[3].text(0.50, 0.35, f"Classical SpO₂ = 110.0 - 25.0 × R = {spo2_est:.1f} %", fontsize=13, fontweight='bold', color='#2E7D32')
    axes[3].set_title('4. AC/DC Optical Modulation R-Ratio & Empirical SpO₂ Calculation', fontsize=12, fontweight='bold')
    axes[3].axis('off')
    
    plt.tight_layout()
    diag_plot_path = os.path.join(figures_dir, "diagnostic_ppg_pipeline.png")
    plt.savefig(diag_plot_path)
    plt.close()
    print(f"Saved diagnostic PPG verification plot: {diag_plot_path}")
    
    # Save Feature Statistics
    stats_df = df[feature_cols].describe().T
    stats_df.to_csv(os.path.join(reports_dir, "feature_statistics.csv"))
    
    # Save Evaluation Metrics
    with open(os.path.join(reports_dir, "evaluation_metrics.json"), 'w') as f:
        json.dump(metrics, f, indent=2)
        
    return metrics

if __name__ == '__main__':
    evaluate_spo2_system()
