"""
SwasthAI Air-Pressure ML - Master Orchestration Runner
Executes end-to-end pipeline: Feature Extraction -> Optuna Tuning -> Model Training -> Evaluation.
"""

import os
import glob
import re
import pandas as pd
import numpy as np
from .features.respiratory_features import RespiratoryFeatureExtractor
from .models.train import train_pipeline
from .evaluation.evaluate import evaluate_model

def run_feature_extraction(
    proc_dir: str = "airpressure-dataset/simulated-obstructive-disease-respiratory-pressure-and-flow-1.0.0/PQ_ProcessedData",
    raw_dir: str = "airpressure-dataset/simulated-obstructive-disease-respiratory-pressure-and-flow-1.0.0/PQ_RawData",
    output_csv: str = "air_pressure_ml/data/respiratory_features.csv"
):
    print("=== EXTRACTING FEATURES FROM 240 EXPERIMENTAL RESPIRATORY TRIALS ===")
    proc_files = sorted(glob.glob(os.path.join(proc_dir, "*.csv")))
    extractor = RespiratoryFeatureExtractor(sampling_rate=100.0)

    records = []
    for pf in proc_files:
        fname = os.path.basename(pf)
        match = re.match(r"ProcessedCOPD_Subject(\d+)_(\d+)cmH2O_(\d+)mL\.csv", fname)
        if not match:
            continue

        subj = int(match.group(1))
        peep = int(match.group(2))
        size = int(match.group(3))

        df_p = pd.read_csv(pf)
        p_cmh2o = df_p['Pressure [cmH2O]'].values
        q_flow = df_p['Flow [L/s]'].values
        v_tidal = df_p['V_tidal [L]'].values

        # Matching raw file
        raw_fname = f"COPDTrial2023_Subject{subj}_{peep}cmH2O_{size}mL_raw.csv"
        raw_fpath = os.path.join(raw_dir, raw_fname)

        if os.path.exists(raw_fpath):
            df_r = pd.read_csv(raw_fpath)
            g_adc = df_r['Gauge Pressure'].values
        else:
            g_adc = (p_cmh2o + 87.883697) / 0.010728

        feat_res = extractor.extract_features(g_adc)
        if feat_res['is_valid']:
            feats = feat_res['features']
            row = {
                'subject_id': subj,
                'peep_cmh2o': peep,
                'copd_sim_ml': size,
                'obstruction_class': 0 if size == 0 else (1 if size == 200 else (2 if size == 250 else 3)),
                **feats,
                'ref_peak_p_cmh2o': round(float(np.max(p_cmh2o)), 4),
                'ref_mean_p_cmh2o': round(float(np.mean(p_cmh2o)), 4),
                'ref_peak_flow_l_s': round(float(np.max(q_flow)), 4),
                'ref_max_volume_l': round(float(np.max(v_tidal)), 4)
            }
            records.append(row)

    df_out = pd.DataFrame(records)
    os.makedirs(os.path.dirname(output_csv), exist_ok=True)
    df_out.to_csv(output_csv, index=False)
    print(f"Extracted features saved to {output_csv} ({len(df_out)} rows, {df_out.shape[1]} columns)")
    return df_out

def main():
    # 1. Feature Extraction
    run_feature_extraction()

    # 2. Model Training & Tuning
    train_pipeline(n_trials=25)

    # 3. Evaluation & Diagnostics
    evaluate_model()

    print("\n=== AIR-PRESSURE ML PIPELINE COMPLETED SUCCESSFULLY ===")

if __name__ == "__main__":
    main()
