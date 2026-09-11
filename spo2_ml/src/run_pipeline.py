"""
SwasthAI SpO2 & PPG ML - Complete End-to-End Pipeline Runner
"""

import os
from spo2_ml.src.data.audit import audit_spo2_datasets
from spo2_ml.src.data.dataset_loader import build_feature_dataset
from spo2_ml.src.tuning.optuna_tuning import tune_xgboost
from spo2_ml.src.models.train import train_final_xgboost
from spo2_ml.src.evaluation.evaluate import evaluate_spo2_system
from spo2_ml.src.inference.predict import SpO2PPGPredictor

def run_full_spo2_pipeline(
    dataset_dir: str = "Spo2 dataset",
    target_db: str = "16s_db",
    tune: bool = True
):
    print("="*75)
    print("SWASTHAI SpO2 & PPG MACHINE LEARNING PIPELINE (XGBoost + Optuna)")
    print("="*75)
    
    # 1. Dataset Audit
    print("\n[STEP 1/5] Auditing SpO2 / PPG Datasets...")
    audit_spo2_datasets(dataset_dir, output_report_file="spo2_ml/outputs/reports/dataset_audit_report.md")
    
    # 2. Build Feature Dataset with Subject-Level Isolation
    print("\n[STEP 2/5] Extracting Engineered PPG Features & Subject-Level Splitting...")
    feature_csv = "spo2_ml/data/features.csv"
    splits_file = "spo2_ml/data/splits/subject_splits.json"
    build_feature_dataset(
        dataset_dir=dataset_dir,
        target_db=target_db,
        output_feature_file=feature_csv,
        output_splits_file=splits_file,
        sample_limit_per_subject=2500
    )
    
    # 3. Optuna Hyperparameter Tuning
    if tune:
        print("\n[STEP 3/5] Running Optuna Hyperparameter Optimization...")
        tune_xgboost(
            feature_csv=feature_csv,
            n_trials=15,
            output_params_file="spo2_ml/outputs/experiments/optuna_best_params.json"
        )
        
    # 4. Final Model Training
    print("\n[STEP 4/5] Training Final XGBoost Model with Subject Isolation...")
    train_final_xgboost(
        feature_csv=feature_csv,
        splits_file=splits_file,
        best_params_file="spo2_ml/outputs/experiments/optuna_best_params.json",
        models_dir="spo2_ml/models"
    )
    
    # 5. Evaluation & Diagnostic Visualization Generation
    print("\n[STEP 5/5] Evaluating Model & Generating Diagnostic Visualizations...")
    evaluate_spo2_system(
        feature_csv=feature_csv,
        splits_file=splits_file,
        model_path="spo2_ml/models/spo2_xgb_best.json",
        figures_dir="spo2_ml/outputs/figures",
        reports_dir="spo2_ml/outputs/reports"
    )
    
    print("\n" + "="*75)
    print("SWASTHAI SpO2 & PPG ML PIPELINE COMPLETED SUCCESSFULLY!")
    print("="*75)

if __name__ == '__main__':
    run_full_spo2_pipeline(tune=True)
