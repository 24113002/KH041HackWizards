"""
SwasthAI Air-Pressure ML - Automated Unit Test Suite
Tests baseline calculation, filtering, segmentation, feature extraction, signal quality gates, and inference.
"""

import unittest
import numpy as np
from ..src.preprocessing.baseline import BaselineEstimator
from ..src.preprocessing.filtering import RespiratoryFilter
from ..src.preprocessing.signal_quality import PressureSignalQualityChecker
from ..src.preprocessing.segmentation import RespiratoryBlowSegmenter
from ..src.features.respiratory_features import RespiratoryFeatureExtractor
from ..src.inference.inference import AirPressurePredictor

class TestAirPressurePipeline(unittest.TestCase):
    def setUp(self):
        self.fs = 100.0
        self.t = np.linspace(0, 4.0, int(4.0 * self.fs))
        self.baseline_val = 523433.0
        # Simulated blow occurring at t=2.0s (resting baseline from 0 to 1.0s)
        self.blow = 196567.0 * np.exp(-((self.t - 2.0) ** 2) / (2 * 0.3 ** 2))
        self.normal_raw = self.baseline_val + self.blow + np.random.normal(0, 50, len(self.t))

    def test_baseline_estimation(self):
        est = BaselineEstimator(sampling_rate=self.fs)
        b_info = est.estimate_baseline(self.normal_raw)
        self.assertAlmostEqual(b_info['baseline_mean'], self.baseline_val, delta=1000.0)
        self.assertTrue(b_info['is_stable'])

    def test_saturation_detection(self):
        checker = PressureSignalQualityChecker(sampling_rate=self.fs)
        # Saturated signal
        sat_signal = np.full_like(self.t, 8388600.0)
        res = checker.check_quality(sat_signal)
        self.assertFalse(res['is_valid'])
        self.assertEqual(res['quality_rating'], 'INVALID')

    def test_flatline_detection(self):
        checker = PressureSignalQualityChecker(sampling_rate=self.fs)
        # Flatline signal
        flat_signal = np.full_like(self.t, 523433.0)
        res = checker.check_quality(flat_signal)
        self.assertFalse(res['is_valid'])
        self.assertEqual(res['quality_rating'], 'INVALID')

    def test_segmentation(self):
        segmenter = RespiratoryBlowSegmenter(sampling_rate=self.fs)
        delta = self.blow
        seg = segmenter.segment(delta)
        self.assertTrue(seg['has_blow'])
        self.assertGreater(seg['peak_val'], 150000.0)
        self.assertGreater(seg['blow_duration_sec'], 0.5)

    def test_feature_extraction(self):
        extractor = RespiratoryFeatureExtractor(sampling_rate=self.fs)
        res = extractor.extract_features(self.normal_raw)
        self.assertTrue(res['is_valid'])
        self.assertIn('peak_delta', res['features'])
        self.assertIn('max_rise_rate', res['features'])
        self.assertIn('auc_total', res['features'])
        self.assertIn('skewness', res['features'])
        self.assertIn('dom_freq_hz', res['features'])

    def test_inference_and_invalid_rejection(self):
        predictor = AirPressurePredictor(sampling_rate=self.fs)
        # Valid test
        res_valid = predictor.predict_raw_session(self.normal_raw)
        self.assertEqual(res_valid['status'], 'SUCCESS')
        self.assertIsNotNone(res_valid['estimated_peak_pressure_cmh2o'])

        # Invalid test (Flatline)
        res_inv = predictor.predict_raw_session(np.full_like(self.t, 523433.0))
        self.assertEqual(res_inv['status'], 'INVALID_SIGNAL')
        self.assertIsNone(res_inv['estimated_peak_pressure_cmh2o'])

if __name__ == '__main__':
    unittest.main()
