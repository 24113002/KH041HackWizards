"""
SwasthAI SpO2 & PPG ML - End-to-End Feature Extraction Pipeline
Combines signal quality, preprocessing, AC/DC, morphology, and frequency extractors.
"""

import numpy as np
import pandas as pd
from ..preprocessing.signal_quality import SignalQualityChecker
from ..preprocessing.ppg_preprocessing import PPGPreprocessor
from .ac_dc_extractor import ACDCExtractor
from .ppg_features import PPGFeatureExtractor

class PPGFeaturePipeline:
    def __init__(self, sampling_rate: float = 100.0):
        self.sampling_rate = sampling_rate
        self.quality_checker = SignalQualityChecker()
        self.preprocessor = PPGPreprocessor(sampling_rate=sampling_rate)
        self.ac_dc_extractor = ACDCExtractor(sampling_rate=sampling_rate)
        self.feature_extractor = PPGFeatureExtractor(sampling_rate=sampling_rate)

    def extract_from_raw_pair(self, red: np.ndarray, ir: np.ndarray) -> dict:
        """
        Processes raw RED & IR signals (e.g. from MAX30102 or dataset window) and extracts structured features.
        """
        # 1. Quality Check
        q_red = self.quality_checker.check_quality(red, self.sampling_rate)
        q_ir = self.quality_checker.check_quality(ir, self.sampling_rate)
        
        is_valid = q_red['is_valid'] and q_ir['is_valid']
        if not is_valid:
            rejection = q_red['rejection_reason'] or q_ir['rejection_reason']
            return {
                'is_valid': False,
                'signal_quality': 'INVALID',
                'rejection_reason': rejection,
                'features': None
            }
            
        # 2. Preprocessing & AC/DC Separation
        prep_data = self.preprocessor.preprocess_pair(red, ir)
        
        red_ac_dc = self.ac_dc_extractor.compute_ac_dc(prep_data['red_raw'], prep_data['red_ac'])
        ir_ac_dc = self.ac_dc_extractor.compute_ac_dc(prep_data['ir_raw'], prep_data['ir_ac'])
        r_info = self.ac_dc_extractor.compute_r_ratio(red_ac_dc, ir_ac_dc)
        
        # 3. Statistical Features
        stat_red = self.feature_extractor.extract_statistical_features(prep_data['red_raw'], prefix='red')
        stat_ir = self.feature_extractor.extract_statistical_features(prep_data['ir_raw'], prefix='ir')
        
        # 4. Morphology & Peak Features
        morph_red = self.feature_extractor.extract_morphology_features(prep_data['red_ac'], prefix='red')
        morph_ir = self.feature_extractor.extract_morphology_features(prep_data['ir_ac'], prefix='ir')
        
        # 5. Frequency Features
        freq_red = self.feature_extractor.extract_frequency_features(prep_data['red_ac'], prefix='red')
        freq_ir = self.feature_extractor.extract_frequency_features(prep_data['ir_ac'], prefix='ir')
        
        # 6. Relational Features
        rel_feats = self.feature_extractor.extract_relational_features(prep_data['red_raw'], prep_data['ir_raw'])
        
        # Combine all features into flat dictionary
        features = {}
        features.update(stat_red)
        features.update(stat_ir)
        features.update(morph_red)
        features.update(morph_ir)
        features.update(freq_red)
        features.update(freq_ir)
        features.update(rel_feats)
        
        features['ac_red'] = red_ac_dc['ac']
        features['dc_red'] = red_ac_dc['dc']
        features['ac_dc_red'] = red_ac_dc['ac_dc_ratio']
        
        features['ac_ir'] = ir_ac_dc['ac']
        features['dc_ir'] = ir_ac_dc['dc']
        features['ac_dc_ir'] = ir_ac_dc['ac_dc_ratio']
        
        features['r_ratio'] = r_info['r_ratio'] if not np.isnan(r_info['r_ratio']) else 1.0
        features['spo2_classical_est'] = r_info['spo2_estimated_linear'] if not np.isnan(r_info['spo2_estimated_linear']) else 95.0
        
        features['signal_quality_score'] = (q_red['quality_score'] + q_ir['quality_score']) / 2.0
        features['saturation_pct'] = max(q_red['saturation_pct'], q_ir['saturation_pct'])
        
        # Clean NaNs or Infs
        for k, v in features.items():
            if np.isnan(v) or np.isinf(v):
                features[k] = 0.0
                
        return {
            'is_valid': True,
            'signal_quality': 'GOOD' if features['signal_quality_score'] >= 0.75 else 'ACCEPTABLE',
            'rejection_reason': None,
            'features': features,
            'r_ratio_info': r_info
        }

    def extract_from_window_row(self, row_values: np.ndarray) -> dict:
        """
        Processes a single normalized 256-point time-series window from the Zenodo dataset.
        Generates robust statistical, morphological, and spectral features.
        """
        row_values = np.asarray(row_values, dtype=np.float64)
        stat_feats = self.feature_extractor.extract_statistical_features(row_values, prefix='ppg')
        morph_feats = self.feature_extractor.extract_morphology_features(row_values, prefix='ppg')
        freq_feats = self.feature_extractor.extract_frequency_features(row_values, prefix='ppg')
        
        feats = {}
        feats.update(stat_feats)
        feats.update(morph_feats)
        feats.update(freq_feats)
        
        # AC approximation from peak-to-peak and variance
        feats['ppg_ac_approx'] = float(np.std(row_values))
        feats['ppg_dc_approx'] = float(np.mean(row_values))
        
        for k, v in feats.items():
            if np.isnan(v) or np.isinf(v):
                feats[k] = 0.0
                
        return feats
