"""
SwasthAI Air-Pressure ML - Standalone Inference CLI & Engine
Accepts raw HX710B readings (or CSV) and returns structured respiratory pressure & screening indices.
"""

import os
import json
import argparse
import numpy as np
import pandas as pd
from ..features.respiratory_features import RespiratoryFeatureExtractor
from ..models.xgboost_regressor import AirPressureXGBModel

class AirPressurePredictor:
    def __init__(
        self,
        model_path: str = "air_pressure_ml/models/airpressure_xgb_best.json",
        config_path: str = "air_pressure_ml/models/feature_columns.json",
        sampling_rate: float = 100.0
    ):
        self.sampling_rate = sampling_rate
        self.extractor = RespiratoryFeatureExtractor(sampling_rate=sampling_rate)
        
        self.feature_names = []
        if os.path.exists(config_path):
            with open(config_path, "r") as f:
                self.feature_names = json.load(f).get("feature_names", [])

        self.model = AirPressureXGBModel(task="regression")
        if os.path.exists(model_path):
            self.model.load_model(model_path)
            self.model.feature_names = self.feature_names

    def predict_raw_session(self, raw_samples: np.ndarray) -> dict:
        raw = np.asarray(raw_samples, dtype=np.float64)
        
        # 1. Feature Extraction & Signal Quality Gate
        feat_res = self.extractor.extract_features(raw)
        if not feat_res['is_valid']:
            return {
                'status': 'INVALID_SIGNAL',
                'signal_quality': feat_res['signal_quality'],
                'rejection_reason': feat_res['rejection_reason'],
                'baseline_raw': None,
                'peak_raw': None,
                'peak_delta': None,
                'blow_duration_sec': None,
                'estimated_peak_pressure_cmh2o': None,
                'screening_risk_level': None,
                'clinical_disclaimer': 'Signal quality insufficient for reliable respiratory screening.'
            }

        feats = feat_res['features']
        b_info = feat_res['baseline_info']
        seg_info = feat_res['segmentation_info']

        # 2. XGBoost Prediction
        x_vec = np.zeros((1, len(self.feature_names)))
        for i, fname in enumerate(self.feature_names):
            x_vec[0, i] = feats.get(fname, 0.0)

        pred_p = float(self.model.predict(x_vec)[0])
        # Biological boundary clip (0.0 to 80.0 cmH2O)
        pred_p = max(0.0, min(80.0, pred_p))

        # Risk Stratification based on peak pressure & dynamics
        if pred_p < 15.0:
            risk = "NORMAL_RESISTANCE"
        elif pred_p < 25.0:
            risk = "MILD_AIRWAY_RESISTANCE"
        elif pred_p < 35.0:
            risk = "MODERATE_OBSTRUCTION_RISK"
        else:
            risk = "SEVERE_OBSTRUCTION_RISK"

        return {
            'status': 'SUCCESS',
            'signal_quality': feat_res['signal_quality'],
            'baseline_raw': b_info['baseline_mean'],
            'peak_raw': round(float(np.max(raw)), 2),
            'peak_delta': feats['peak_delta'],
            'blow_duration_sec': feats['blow_duration_sec'],
            'rise_time_sec': feats['rise_time_sec'],
            'estimated_peak_pressure_cmh2o': round(pred_p, 2),
            'screening_risk_level': risk,
            'signal_quality_score': feats['signal_quality_score'],
            'model_version': 'SwasthAI_AirPressure_XGB_v1',
            'clinical_disclaimer': 'Screening-support feature only. Not a diagnostic confirmation of COPD.'
        }

def main():
    parser = argparse.ArgumentParser(description="SwasthAI Air-Pressure ML Inference CLI")
    parser.add_argument("--csv", type=str, help="Path to CSV containing raw pressure column")
    parser.add_argument("--test_sample", action="store_true", help="Run on realistic ESP32 HX710B sample blow")
    args = parser.parse_args()

    predictor = AirPressurePredictor()

    if args.csv and os.path.exists(args.csv):
        df = pd.read_csv(args.csv)
        col = 'raw_adc' if 'raw_adc' in df.columns else df.columns[0]
        res = predictor.predict_raw_session(df[col].values)
        print(json.dumps(res, indent=2))
    elif args.test_sample or True:
        # Realistic ESP32 + HX710B blow signal (baseline ~ 523433, peak ~ 720000, 4s duration @ 100Hz)
        t = np.linspace(0, 4.0, 400)
        baseline = 523433.0
        # Bell-shaped respiratory blow curve
        blow = 196567.0 * np.exp(-((t - 1.5) ** 2) / (2 * 0.45 ** 2))
        raw = baseline + blow + np.random.normal(0, 250, len(t))
        
        print("=== RUNNING INFERENCE ON REALISTIC ESP32 HX710B RESPIRATORY BLOW ===")
        res = predictor.predict_raw_session(raw)
        print(json.dumps(res, indent=2))

if __name__ == "__main__":
    main()
