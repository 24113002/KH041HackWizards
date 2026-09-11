"""
SwasthAI SpO2 & PPG ML - Final Model Training & Checkpoint Engine
"""

import os
import json
import pandas as pd
import numpy as np
from .xgboost_model import SwasthAIXGBoostModel

def train_final_xgboost(
    feature_csv: str = "spo2_ml/data/features.csv",
    splits_file: str = "spo2_ml/data/splits/subject_splits.json",
    best_params_file: str = "spo2_ml/outputs/experiments/optuna_best_params.json",
    models_dir: str = "spo2_ml/models"
):
    print("=== TRAINING FINAL SWASTHAI PPG XGBOOST MODEL ===")
    df = pd.read_csv(feature_csv)
    
    with open(splits_file, 'r') as f:
        splits = json.load(f)
        
    train_subs = splits['train_subjects']
    val_subs = splits['val_subjects']
    test_subs = splits['test_subjects']
    
    ignore_cols = {'subject_id', 'target_copd', 'is_patient'}
    feature_cols = [c for c in df.columns if c not in ignore_cols]
    
    train_df = df[df['subject_id'].isin(train_subs)]
    val_df = df[df['subject_id'].isin(val_subs)]
    test_df = df[df['subject_id'].isin(test_subs)]
    
    print(f"Train Set: {len(train_df):,} windows from subjects {train_subs}")
    print(f"Val Set:   {len(val_df):,} windows from subjects {val_subs}")
    print(f"Test Set:  {len(test_df):,} windows from subjects {test_subs}")
    
    X_train, y_train = train_df[feature_cols].values, train_df['target_copd'].values
    X_val, y_val = val_df[feature_cols].values, val_df['target_copd'].values
    X_test, y_test = test_df[feature_cols].values, test_df['target_copd'].values
    
    # Load tuned parameters
    params = {}
    if os.path.exists(best_params_file):
        with open(best_params_file, 'r') as f:
            study_data = json.load(f)
            params = study_data.get('best_params', {})
            
    xgb_wrapper = SwasthAIXGBoostModel(
        n_estimators=params.get('n_estimators', 150),
        max_depth=params.get('max_depth', 4),
        learning_rate=params.get('learning_rate', 0.05),
        subsample=params.get('subsample', 0.8),
        colsample_bytree=params.get('colsample_bytree', 0.8),
        min_child_weight=params.get('min_child_weight', 3),
        gamma=params.get('gamma', 0.1),
        reg_alpha=params.get('reg_alpha', 0.05),
        reg_lambda=params.get('reg_lambda', 1.0)
    )
    
    xgb_wrapper.fit(X_train, y_train, X_val, y_val, feature_names=feature_cols)
    
    # Save Model Checkpoint
    os.makedirs(models_dir, exist_ok=True)
    model_path = os.path.join(models_dir, "spo2_xgb_best.json")
    xgb_wrapper.save_model(model_path)
    
    # Save Feature List
    with open(os.path.join(models_dir, "features.json"), 'w') as f:
        json.dump({'feature_names': feature_cols, 'count': len(feature_cols)}, f, indent=2)
        
    # Save Labels
    labels = {
        '0': 'Normal_Respiratory_PPG',
        '1': 'Pathological_COPD_PPG'
    }
    with open(os.path.join(models_dir, "labels.json"), 'w') as f:
        json.dump(labels, f, indent=2)
        
    print(f"Final training complete. Model and metadata saved to {models_dir}")
    return xgb_wrapper, feature_cols

if __name__ == '__main__':
    train_final_xgboost()
