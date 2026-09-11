"""
SwasthAI Fusion ML - Model Training, Benchmarking & 8-Way Ablation Study
"""

import os
import json
import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.svm import SVC
from sklearn.dummy import DummyClassifier
from sklearn.impute import SimpleImputer
from sklearn.pipeline import make_pipeline
from sklearn.metrics import accuracy_score, f1_score, precision_score, recall_score, classification_report
from .fusion_model import SwasthAIFusionModel
from ..tuning.optuna_fusion_tuner import FusionOptunaTuner

def train_fusion_pipeline(
    dataset_csv: str = "fusion_ml/data/multimodal_fusion_dataset.csv",
    output_dir: str = "fusion_ml/models",
    n_trials: int = 20
):
    print("=== STARTING SWASTHAI MULTIMODAL FUSION TRAINING ===")
    df = pd.read_csv(dataset_csv)
    print(f"Loaded dataset: {len(df)} samples across {df['subject_id'].nunique()} subjects.")

    # 1. Subject-Level Splitting (Holdout 20% subjects: subjects 41 to 50)
    test_subjects = list(range(41, 51))
    train_subjects = [s for s in df['subject_id'].unique() if s not in test_subjects]

    df_train = df[df['subject_id'].isin(train_subjects)].copy()
    df_test = df[df['subject_id'].isin(test_subjects)].copy()

    print(f"Training subjects ({len(train_subjects)}): {len(df_train)} samples")
    print(f"Holdout Test subjects ({len(test_subjects)}): {len(df_test)} samples")

    exclude_cols = ['subject_id', 'session_id', 'risk_category', 'composite_risk_score']
    feature_cols = [c for c in df.columns if c not in exclude_cols]
    print(f"Selected {len(feature_cols)} fusion features: {feature_cols}")

    X_train = df_train[feature_cols].values
    y_train = df_train['risk_category'].values
    groups_train = df_train['subject_id'].values

    X_test = df_test[feature_cols].values
    y_test = df_test['risk_category'].values

    # 2. Optuna Hyperparameter Optimization
    print("\n--- Running Optuna Hyperparameter Tuning ---")
    tuner = FusionOptunaTuner(n_trials=n_trials, n_splits=4, random_state=42)
    tuning_res = tuner.tune(X_train, y_train, groups_train)
    print(f"Best CV Macro F1: {tuning_res['best_macro_f1']:.4f}")
    print(f"Best Parameters: {json.dumps(tuning_res['best_params'], indent=2)}")

    os.makedirs("fusion_ml/outputs/experiments", exist_ok=True)
    with open("fusion_ml/outputs/experiments/optuna_best_params.json", "w") as f:
        json.dump(tuning_res, f, indent=2)

    # 3. Model Benchmark Comparison
    print("\n--- Model Benchmark Comparison (Holdout Test Subjects) ---")
    benchmarks = {
        'Majority Class Baseline': DummyClassifier(strategy='most_frequent'),
        'Logistic Regression': make_pipeline(SimpleImputer(strategy='median'), LogisticRegression(max_iter=500)),
        'Random Forest': make_pipeline(SimpleImputer(strategy='median'), RandomForestClassifier(n_estimators=100, max_depth=4, random_state=42)),
        'Support Vector Classifier': make_pipeline(SimpleImputer(strategy='median'), SVC(probability=True, random_state=42)),
        'XGBoost (Optuna Tuned)': SwasthAIFusionModel(params={**tuning_res['best_params'], 'objective': 'multi:softprob', 'num_class': 3, 'random_state': 42}).model
    }

    bench_records = []
    for name, m in benchmarks.items():
        m.fit(X_train, y_train)
        preds = m.predict(X_test)
        if hasattr(preds, 'ndim') and preds.ndim > 1:
            preds = np.argmax(preds, axis=1)
        acc = accuracy_score(y_test, preds)
        macro_f1 = f1_score(y_test, preds, average='macro')
        weighted_f1 = f1_score(y_test, preds, average='weighted')
        macro_recall = recall_score(y_test, preds, average='macro')

        bench_records.append({
            'Model': name,
            'Accuracy': round(acc, 4),
            'Macro F1': round(macro_f1, 4),
            'Weighted F1': round(weighted_f1, 4),
            'Macro Sensitivity (Recall)': round(macro_recall, 4)
        })

    df_bench = pd.DataFrame(bench_records)
    print(df_bench.to_string(index=False))
    os.makedirs("fusion_ml/outputs/reports", exist_ok=True)
    df_bench.to_csv("fusion_ml/outputs/reports/model_benchmark.csv", index=False)

    # 4. 8-Way Modality Ablation Study
    print("\n--- 8-Way Modality Ablation Study ---")
    modalities = {
        'spo2': [c for c in feature_cols if 'spo2' in c],
        'pressure': [c for c in feature_cols if 'pressure' in c],
        'sound': [c for c in feature_cols if 'sound' in c],
        'quest': [c for c in feature_cols if any(k in c for k in ['questionnaire', 'patient_age', 'smoking', 'biomass', 'breath', 'cough', 'phlegm', 'wheez'])]
    }

    ablation_sets = {
        'A: Questionnaire Only': modalities['quest'],
        'B: Questionnaire + SpO2': modalities['quest'] + modalities['spo2'],
        'C: Questionnaire + Pressure': modalities['quest'] + modalities['pressure'],
        'D: Questionnaire + Sound': modalities['quest'] + modalities['sound'],
        'E: Questionnaire + SpO2 + Pressure': modalities['quest'] + modalities['spo2'] + modalities['pressure'],
        'F: Questionnaire + SpO2 + Sound': modalities['quest'] + modalities['spo2'] + modalities['sound'],
        'G: Questionnaire + Pressure + Sound': modalities['quest'] + modalities['pressure'] + modalities['sound'],
        'H: Full Multimodal Fusion (All 4)': feature_cols
    }

    ablation_records = []
    for ab_name, feats in ablation_sets.items():
        X_tr_sub = df_train[feats].values
        X_te_sub = df_test[feats].values

        clf = SwasthAIFusionModel(params={**tuning_res['best_params'], 'objective': 'multi:softprob', 'num_class': 3, 'random_state': 42}).model
        clf.fit(X_tr_sub, y_train)
        preds = clf.predict(X_te_sub)
        if hasattr(preds, 'ndim') and preds.ndim > 1:
            preds = np.argmax(preds, axis=1)

        acc = accuracy_score(y_test, preds)
        f1 = f1_score(y_test, preds, average='macro')
        rec = recall_score(y_test, preds, average='macro')

        ablation_records.append({
            'Modality Combination': ab_name,
            'Features Used': len(feats),
            'Accuracy': round(acc, 4),
            'Macro F1': round(f1, 4),
            'Sensitivity (Recall)': round(rec, 4)
        })

    df_ablation = pd.DataFrame(ablation_records)
    print(df_ablation.to_string(index=False))
    df_ablation.to_csv("fusion_ml/outputs/reports/ablation_study.csv", index=False)

    # 5. Train & Save Final Best Model
    final_model = SwasthAIFusionModel(params={**tuning_res['best_params'], 'objective': 'multi:softprob', 'num_class': 3, 'random_state': 42})
    final_model.fit(X_train, y_train, feature_names=feature_cols)

    os.makedirs(output_dir, exist_ok=True)
    model_path = os.path.join(output_dir, "fusion_xgboost_model.json")
    final_model.save_model(model_path)
    print(f"\nSaved Best Fusion XGBoost Model to: {model_path}")

    # Save feature metadata
    with open(os.path.join(output_dir, "fusion_feature_columns.json"), "w") as f:
        json.dump({
            'feature_names': feature_cols,
            'class_labels': {'0': 'LOWER_RISK', '1': 'MODERATE_RISK', '2': 'HIGHER_RISK'},
            'modalities': list(modalities.keys())
        }, f, indent=2)

    # Save feature importance
    feat_imp = final_model.get_feature_importance()
    df_imp = pd.DataFrame([{'feature': k, 'importance': v} for k, v in feat_imp.items()])
    df_imp.to_csv("fusion_ml/outputs/reports/feature_importance.csv", index=False)

    return final_model, df_bench, df_ablation

if __name__ == "__main__":
    train_fusion_pipeline()
