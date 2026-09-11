"""
SwasthAI SpO2 & PPG ML - Standalone Inference CLI
Accepts raw RED & IR PPG readings or CSV file and returns structured clinical screening output.
"""

import os
import json
import argparse
import numpy as np
import pandas as pd
from ..features.feature_pipeline import PPGFeaturePipeline
from ..models.xgboost_model import SwasthAIXGBoostModel
from ..models.classical_baseline import ClassicalPulseOximeter

class SpO2PPGPredictor:
    def __init__(
        self,
        model_path: str = "spo2_ml/models/spo2_xgb_best.json",
        features_path: str = "spo2_ml/models/features.json",
        labels_path: str = "spo2_ml/models/labels.json",
        sampling_rate: float = 100.0
    ):
        self.sampling_rate = sampling_rate
        self.pipeline = PPGFeaturePipeline(sampling_rate=sampling_rate)
        self.classical_oximeter = ClassicalPulseOximeter(sampling_rate=sampling_rate)
        
        # Load Model
        self.model = SwasthAIXGBoostModel()
        if os.path.exists(model_path):
            self.model.load_model(model_path)
            
        if os.path.exists(features_path):
            with open(features_path, 'r') as f:
                self.feature_names = json.load(f).get('feature_names', [])
        else:
            self.feature_names = []
            
        if os.path.exists(labels_path):
            with open(labels_path, 'r') as f:
                self.labels = json.load(f)
        else:
            self.labels = {'0': 'Normal_Respiratory_PPG', '1': 'Pathological_COPD_PPG'}

    def predict_raw_pair(self, red: np.ndarray, ir: np.ndarray) -> dict:
        red = np.asarray(red, dtype=np.float64)
        ir = np.asarray(ir, dtype=np.float64)
        
        # 1. Classical Pulse Oximetry Calculation
        classical_res = self.classical_oximeter.calculate_spo2(red, ir)
        
        # 2. Feature Extraction & Quality Verification
        feat_res = self.pipeline.extract_from_raw_pair(red, ir)
        
        if not feat_res['is_valid']:
            return {
                'status': 'INVALID_SIGNAL',
                'signal_quality': 'INVALID',
                'spo2_classical_estimate': None,
                'heart_rate_bpm': None,
                'ppg_pathology_prediction': None,
                'pathology_risk_score': None,
                'rejection_reason': feat_res['rejection_reason'],
                'clinical_disclaimer': 'Signal quality insufficient for reliable pulse oximetry or screening.'
            }
            
        features = feat_res['features']
        
        # 3. XGBoost Model Inference (using matching features)
        x_vec = np.zeros((1, len(self.feature_names)))
        for i, fname in enumerate(self.feature_names):
            x_vec[0, i] = features.get(fname, 0.0)
            
        try:
            probs = self.model.predict_proba(x_vec)[0]
            pred_idx = int(np.argmax(probs))
            pathology_prob = float(probs[1])
            pred_label = self.labels.get(str(pred_idx), f"Class_{pred_idx}")
        except Exception:
            pred_label = "Unavailable"
            pathology_prob = None
            
        return {
            'status': 'SUCCESS',
            'signal_quality': feat_res['signal_quality'],
            'spo2_classical_estimate': classical_res['spo2'],
            'r_ratio': classical_res['r_ratio'],
            'heart_rate_bpm': classical_res['heart_rate_bpm'],
            'ppg_pathology_prediction': pred_label,
            'pathology_risk_probability': round(pathology_prob, 4) if pathology_prob is not None else None,
            'quality_score': round(features['signal_quality_score'], 4),
            'model_version': 'SwasthAI_PPG_XGB_v1',
            'clinical_disclaimer': 'Screening support estimation only. Not a diagnostic confirmation of COPD or hypoxemia.'
        }

    def predict_window_row(self, window_256: np.ndarray) -> dict:
        """
        Inference on single normalized 256-point time-series window.
        """
        window_256 = np.asarray(window_256, dtype=np.float64)
        feats = self.pipeline.extract_from_window_row(window_256)
        
        x_vec = np.zeros((1, len(self.feature_names)))
        for i, fname in enumerate(self.feature_names):
            x_vec[0, i] = feats.get(fname, 0.0)
            
        probs = self.model.predict_proba(x_vec)[0]
        pred_idx = int(np.argmax(probs))
        
        return {
            'status': 'SUCCESS',
            'prediction': self.labels.get(str(pred_idx), f"Class_{pred_idx}"),
            'class_index': pred_idx,
            'confidence': round(float(probs[pred_idx]), 4),
            'probabilities': {
                'normal': round(float(probs[0]), 4),
                'copd_pathology': round(float(probs[1]), 4)
            },
            'model_version': 'SwasthAI_PPG_XGB_v1'
        }

def main():
    parser = argparse.ArgumentParser(description="SwasthAI SpO2 & PPG ML Inference CLI")
    parser.add_argument("--csv", type=str, help="Path to CSV containing RED and IR columns")
    parser.add_argument("--test_sample", action="store_true", help="Run on synthesized realistic MAX30102 PPG signals")
    args = parser.parse_args()
    
    predictor = SpO2PPGPredictor()
    
    if args.csv and os.path.exists(args.csv):
        df = pd.read_csv(args.csv)
        if 'red' in df.columns and 'ir' in df.columns:
            res = predictor.predict_raw_pair(df['red'].values, df['ir'].values)
            print(json.dumps(res, indent=2))
        else:
            print("CSV must contain 'red' and 'ir' columns.")
    elif args.test_sample or True:
        # Generate realistic MAX30102 PPG signal
        t = np.linspace(0, 4.0, 400)
        pulse = (np.sin(2 * np.pi * 1.15 * t) + 0.35 * np.sin(4 * np.pi * 1.15 * t + 0.5))
        red = 58200.0 + 850.0 * pulse + np.random.normal(0, 30, len(t))
        ir = 63400.0 + 1350.0 * pulse + np.random.normal(0, 30, len(t))
        
        print("=== RUNNING INFERENCE ON SAMPLE MAX30102 PPG RECORDING ===")
        res = predictor.predict_raw_pair(red, ir)
        print(json.dumps(res, indent=2))

if __name__ == '__main__':
    main()
