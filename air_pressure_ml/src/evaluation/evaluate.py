"""
SwasthAI Air-Pressure ML - Evaluation & Diagnostic Plotting Module
Generates holdout predicted vs actual plots, residual distributions, and Bland-Altman agreement plots.
"""

import os
import json
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import scipy.stats
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from ..models.xgboost_regressor import AirPressureXGBModel

def evaluate_model(
    model_path: str = "air_pressure_ml/models/airpressure_xgb_best.json",
    features_csv: str = "air_pressure_ml/data/respiratory_features.csv",
    config_path: str = "air_pressure_ml/models/feature_columns.json",
    output_dir: str = "air_pressure_ml/outputs"
):
    df = pd.read_csv(features_csv)
    with open(config_path, "r") as f:
        cfg = json.load(f)
    feature_cols = cfg['feature_names']

    # Holdout Test Set (Subjects 17, 18, 19, 20)
    test_subjects = [17, 18, 19, 20]
    df_test = df[df['subject_id'].isin(test_subjects)].copy()

    X_test = df_test[feature_cols].values
    y_test = df_test['ref_peak_p_cmh2o'].values

    model = AirPressureXGBModel(task="regression")
    model.load_model(model_path)
    model.feature_names = feature_cols

    preds = model.predict(X_test)

    mae = float(mean_absolute_error(y_test, preds))
    rmse = float(np.sqrt(mean_squared_error(y_test, preds)))
    r2 = float(r2_score(y_test, preds))
    pearson_r, _ = scipy.stats.pearsonr(y_test, preds)
    spearman_rho, _ = scipy.stats.spearmanr(y_test, preds)
    residuals = preds - y_test

    metrics = {
        'mae_cmh2o': round(mae, 4),
        'rmse_cmh2o': round(rmse, 4),
        'r2_score': round(r2, 4),
        'pearson_r': round(float(pearson_r), 4),
        'spearman_rho': round(float(spearman_rho), 4),
        'test_subjects_count': len(test_subjects),
        'test_samples_count': len(y_test)
    }

    os.makedirs(os.path.join(output_dir, "reports"), exist_ok=True)
    with open(os.path.join(output_dir, "reports", "evaluation_metrics.json"), "w") as f:
        json.dump(metrics, f, indent=2)

    # Generate Evaluation Figures
    fig_dir = os.path.join(output_dir, "figures")
    brain_dir = r"C:\Users\gaura\.gemini\antigravity-ide\brain\6e858849-0199-4f34-8c8b-7304b1b07771"
    os.makedirs(fig_dir, exist_ok=True)

    plt.style.use('default')
    fig, axs = plt.subplots(1, 3, figsize=(18, 5.5), dpi=200)
    fig.patch.set_facecolor('#ffffff')

    # 1. Predicted vs Actual
    min_val = min(np.min(y_test), np.min(preds)) - 2
    max_val = max(np.max(y_test), np.max(preds)) + 2
    axs[0].scatter(y_test, preds, color='#0284c7', alpha=0.75, edgecolors='none', s=45, label='Test Trials')
    axs[0].plot([min_val, max_val], [min_val, max_val], 'r--', lw=1.8, label='Ideal Line (y = x)')
    axs[0].set_title(f'Predicted vs Actual Peak Pressure\n$R^2 = {r2:.3f} | Pearson r = {pearson_r:.3f}$', fontsize=11, fontweight='bold')
    axs[0].set_xlabel('Reference Peak Pressure [cmH2O]', fontsize=10)
    axs[0].set_ylabel('XGBoost Estimated Peak Pressure [cmH2O]', fontsize=10)
    axs[0].legend(frameon=True)
    axs[0].grid(True, linestyle=':', alpha=0.6)

    # 2. Residual Distribution
    axs[1].hist(residuals, bins=15, color='#10b981', edgecolor='#065f46', alpha=0.8)
    axs[1].axvline(0, color='#dc2626', linestyle='--', lw=1.8)
    axs[1].set_title(f'Residual Error Distribution\nMAE = {mae:.2f} cmH2O | RMSE = {rmse:.2f} cmH2O', fontsize=11, fontweight='bold')
    axs[1].set_xlabel('Prediction Error (Predicted - Actual) [cmH2O]', fontsize=10)
    axs[1].set_ylabel('Trial Count', fontsize=10)
    axs[1].grid(True, linestyle=':', alpha=0.6)

    # 3. Bland-Altman Agreement Plot
    mean_pair = (preds + y_test) / 2.0
    diff_pair = preds - y_test
    mean_diff = np.mean(diff_pair)
    std_diff = np.std(diff_pair)
    axs[2].scatter(mean_pair, diff_pair, color='#7c3aed', alpha=0.75, edgecolors='none', s=45)
    axs[2].axhline(mean_diff, color='#dc2626', linestyle='-', lw=1.8, label=f'Mean Bias: {mean_diff:.2f}')
    axs[2].axhline(mean_diff + 1.96 * std_diff, color='#d97706', linestyle='--', lw=1.5, label=f'+1.96 SD: {mean_diff + 1.96 * std_diff:.2f}')
    axs[2].axhline(mean_diff - 1.96 * std_diff, color='#d97706', linestyle='--', lw=1.5, label=f'-1.96 SD: {mean_diff - 1.96 * std_diff:.2f}')
    axs[2].set_title('Bland-Altman Agreement Analysis', fontsize=11, fontweight='bold')
    axs[2].set_xlabel('Mean of (Predicted + Actual) [cmH2O]', fontsize=10)
    axs[2].set_ylabel('Difference (Predicted - Actual) [cmH2O]', fontsize=10)
    axs[2].legend(frameon=True, fontsize=9)
    axs[2].grid(True, linestyle=':', alpha=0.6)

    plt.tight_layout()
    fig1_path = os.path.join(fig_dir, "airpressure_evaluation_diagnostics.png")
    fig1_brain = os.path.join(brain_dir, "airpressure_evaluation_diagnostics.png")
    plt.savefig(fig1_path, dpi=200, bbox_inches='tight')
    plt.savefig(fig1_brain, dpi=200, bbox_inches='tight')
    plt.close()

    # 4. Feature Importance Plot
    imp_dict = model.get_feature_importance()
    top_items = list(imp_dict.items())[:12]
    top_names = [k for k, v in reversed(top_items)]
    top_vals = [v for k, v in reversed(top_items)]

    plt.figure(figsize=(10, 6), dpi=200)
    plt.barh(range(len(top_names)), top_vals, color='#0284c7', edgecolor='#0369a1')
    plt.yticks(range(len(top_names)), top_names, fontsize=10)
    plt.xlabel('XGBoost Relative Gain Feature Importance', fontsize=10)
    plt.title('Top Respiratory Waveform Features for Peak Pressure Estimation', fontsize=12, fontweight='bold')
    plt.grid(True, axis='x', linestyle=':', alpha=0.6)
    plt.tight_layout()

    fig2_path = os.path.join(fig_dir, "airpressure_feature_importance.png")
    fig2_brain = os.path.join(brain_dir, "airpressure_feature_importance.png")
    plt.savefig(fig2_path, dpi=200, bbox_inches='tight')
    plt.savefig(fig2_brain, dpi=200, bbox_inches='tight')
    plt.close()

    print(f"Evaluation complete. Figures saved to {fig1_path} and {fig2_path}")
    return metrics
