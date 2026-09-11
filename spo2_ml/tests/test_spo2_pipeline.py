"""
SwasthAI SpO2 & PPG ML - Automated Unit & Integration Tests
"""

import unittest
import numpy as np
from spo2_ml.src.preprocessing.signal_quality import SignalQualityChecker
from spo2_ml.src.preprocessing.ppg_preprocessing import PPGPreprocessor
from spo2_ml.src.features.ac_dc_extractor import ACDCExtractor
from spo2_ml.src.features.ppg_features import PPGFeatureExtractor
from spo2_ml.src.models.classical_baseline import ClassicalPulseOximeter

class TestSpO2PPGPipeline(unittest.TestCase):
    def test_saturation_detection_and_rejection(self):
        # Test case with saturated samples (262143 in 18-bit ADC)
        checker = SignalQualityChecker()
        sat_signal = np.full(400, 262143.0)
        res = checker.check_quality(sat_signal)
        
        self.assertFalse(res['is_valid'])
        self.assertEqual(res['quality_rating'], 'INVALID')
        self.assertEqual(res['saturation_pct'], 100.0)
        
    def test_ac_dc_and_r_ratio(self):
        t = np.linspace(0, 4.0, 400)
        pulse = np.sin(2 * np.pi * 1.2 * t)
        red = 50000.0 + 1000.0 * pulse
        ir = 50000.0 + 1500.0 * pulse
        
        preprocessor = PPGPreprocessor(sampling_rate=100.0)
        prep = preprocessor.preprocess_pair(red, ir)
        
        extractor = ACDCExtractor(sampling_rate=100.0)
        red_dict = extractor.compute_ac_dc(prep['red_raw'], prep['red_ac'])
        ir_dict = extractor.compute_ac_dc(prep['ir_raw'], prep['ir_ac'])
        r_info = extractor.compute_r_ratio(red_dict, ir_dict)
        
        self.assertIsNotNone(r_info['r_ratio'])
        self.assertGreater(r_info['r_ratio'], 0.5)
        self.assertLess(r_info['r_ratio'], 1.0)
        self.assertGreater(r_info['spo2_estimated_linear'], 85.0)
        self.assertLessEqual(r_info['spo2_estimated_linear'], 100.0)
        
    def test_classical_pulse_oximeter(self):
        oximeter = ClassicalPulseOximeter(sampling_rate=100.0)
        t = np.linspace(0, 4.0, 400)
        pulse = np.sin(2 * np.pi * 1.0 * t) # 60 BPM
        red = 58000.0 + 800.0 * pulse
        ir = 63000.0 + 1200.0 * pulse
        
        res = oximeter.calculate_spo2(red, ir)
        self.assertEqual(res['status'], 'SUCCESS')
        self.assertIsNotNone(res['spo2'])
        self.assertIsNotNone(res['heart_rate_bpm'])
        self.assertAlmostEqual(res['heart_rate_bpm'], 60.0, delta=5.0)

    def test_feature_extractor_completeness(self):
        extractor = PPGFeatureExtractor(sampling_rate=100.0)
        t = np.linspace(0, 4.0, 400)
        sig = np.sin(2 * np.pi * 1.2 * t) + 0.5
        
        stat = extractor.extract_statistical_features(sig, prefix='test')
        morph = extractor.extract_morphology_features(sig, prefix='test')
        freq = extractor.extract_frequency_features(sig, prefix='test')
        
        self.assertIn('test_mean', stat)
        self.assertIn('test_pulse_rate_bpm', morph)
        self.assertIn('test_spectral_entropy', freq)

if __name__ == '__main__':
    unittest.main()
