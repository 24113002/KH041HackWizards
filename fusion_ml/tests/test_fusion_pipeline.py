"""
SwasthAI Fusion ML - Automated Unit Test Suite
"""

import unittest
import numpy as np
from fusion_ml.src.inference.predict_final_risk import SwasthAIRiskEngine

class TestFusionPipeline(unittest.TestCase):
    def setUp(self):
        self.engine = SwasthAIRiskEngine()

    def test_complete_lower_risk_case(self):
        spo2_res = {
            'status': 'SUCCESS',
            'spo2_classical_estimate': 98.6,
            'r_ratio': 0.46,
            'heart_rate_bpm': 68.0,
            'pathology_risk_probability': 0.05,
            'quality_score': 0.95
        }
        pressure_res = {
            'status': 'SUCCESS',
            'estimated_peak_pressure_cmh2o': 10.8,
            'peak_delta': 92000.0,
            'blow_duration_sec': 1.1,
            'signal_quality_score': 1.0
        }
        sound_res = {
            'status': 'success',
            'confidence': 0.92,
            'probabilities': {'normal': 0.92, 'pathological_adventitious': 0.08}
        }
        quest_res = {
            'age': 25,
            'years_smoked': 0,
            'cigarettes_per_day': 0,
            'biomass_exposure': False,
            'breathlessness': False,
            'chronic_cough': False
        }

        res = self.engine.predict_final_risk(spo2_res, pressure_res, sound_res, quest_res)
        self.assertEqual(res['status'], 'SUCCESS')
        self.assertEqual(res['screening_status'], 'COMPLETE')
        self.assertEqual(res['valid_modalities_count'], 4)
        self.assertLess(res['composite_risk_score'], 35.0)

    def test_complete_higher_risk_case(self):
        spo2_res = {
            'status': 'SUCCESS',
            'spo2_classical_estimate': 91.2,
            'r_ratio': 0.75,
            'heart_rate_bpm': 88.0,
            'pathology_risk_probability': 0.92,
            'quality_score': 0.90
        }
        pressure_res = {
            'status': 'SUCCESS',
            'estimated_peak_pressure_cmh2o': 38.5,
            'peak_delta': 320000.0,
            'blow_duration_sec': 1.8,
            'signal_quality_score': 1.0
        }
        sound_res = {
            'status': 'success',
            'confidence': 0.95,
            'probabilities': {'normal': 0.05, 'pathological_adventitious': 0.95}
        }
        quest_res = {
            'age': 65,
            'years_smoked': 30,
            'cigarettes_per_day': 20,
            'biomass_exposure': True,
            'breathlessness': True,
            'chronic_cough': True
        }

        res = self.engine.predict_final_risk(spo2_res, pressure_res, sound_res, quest_res)
        self.assertEqual(res['status'], 'SUCCESS')
        self.assertEqual(res['screening_status'], 'COMPLETE')
        self.assertGreater(res['composite_risk_score'], 65.0)

    def test_partial_screening_missing_spo2(self):
        # SpO2 is None / missing
        pressure_res = {
            'status': 'SUCCESS',
            'estimated_peak_pressure_cmh2o': 22.0,
            'peak_delta': 185000.0,
            'blow_duration_sec': 1.3,
            'signal_quality_score': 1.0
        }
        sound_res = {
            'status': 'success',
            'confidence': 0.85,
            'probabilities': {'normal': 0.50, 'pathological_adventitious': 0.50}
        }
        quest_res = {
            'age': 52,
            'years_smoked': 10,
            'cigarettes_per_day': 10,
            'biomass_exposure': True,
            'breathlessness': True,
            'chronic_cough': False
        }

        res = self.engine.predict_final_risk(None, pressure_res, sound_res, quest_res)
        self.assertEqual(res['status'], 'SUCCESS')
        self.assertEqual(res['screening_status'], 'PARTIAL')
        self.assertEqual(res['valid_modalities_count'], 3)
        self.assertIsNone(res['modality_risk_scores']['spo2_risk'])

    def test_invalid_all_missing(self):
        res = self.engine.predict_final_risk(None, None, None, None)
        self.assertEqual(res['status'], 'INVALID')
        self.assertEqual(res['valid_modalities_count'], 0)
        self.assertIsNone(res['composite_risk_score'])

if __name__ == '__main__':
    unittest.main()
