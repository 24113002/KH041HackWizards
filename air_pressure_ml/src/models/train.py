"""
SwasthAI Air-Pressure ML - Model Training Script
Performs feature dataset preparation, Optuna optimization, model training, and baseline comparison.
"""

import os
import json
import numpy as np
import pandas as pd
from sklearn.linear_model import LinearRegression, Ridge
from sklearn.ensemble import RandomForestRegressor
from sklearn.svm import SVR
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import scipy.stats
from .xgboost_regressor import AirPressureXGBModel
from ..tuning.optuna_tuner import AirPressureOptunaTuner

def train_pipeline(
    features_csv: str = "air_pressure_ml/data/respiratory_features.csv",
    output_dir: str = "air_pressure_ml/models",
    n_trials: int = 20
):
    print("=== STARTING SWASTHAI AIR-PRESSURE ML TRAINING ===")
    df = pd.read_csv(features_csv)
    print(f"Loaded features dataset: {df.shape[0]} trials across {df['subject_id'].nunique()} subjects.")

    # 1. Subject-Level Splitting (Holdout Test: Subjects 17, 18, 19, 20)
    test_subjects = [17, 18, 19, 20]
    train_subjects = [s for s in df['subject_id'].unique() if s not in test_subjects]

    df_train = df[df['subject_id'].isin(train_subjects)].copy()
    df_test = df[df['subject_id'].isin(test_subjects)].copy()

    print(f"Training subjects ({len(train_subjects)}): {train_subjects} -> {len(df_train)} trials")
    print(f"Holdout Test subjects ({len(test_subjects)}): {test_subjects} -> {len(df_test)} trials")

    # Feature column selection (exclude metadata and ground truth reference columns)
    exclude_cols = [
        'subject_id', 'peep_cmh2o', 'copd_sim_ml', 'obstruction_class',
        'ref_peak_p_cmh2o', 'ref_mean_p_cmh2o', 'ref_peak_flow_l_s', 'ref_max_volume_l'
    ]
    feature_cols = [c for c in df.columns if c not in exclude_cols]
    print(f"Selected {len(feature_cols)} input features: {feature_cols}")

    X_train = df_train[feature_cols].values
    y_train = df_train['ref_peak_p_cmh2o'].values
    groups_train = df_train['subject_id'].values

    X_test = df_test[feature_cols].values
    y_test = df_test['ref_peak_p_cmh2o'].values

    # 2. Optuna Hyperparameter Tuning (GroupKFold)
    print("\n--- Running Optuna Hyperparameter Optimization ---")
    tuner = AirPressureOptunaTuner(n_trials=n_trials, n_splits=4, random_state=42)
    tuning_res = tuner.tune_regression(X_train, y_train, groups_train)
    print(f"Best CV RMSE: {tuning_res['best_cv_rmse']:.4f} cmH2O")
    print(f"Best Parameters: {json.dumps(tuning_res['best_params'], indent=2)}")

    os.makedirs("air_pressure_ml/outputs/experiments", exist_ok=True)
    with open("air_pressure_ml/outputs/experiments/optuna_best_params.json", "w") as f:
        json.dump(tuning_res, f, indent=2)

    # 3. Benchmark Models Comparison
    print("\n--- Model Benchmark Comparison (Holdout Test Set) ---")
    models = {
        'Linear Regression': LinearRegression(),
        'Ridge Regression': Ridge(alpha=1.0),
        'Support Vector Regressor': SVR(C=10.0, epsilon=0.1),
        'Random Forest': RandomForestRegressor(n_estimators=100, max_depth=5, random_state=42),
        'XGBoost (Default)': AirPressureXGBModel(task='regression', params={'random_state': 42}).model,
        'XGBoost (Optuna Tuned)': AirPressureXGBModel(task='regression', params={**tuning_res['best_params'], 'random_state': 42}).model
    }

    benchmark_records = []
    for name, m in models.items():
        m.fit(X_train, y_train)
        preds = m.predict(X_test)
        mae = mean_absolute_error(y_test, preds)
        rmse = np.sqrt(mean_squared_error(y_test, preds))
        r2 = r2_score(y_test, preds)
        pearson_r, _ = scipy.stats.pearsonr(y_test, preds)

        benchmark_records.append({
            'Model': name,
            'MAE [cmH2O]': round(mae, 4),
            'RMSE [cmH2O]': round(rmse, 4),
            'R²': round(r2, 4),
            'Pearson r': round(pearson_r, 4)
        })

    df_bench = pd.DataFrame(benchmark_records)
    print(df_bench.to_string(index=False))
    df_bench.to_csv("air_pressure_ml/outputs/reports/model_benchmark.csv", index=False)

    # 4. Train and Save Final Best Model
    best_xgb = AirPressureXGBModel(task='regression', params={**tuning_res['best_params'], 'random_state': 42})
    best_xgb.fit(X_train, y_train, feature_names=feature_cols)

    os.makedirs(output_dir, exist_ok=True)
    model_save_path = os.path.join(output_dir, "airpressure_xgb_best.json")
    best_xgb.save_model(model_save_path)
    print(f"\nSaved Best XGBoost Model to: {model_save_path}")

    # Save feature names & config
    with open(os.path.join(output_dir, "feature_columns.json"), "w") as f:
        json.dump({'feature_names': feature_cols, 'target': 'ref_peak_p_cmh2o', 'unit': 'cmH2O'}, f, indent=2)

    # Save feature importance
    feat_imp = best_xgb.get_feature_importance()
    df_imp = pd.DataFrame([{'feature': k, 'importance': v} for k, v in feat_imp.items()])
    df_imp.to_csv("air_pressure_ml/outputs/reports/feature_importance.csv", index=False)
    print(f"Saved Feature Importance to air_pressure_ml/outputs/reports/feature_importance.csv")

    return best_xgb, df_bench

if __name__ == "__main__":
    train_pipeline()
