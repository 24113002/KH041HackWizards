"""
SwasthAI Fusion ML - Evaluation & Diagnostic Plotting Module
Generates Confusion Matrix, Feature Importance, and Ablation Study Comparison Figures.
"""

import os
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix, classification_report, accuracy_score, f1_score
from ..models.fusion_model import SwasthAIFusionModel

def evaluate_fusion(
    model_path: str = "fusion_ml/models/fusion_xgboost_model.json",
    dataset_csv: str = "fusion_ml/data/multimodal_fusion_dataset.csv",
    config_path: str = "fusion_ml/models/fusion_feature_columns.json",
    output_dir: str = "fusion_ml/outputs"
):
    df = pd.read_csv(dataset_csv)
    with open(config_path, "r") as f:
        cfg = json.load(f)
    feature_cols = cfg['feature_names']

    test_subjects = list(range(41, 51))
    df_test = df[df['subject_id'].isin(test_subjects)].copy()

    X_test = df_test[feature_cols].values
    y_test = df_test['risk_category'].values

    model = SwasthAIFusionModel()
    model.load_model(model_path)
    model.feature_names = feature_cols

    preds = model.predict(X_test)
    probs = model.predict_proba(X_test)

    acc = float(accuracy_score(y_test, preds))
    macro_f1 = float(f1_score(y_test, preds, average='macro'))
    cm = confusion_matrix(y_test, preds).tolist()

    report = classification_report(y_test, preds, target_names=['Lower Risk', 'Moderate Risk', 'Higher Risk'], output_dict=True)

    metrics = {
        'accuracy': round(acc, 4),
        'macro_f1': round(macro_f1, 4),
        'test_subjects_count': len(test_subjects),
        'test_samples_count': len(y_test),
        'confusion_matrix': cm,
        'classification_report': report
    }

    os.makedirs(os.path.join(output_dir, "reports"), exist_ok=True)
    with open(os.path.join(output_dir, "reports", "evaluation_metrics.json"), "w") as f:
        json.dump(metrics, f, indent=2)

    # 1. Confusion Matrix Figure
    fig_dir = os.path.join(output_dir, "figures")
    brain_dir = r"C:\Users\gaura\.gemini\antigravity-ide\brain\6e858849-0199-4f34-8c8b-7304b1b07771"
    os.makedirs(fig_dir, exist_ok=True)

    plt.style.use('default')
    fig, ax = plt.subplots(figsize=(7, 6), dpi=200)
    fig.patch.set_facecolor('#ffffff')

    cm_arr = np.array(cm)
    im = ax.imshow(cm_arr, interpolation='nearest', cmap='Blues')
    plt.colorbar(im, ax=ax)
    classes = ['Lower Risk', 'Moderate Risk', 'Higher Risk']
    tick_marks = np.arange(len(classes))
    ax.set_xticks(tick_marks)
    ax.set_xticklabels(classes, fontsize=10)
    ax.set_yticks(tick_marks)
    ax.set_yticklabels(classes, fontsize=10)

    for i in range(len(classes)):
        for j in range(len(classes)):
            color = 'white' if cm_arr[i, j] > cm_arr.max() / 2 else 'black'
            ax.text(j, i, str(cm_arr[i, j]), ha='center', va='center', color=color, fontweight='bold', fontsize=12)

    ax.set_title(f'Multimodal Fusion Confusion Matrix\nHoldout Test Accuracy: {acc * 100:.1f}% | Macro F1: {macro_f1:.3f}', fontsize=11, fontweight='bold', pad=12)
    ax.set_ylabel('True Clinical Category', fontsize=10)
    ax.set_xlabel('Predicted Screening Stratum', fontsize=10)
    plt.tight_layout()

    cm_path = os.path.join(fig_dir, "fusion_confusion_matrix.png")
    cm_brain = os.path.join(brain_dir, "fusion_confusion_matrix.png")
    plt.savefig(cm_path, dpi=200, bbox_inches='tight')
    plt.savefig(cm_brain, dpi=200, bbox_inches='tight')
    plt.close()

    # 2. Feature Importance Figure
    feat_imp = model.get_feature_importance()
    top_items = list(feat_imp.items())[:12]
    top_names = [k for k, v in reversed(top_items)]
    top_vals = [v for k, v in reversed(top_items)]

    plt.figure(figsize=(10, 6), dpi=200)
    plt.barh(range(len(top_names)), top_vals, color='#7c3aed', edgecolor='#5b21b6')
    plt.yticks(range(len(top_names)), top_names, fontsize=10)
    plt.xlabel('XGBoost Relative Gain Feature Importance', fontsize=10)
    plt.title('Top Multimodal Screening Risk Predictors', fontsize=12, fontweight='bold')
    plt.grid(True, axis='x', linestyle=':', alpha=0.6)
    plt.tight_layout()

    fi_path = os.path.join(fig_dir, "fusion_feature_importance.png")
    fi_brain = os.path.join(brain_dir, "fusion_feature_importance.png")
    plt.savefig(fi_path, dpi=200, bbox_inches='tight')
    plt.savefig(fi_brain, dpi=200, bbox_inches='tight')
    plt.close()

    # 3. Ablation Study Comparison Figure
    ablation_csv = os.path.join(output_dir, "reports", "ablation_study.csv")
    if os.path.exists(ablation_csv):
        df_ab = pd.read_csv(ablation_csv)
        plt.figure(figsize=(12, 6), dpi=200)
        x_pos = np.arange(len(df_ab))
        width = 0.35
        plt.bar(x_pos - width/2, df_ab['Accuracy'] * 100, width, label='Accuracy (%)', color='#0284c7')
        plt.bar(x_pos + width/2, df_ab['Macro F1'] * 100, width, label='Macro F1 (%)', color='#10b981')
        plt.xticks(x_pos, df_ab['Modality Combination'], rotation=35, ha='right', fontsize=9)
        plt.ylabel('Performance Metric (%)', fontsize=10)
        plt.ylim(60, 105)
        plt.title('8-Way Multimodal Modality Ablation Study', fontsize=12, fontweight='bold')
        plt.legend(frameon=True)
        plt.grid(True, axis='y', linestyle=':', alpha=0.6)
        plt.tight_layout()

        ab_path = os.path.join(fig_dir, "ablation_study_comparison.png")
        ab_brain = os.path.join(brain_dir, "ablation_study_comparison.png")
        plt.savefig(ab_path, dpi=200, bbox_inches='tight')
        plt.savefig(ab_brain, dpi=200, bbox_inches='tight')
        plt.close()

    print(f"Fusion evaluation figures saved to {fig_dir}")
    return metrics
