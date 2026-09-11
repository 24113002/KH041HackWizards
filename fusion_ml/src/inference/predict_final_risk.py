"""
SwasthAI Fusion ML - Standalone Multi-Modal Risk Inference Engine
Accepts structured outputs from SpO2, Air-Pressure, Sound CNN, and Questionnaire.
"""

import os
import json
import numpy as np
from ..models.fusion_model import SwasthAIFusionModel

class SwasthAIRiskEngine:
    def __init__(
        self,
        model_path: str = "fusion_ml/models/fusion_xgboost_model.json",
        config_path: str = "fusion_ml/models/fusion_feature_columns.json"
    ):
        self.feature_names = []
        if os.path.exists(config_path):
            with open(config_path, "r") as f:
                cfg = json.load(f)
                self.feature_names = cfg.get("feature_names", [])

        self.model = SwasthAIFusionModel()
        if os.path.exists(model_path):
            self.model.load_model(model_path)
            self.model.feature_names = self.feature_names

    def predict_final_risk(
        self,
        spo2_result: dict = None,
        pressure_result: dict = None,
        sound_result: dict = None,
        questionnaire_result: dict = None
    ) -> dict:
        """
        Calculates unified screening risk category, 0-100 composite score, and explainable factors.
        """
        contributing_factors = []
        valid_mods = 0

        # 1. Parse SpO2 Modality
        spo2_missing = 1
        spo2_val, spo2_r, spo2_hr, spo2_prob, spo2_risk, spo2_q = np.nan, np.nan, np.nan, np.nan, np.nan, 0.0
        if spo2_result and spo2_result.get('status') == 'SUCCESS' and spo2_result.get('spo2_classical_estimate') is not None:
            spo2_missing = 0
            valid_mods += 1
            spo2_val = float(spo2_result.get('spo2_classical_estimate', 98.0))
            spo2_r = float(spo2_result.get('r_ratio', 0.50))
            spo2_hr = float(spo2_result.get('heart_rate_bpm', 72.0)) if spo2_result.get('heart_rate_bpm') is not None else np.nan
            spo2_prob = float(spo2_result.get('pathology_risk_probability', 0.10)) if spo2_result.get('pathology_risk_probability') is not None else 0.10
            spo2_q = float(spo2_result.get('quality_score', 1.0))

            # 0-100 SpO2 Risk Score
            desat = float(np.clip((100.0 - spo2_val) / 20.0 * 100.0, 0.0, 100.0))
            spo2_risk = round(0.65 * desat + 0.35 * (spo2_prob * 100.0), 2)

            if spo2_val < 95.0:
                contributing_factors.append(f"Reduced oxygen saturation detected ({spo2_val:.1f}% SpO₂)")
            if spo2_prob > 0.5:
                contributing_factors.append(f"PPG waveform morphology indicates vascular/respiratory alteration ({spo2_prob*100:.0f}% probability)")

        # 2. Parse Air-Pressure Modality
        pressure_missing = 1
        peak_p, peak_delta, blow_dur, p_risk, p_q = np.nan, np.nan, np.nan, np.nan, 0.0
        if pressure_result and pressure_result.get('status') == 'SUCCESS' and pressure_result.get('estimated_peak_pressure_cmh2o') is not None:
            pressure_missing = 0
            valid_mods += 1
            peak_p = float(pressure_result.get('estimated_peak_pressure_cmh2o', 12.0))
            peak_delta = float(pressure_result.get('peak_delta', 100000.0))
            blow_dur = float(pressure_result.get('blow_duration_sec', 1.2))
            p_q = float(pressure_result.get('signal_quality_score', 1.0))
            p_risk = round(float(np.clip(peak_p / 45.0 * 100.0, 0.0, 100.0)), 2)

            if peak_p >= 25.0:
                contributing_factors.append(f"Elevated expiratory airway resistance ({peak_p:.1f} cmH₂O peak pressure)")
            elif peak_p >= 18.0:
                contributing_factors.append(f"Mildly increased airway pressure excursion ({peak_p:.1f} cmH₂O)")

        # 3. Parse Sound CNN Modality
        sound_missing = 1
        abn_prob, sound_risk, sound_conf = np.nan, np.nan, np.nan
        if sound_result and sound_result.get('status') in ['success', 'SUCCESS'] and sound_result.get('probabilities') is not None:
            sound_missing = 0
            valid_mods += 1
            probs = sound_result.get('probabilities', {})
            abn_prob = float(probs.get('pathological_adventitious', 0.10))
            sound_risk = round(abn_prob * 100.0, 2)
            sound_conf = float(sound_result.get('confidence', 0.85))

            if abn_prob > 0.50:
                contributing_factors.append(f"Acoustic lung-sound analysis detected adventitious/wheezing sounds ({abn_prob*100:.0f}% confidence)")

        # 4. Parse Questionnaire Modality
        quest_missing = 1
        age, pack_years, biomass, dyspnea, cough, phlegm, wheeze, q_score, q_risk = (
            np.nan, np.nan, 0, 0, 0, 0, 0, np.nan, np.nan
        )
        if questionnaire_result is not None:
            quest_missing = 0
            valid_mods += 1
            age = float(questionnaire_result.get('age', 45))
            years_smoked = float(questionnaire_result.get('years_smoked', 0) or 0)
            cigs = float(questionnaire_result.get('cigarettes_per_day', 0) or 0)
            pack_years = (years_smoked * cigs) / 20.0
            biomass = 1 if questionnaire_result.get('biomass_exposure') else 0
            dyspnea = 1 if questionnaire_result.get('breathlessness') else 0
            cough = 1 if questionnaire_result.get('chronic_cough') else 0
            phlegm = 1 if questionnaire_result.get('phlegm') else 0
            wheeze = 1 if questionnaire_result.get('wheezing') else 0

            # Compute clinical score
            raw_score = 0
            if age >= 60: raw_score += 3
            elif age >= 50: raw_score += 2
            elif age >= 40: raw_score += 1

            if pack_years >= 20: raw_score += 2
            elif pack_years >= 10: raw_score += 1

            if biomass: raw_score += 2
            if dyspnea: raw_score += 2
            if cough: raw_score += 2
            if phlegm: raw_score += 1
            if wheeze: raw_score += 1

            q_score = float(min(10, raw_score))
            q_risk = round(float(q_score / 10.0 * 100.0), 2)

            if q_score >= 6:
                contributing_factors.append(f"High-risk clinical profile on respiratory questionnaire ({q_score:.0f}/10 COPD-PS score)")
            elif q_score >= 4:
                contributing_factors.append(f"Moderate clinical risk factors identified (dyspnea/exposure history)")

        # Incomplete / Invalid Screening Check
        if valid_mods == 0:
            return {
                'status': 'INVALID',
                'risk_category': 'INVALID',
                'composite_risk_score': None,
                'model_confidence': None,
                'valid_modalities_count': 0,
                'screening_status': 'INVALID',
                'modality_risk_scores': {},
                'contributing_factors': ['No valid sensor or questionnaire modalities received.'],
                'recommendation': 'Screening invalid. Please re-administer sensor tests.',
                'clinical_disclaimer': 'Screening support estimation only. Not a diagnostic confirmation.'
            }

        # 5. Build Feature Vector for XGBoost Late Fusion
        feat_dict = {
            'spo2_value': spo2_val,
            'spo2_r_ratio': spo2_r,
            'spo2_heart_rate': spo2_hr,
            'spo2_pathology_prob': spo2_prob,
            'spo2_risk_score': spo2_risk,
            'spo2_quality_score': spo2_q,
            'spo2_is_missing': spo2_missing,

            'pressure_peak_cmh2o': peak_p,
            'pressure_peak_delta': peak_delta,
            'pressure_blow_duration': blow_dur,
            'pressure_risk_score': p_risk,
            'pressure_quality_score': p_q,
            'pressure_is_missing': pressure_missing,

            'sound_abnormal_prob': abn_prob,
            'sound_risk_score': sound_risk,
            'sound_confidence': sound_conf,
            'sound_is_missing': sound_missing,

            'questionnaire_score': q_score,
            'questionnaire_risk_score': q_risk,
            'patient_age': age,
            'smoking_pack_years': pack_years,
            'biomass_exposure': biomass,
            'breathlessness': dyspnea,
            'chronic_cough': cough,
            'phlegm': phlegm,
            'wheezing': wheeze,
            'questionnaire_is_missing': quest_missing,

            'valid_modalities_count': valid_mods,
            'screening_completeness_ratio': round(valid_mods / 4.0, 2)
        }

        x_vec = np.zeros((1, len(self.feature_names)))
        for i, fname in enumerate(self.feature_names):
            x_vec[0, i] = feat_dict.get(fname, np.nan)

        probs = self.model.predict_proba(x_vec)[0]
        pred_class_idx = int(np.argmax(probs))
        confidence = float(probs[pred_class_idx])

        # Composite Continuous Score (Weighted blend of model probability distribution & sensor risks)
        risk_weights = [0.0, 50.0, 100.0]
        prob_composite = float(np.sum(probs * risk_weights))

        valid_risks = [r for r in [spo2_risk, p_risk, sound_risk, q_risk] if not np.isnan(r)]
        sensor_avg_risk = float(np.mean(valid_risks)) if len(valid_risks) > 0 else prob_composite
        final_composite_score = round(0.50 * prob_composite + 0.50 * sensor_avg_risk, 2)

        # Map to Approved Category
        if pred_class_idx == 0:
            category = "LOWER_RISK"
            rec = "Routine health screening. No acute pulmonary intervention required at this time."
        elif pred_class_idx == 1:
            category = "MODERATE_RISK"
            rec = "Primary care follow-up recommended. Consider preventive counseling, smoking/biomass cessation, and spirometry."
        else:
            category = "HIGHER_RISK"
            rec = "Clinical evaluation recommended. Refer patient to Community Health Center (CHC) / Hospital for diagnostic spirometry."

        status_str = "COMPLETE" if valid_mods == 4 else "PARTIAL"

        return {
            'status': 'SUCCESS',
            'risk_category': category,
            'composite_risk_score': final_composite_score,
            'model_confidence': round(confidence, 4),
            'class_probabilities': {
                'lower_risk': round(float(probs[0]), 4),
                'moderate_risk': round(float(probs[1]), 4),
                'higher_risk': round(float(probs[2]), 4)
            },
            'valid_modalities_count': valid_mods,
            'screening_status': status_str,
            'modality_risk_scores': {
                'spo2_risk': spo2_risk if not np.isnan(spo2_risk) else None,
                'pressure_risk': p_risk if not np.isnan(p_risk) else None,
                'sound_risk': sound_risk if not np.isnan(sound_risk) else None,
                'questionnaire_risk': q_risk if not np.isnan(q_risk) else None
            },
            'contributing_factors': contributing_factors if len(contributing_factors) > 0 else ["No significant abnormal respiratory factors detected."],
            'recommendation': rec,
            'model_version': 'SwasthAI_Fusion_XGB_v1',
            'clinical_disclaimer': 'Rural screening-support decision engine. Not a diagnostic confirmation of COPD.'
        }
