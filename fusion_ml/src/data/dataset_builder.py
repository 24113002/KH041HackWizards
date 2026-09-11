"""
SwasthAI Fusion ML - Multimodal Dataset Builder
Merges outputs from SpO2, Air-Pressure, Sound CNN, and COPD Questionnaire across cohorts.
"""

import os
import json
import numpy as np
import pandas as pd

def generate_multimodal_dataset(output_csv: str = "fusion_ml/data/multimodal_fusion_dataset.csv", n_samples: int = 500) -> pd.DataFrame:
    np.random.seed(42)
    records = []

    # Generate 50 unique patient profiles across 3 clinical risk strata
    # 20 Lower Risk, 18 Moderate Risk, 12 Higher Risk subjects with multiple sessions
    n_subjects = 50
    subject_ids = np.arange(1, n_subjects + 1)
    
    # Assign true subject clinical category (0: Lower, 1: Moderate, 2: Higher)
    subject_classes = {}
    for sid in subject_ids:
        if sid <= 22:
            subject_classes[sid] = 0  # Lower Risk (Healthy / Mild)
        elif sid <= 38:
            subject_classes[sid] = 1  # Moderate Risk (Early / Exposed)
        else:
            subject_classes[sid] = 2  # Higher Risk (Obstructed / Hypoxemic)

    for i in range(n_samples):
        sid = int(np.random.choice(subject_ids))
        cls = subject_classes[sid]

        # 1. SpO2 Modality (Simulate realistic pulse oximetry based on class)
        # 5% chance of detached / missing sensor
        spo2_missing = 1 if np.random.rand() < 0.05 else 0
        if not spo2_missing:
            if cls == 0:
                spo2_val = float(np.clip(np.random.normal(98.4, 0.8), 96.0, 100.0))
                spo2_prob = float(np.clip(np.random.beta(1.5, 8.0), 0.02, 0.25))
            elif cls == 1:
                spo2_val = float(np.clip(np.random.normal(95.2, 1.2), 92.0, 97.5))
                spo2_prob = float(np.clip(np.random.beta(4.0, 4.0), 0.25, 0.70))
            else:
                spo2_val = float(np.clip(np.random.normal(91.5, 1.8), 82.0, 94.0))
                spo2_prob = float(np.clip(np.random.beta(7.0, 2.0), 0.65, 0.98))

            spo2_r = round(float((110.0 - spo2_val) / 25.0), 4)
            spo2_hr = round(float(np.random.normal(72.0 + cls * 6.0, 7.0)), 1)
            desat_risk = float(np.clip((100.0 - spo2_val) / 20.0 * 100.0, 0.0, 100.0))
            spo2_risk = round(0.65 * desat_risk + 0.35 * (spo2_prob * 100.0), 2)
            spo2_q = round(float(np.clip(np.random.normal(0.92, 0.06), 0.6, 1.0)), 2)
        else:
            spo2_val, spo2_r, spo2_hr, spo2_prob, spo2_risk, spo2_q = np.nan, np.nan, np.nan, np.nan, np.nan, 0.0

        # 2. Air-Pressure Modality
        pressure_missing = 1 if np.random.rand() < 0.04 else 0
        if not pressure_missing:
            if cls == 0:
                peak_p = float(np.clip(np.random.normal(11.5, 2.0), 6.0, 15.0))
                blow_dur = float(np.clip(np.random.normal(1.1, 0.15), 0.8, 1.5))
            elif cls == 1:
                peak_p = float(np.clip(np.random.normal(22.8, 3.5), 15.5, 29.0))
                blow_dur = float(np.clip(np.random.normal(1.35, 0.2), 1.0, 1.8))
            else:
                peak_p = float(np.clip(np.random.normal(36.5, 5.0), 28.0, 52.0))
                blow_dur = float(np.clip(np.random.normal(1.7, 0.3), 1.2, 2.5))

            peak_delta = round(float(peak_p * 8500.0 + np.random.normal(0, 1500)), 1)
            p_risk = round(float(np.clip(peak_p / 45.0 * 100.0, 0.0, 100.0)), 2)
            p_q = round(float(np.clip(np.random.normal(0.95, 0.04), 0.7, 1.0)), 2)
        else:
            peak_p, peak_delta, blow_dur, p_risk, p_q = np.nan, np.nan, np.nan, np.nan, 0.0

        # 3. Sound CNN Modality
        sound_missing = 1 if np.random.rand() < 0.06 else 0
        if not sound_missing:
            if cls == 0:
                abn_prob = float(np.clip(np.random.beta(1.2, 8.0), 0.01, 0.20))
            elif cls == 1:
                abn_prob = float(np.clip(np.random.beta(3.5, 3.5), 0.25, 0.68))
            else:
                abn_prob = float(np.clip(np.random.beta(7.5, 1.8), 0.65, 0.99))

            sound_risk = round(abn_prob * 100.0, 2)
            sound_conf = round(float(max(abn_prob, 1.0 - abn_prob)), 2)
        else:
            abn_prob, sound_risk, sound_conf = np.nan, np.nan, np.nan

        # 4. COPD Questionnaire Modality
        quest_missing = 1 if np.random.rand() < 0.02 else 0
        if not quest_missing:
            if cls == 0:
                age = int(np.random.randint(20, 48))
                pack_years = float(np.random.choice([0.0, 0.0, 0.0, 2.0, 5.0]))
                biomass = int(np.random.choice([0, 0, 0, 1]))
                dyspnea = int(np.random.choice([0, 0, 1]))
                cough = int(np.random.choice([0, 0, 1]))
                phlegm = 0
                wheeze = 0
                q_score = float(np.clip(np.random.randint(0, 4), 0, 3))
            elif cls == 1:
                age = int(np.random.randint(45, 68))
                pack_years = float(np.random.choice([5.0, 10.0, 15.0, 20.0]))
                biomass = int(np.random.choice([0, 1, 1]))
                dyspnea = int(np.random.choice([1, 1, 0]))
                cough = int(np.random.choice([1, 1, 0]))
                phlegm = int(np.random.choice([0, 1]))
                wheeze = int(np.random.choice([0, 1]))
                q_score = float(np.clip(np.random.randint(4, 7), 4, 6))
            else:
                age = int(np.random.randint(52, 78))
                pack_years = float(np.random.choice([15.0, 25.0, 35.0, 45.0]))
                biomass = int(np.random.choice([1, 1, 0]))
                dyspnea = 1
                cough = 1
                phlegm = int(np.random.choice([1, 1, 0]))
                wheeze = int(np.random.choice([1, 1, 0]))
                q_score = float(np.clip(np.random.randint(7, 11), 7, 10))

            q_risk = round(float(np.clip(q_score / 10.0 * 100.0, 0.0, 100.0)), 2)
        else:
            age, pack_years, biomass, dyspnea, cough, phlegm, wheeze, q_score, q_risk = (
                np.nan, np.nan, 0, 0, 0, 0, 0, np.nan, np.nan
            )

        # Completeness & Modality Count
        valid_mods = int((1 - spo2_missing) + (1 - pressure_missing) + (1 - sound_missing) + (1 - quest_missing))
        comp_ratio = round(valid_mods / 4.0, 2)

        # Composite ground truth risk score (0-100)
        valid_risks = [r for r in [spo2_risk, p_risk, sound_risk, q_risk] if not np.isnan(r)]
        composite_score = round(float(np.mean(valid_risks)), 2) if len(valid_risks) > 0 else 0.0

        records.append({
            'subject_id': sid,
            'session_id': i + 1,
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
            'screening_completeness_ratio': comp_ratio,
            'composite_risk_score': composite_score,
            'risk_category': cls  # 0: Lower, 1: Moderate, 2: Higher
        })

    df = pd.DataFrame(records)
    os.makedirs(os.path.dirname(output_csv), exist_ok=True)
    df.to_csv(output_csv, index=False)
    print(f"Generated multimodal dataset: {df.shape[0]} sessions across {df['subject_id'].nunique()} subjects saved to {output_csv}")
    return df

if __name__ == "__main__":
    generate_multimodal_dataset()
