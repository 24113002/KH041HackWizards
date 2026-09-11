"""
SwasthAI SpO2 & PPG ML - Optuna Hyperparameter Tuning Module
Optimizes XGBoost hyperparameters using Subject-Grouped Cross-Validation.
"""

import os
import json
import optuna
import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.model_selection import GroupKFold
from sklearn.metrics import f1_score, roc_auc_score

def tune_xgboost(
    feature_csv: str = "spo2_ml/data/features.csv",
    n_trials: int = 20,
    output_params_file: str = "spo2_ml/outputs/experiments/optuna_best_params.json"
) -> dict:
    print("=== STARTING OPTUNA HYPERPARAMETER TUNING FOR XGBOOST ===")
    df = pd.read_csv(feature_csv)
    
    # Feature columns (exclude subject metadata and target)
    ignore_cols = {'subject_id', 'target_copd', 'is_patient'}
    feature_cols = [c for c in df.columns if c not in ignore_cols]
    
    X = df[feature_cols].values
    y = df['target_copd'].values
    groups = df['subject_id'].values
    
    gkf = GroupKFold(n_splits=3)
    
    def objective(trial):
        params = {
            'n_estimators': trial.suggest_int('n_estimators', 50, 200, step=25),
            'max_depth': trial.suggest_int('max_depth', 3, 6),
            'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.20, log=True),
            'subsample': trial.suggest_float('subsample', 0.6, 1.0),
            'colsample_bytree': trial.suggest_float('colsample_bytree', 0.6, 1.0),
            'min_child_weight': trial.suggest_int('min_child_weight', 1, 6),
            'gamma': trial.suggest_float('gamma', 0.0, 0.5),
            'reg_alpha': trial.suggest_float('reg_alpha', 1e-4, 1.0, log=True),
            'reg_lambda': trial.suggest_float('reg_lambda', 1e-4, 2.0, log=True),
            'random_state': 42,
            'eval_metric': 'logloss',
            'n_jobs': -1
        }
        
        cv_f1_scores = []
        for train_idx, val_idx in gkf.split(X, y, groups=groups):
            X_tr, y_tr = X[train_idx], y[train_idx]
            X_v, y_v = X[val_idx], y[val_idx]
            
            clf = xgb.XGBClassifier(**params)
            clf.fit(X_tr, y_tr, verbose=False)
            preds = clf.predict(X_v)
            f1 = f1_score(y_v, preds, zero_division=0)
            cv_f1_scores.append(f1)
            
        return float(np.mean(cv_f1_scores))

    optuna.logging.set_verbosity(optuna.logging.INFO)
    study = optuna.create_study(direction='maximize')
    study.optimize(objective, n_trials=n_trials)
    
    print("\n=== OPTUNA STUDY FINISHED ===")
    print(f"Best Subject-Grouped CV F1: {study.best_value:.4f}")
    print("Best Hyperparameters:")
    for k, v in study.best_params.items():
        print(f"  {k}: {v}")
        
    os.makedirs(os.path.dirname(output_params_file), exist_ok=True)
    with open(output_params_file, 'w') as f:
        json.dump({
            'best_cv_f1': study.best_value,
            'best_params': study.best_params,
            'n_trials': len(study.trials)
        }, f, indent=2)
        
    return study.best_params

if __name__ == '__main__':
    tune_xgboost()
