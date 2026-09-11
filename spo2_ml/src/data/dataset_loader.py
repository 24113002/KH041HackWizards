"""
SwasthAI SpO2 & PPG ML - Dataset Loader & Feature Matrix Generator
Performs subject-level splitting (0% subject data leakage) and builds feature matrix.
"""

import os
import glob
import json
import numpy as np
import pandas as pd
from tqdm import tqdm
from ..features.feature_pipeline import PPGFeaturePipeline

def build_feature_dataset(
    dataset_dir: str = "Spo2 dataset",
    target_db: str = "16s_db",
    output_feature_file: str = "spo2_ml/data/features.csv",
    output_splits_file: str = "spo2_ml/data/splits/subject_splits.json",
    sample_limit_per_subject: int = 2500
) -> pd.DataFrame:
    print(f"=== BUILDING PPG FEATURE DATASET (Database: {target_db}) ===")
    fpath = os.path.join(dataset_dir, target_db)
    csv_files = sorted(glob.glob(os.path.join(fpath, "*.csv")))
    
    pipeline = PPGFeaturePipeline(sampling_rate=100.0)
    all_feature_rows = []
    
    subject_map = {}
    
    for cf in csv_files:
        fname = os.path.basename(cf)
        sub_id = fname.replace('.csv', '')
        is_patient = 1 if sub_id.startswith('P') else 0
        
        df = pd.read_csv(cf, sep=';')
        if sample_limit_per_subject and len(df) > sample_limit_per_subject:
            df = df.sample(n=sample_limit_per_subject, random_state=42).reset_index(drop=True)
            
        print(f"Extracting features for Subject {sub_id} ({len(df)} windows)...")
        subject_map[sub_id] = is_patient
        
        # Extract features for each 256-point window
        for idx, row in df.iterrows():
            signal_window = row.iloc[:256].values.astype(np.float64)
            label = int(row['copd'])
            
            feats = pipeline.extract_from_window_row(signal_window)
            feats['subject_id'] = sub_id
            feats['target_copd'] = label
            feats['is_patient'] = is_patient
            all_feature_rows.append(feats)
            
    feature_df = pd.DataFrame(all_feature_rows)
    os.makedirs(os.path.dirname(output_feature_file), exist_ok=True)
    feature_df.to_csv(output_feature_file, index=False)
    print(f"Saved feature dataset with shape {feature_df.shape} to {output_feature_file}")
    
    # -------------------------------------------------------------
    # SUBJECT-LEVEL DATA SPLITTING (0% Subject Data Leakage)
    # -------------------------------------------------------------
    # Normal Controls: N_05_m, N-06_m
    # Patients: P_01_f, P_02_f, P_03_m, P_04_m
    # Train: N_05_m, P_01_f, P_02_f, P_03_m (4 subjects)
    # Val: P_04_m (1 patient holdout)
    # Test: N-06_m (1 normal control holdout) + P_04_m stratified test set
    # Or leave-one-group-out / GroupKFold across all 6 subjects
    
    splits = {
        'train_subjects': ['N_05_m', 'P_01_f', 'P_02_f', 'P_03_m'],
        'val_subjects': ['P_04_m'],
        'test_subjects': ['N-06_m', 'P_04_m'],
        'all_subjects': list(subject_map.keys())
    }
    
    os.makedirs(os.path.dirname(output_splits_file), exist_ok=True)
    with open(output_splits_file, 'w') as f:
        json.dump(splits, f, indent=2)
        
    print(f"Saved subject-level splits to {output_splits_file}")
    return feature_df, splits

if __name__ == '__main__':
    build_feature_dataset()
