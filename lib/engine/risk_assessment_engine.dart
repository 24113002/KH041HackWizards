import '../models/patient_model.dart';
import '../models/sensor_data_model.dart';
import '../models/questionnaire_model.dart';
import '../models/screening_result_model.dart';

class RiskAssessmentEngine {
  /// Evaluates multi-modal data and outputs an offline comprehensive screening result.
  static RiskResult evaluate({
    required Patient patient,
    required VitalsReading vitals,
    required SpirometrySummary spirometry,
    required AcousticSummary acoustic,
    required QuestionnaireResponse questionnaire,
  }) {
    final findings = <ClinicalFinding>[];
    final recommendations = <String>[];
    int score = 0;
    bool emergencyFlag = false;

    // 1. Predicted Reference Values
    final predFev1 = patient.predictedFev1;
    final predFvc = patient.predictedFvc;
    final predPef = patient.predictedPef;

    final fev1PctPred = predFev1 > 0 ? (spirometry.fev1 / predFev1) * 100.0 : 0.0;
    final fvcPctPred = predFvc > 0 ? (spirometry.fvc / predFvc) * 100.0 : 0.0;
    final pefPctPred = predPef > 0 ? (spirometry.pefLpm / predPef) * 100.0 : 0.0;

    // 2. Vitals Analysis (SpO2 & Heart Rate)
    final spo2 = vitals.spo2;
    final hr = vitals.heartRate;

    if (spo2 > 0) {
      if (spo2 < 88) {
        score += 30;
        emergencyFlag = true;
        findings.add(ClinicalFinding(
          title: 'Critical Hypoxemia (SpO2: $spo2%)',
          details: 'Severe arterial oxygen desaturation below 88% requires urgent medical evaluation and oxygen support.',
          isAbnormal: true,
          isUrgent: true,
        ));
        recommendations.add('URGENT: Administer supplemental oxygen and transfer to nearest acute healthcare facility.');
      } else if (spo2 < 93) {
        score += 18;
        findings.add(ClinicalFinding(
          title: 'Moderate Hypoxemia (SpO2: $spo2%)',
          details: 'Subnormal oxygen saturation (90-92%) indicating impaired alveolar gas exchange.',
          isAbnormal: true,
        ));
        recommendations.add('Monitor oxygen saturation closely. Perform physician workup for respiratory or cardiac cause.');
      } else if (spo2 < 95) {
        score += 8;
        findings.add(ClinicalFinding(
          title: 'Borderline Low SpO2 ($spo2%)',
          details: 'Mildly reduced oxygen level, common in early respiratory compromise or altitude.',
          isAbnormal: true,
        ));
      } else {
        findings.add(ClinicalFinding(
          title: 'Normal Oxygen Saturation ($spo2%)',
          details: 'Resting pulse oximetry within normal healthy limits (≥95%).',
          isAbnormal: false,
        ));
      }
    }

    if (hr > 0) {
      if (hr > 120) {
        score += 15;
        findings.add(ClinicalFinding(
          title: 'Severe Tachycardia ($hr bpm)',
          details: 'Resting pulse >120 bpm may indicate respiratory exhaustion, infection, or cardiac arrhythmia.',
          isAbnormal: true,
          isUrgent: true,
        ));
        recommendations.add('Perform a 12-lead ECG and assess for compensatory tachycardia or arrhythmia.');
      } else if (hr > 100) {
        score += 8;
        findings.add(ClinicalFinding(
          title: 'Elevated Heart Rate ($hr bpm)',
          details: 'Resting pulse exceeds normal upper limit (60-100 bpm).',
          isAbnormal: true,
        ));
      } else if (hr < 50) {
        score += 8;
        findings.add(ClinicalFinding(
          title: 'Bradycardia ($hr bpm)',
          details: 'Resting heart rate below 50 bpm (unless trained endurance athlete).',
          isAbnormal: true,
        ));
      } else {
        findings.add(ClinicalFinding(
          title: 'Normal Heart Rate ($hr bpm)',
          details: 'Resting rhythm within normal limits (60-100 bpm).',
          isAbnormal: false,
        ));
      }
    }

    // 3. Spirometry & Airflow Analysis (GOLD & ATS/ERS guidelines)
    bool hasObstruction = false;
    bool hasRestriction = false;

    if (spirometry.fvc > 0.2) {
      final ratio = spirometry.fev1FvcRatio > 0
          ? spirometry.fev1FvcRatio
          : (spirometry.fev1 / spirometry.fvc);

      // GOLD criterion: Post-bronchodilator or screening FEV1/FVC < 0.70 indicates airflow limitation
      if (ratio < 0.70) {
        hasObstruction = true;
        if (ratio < 0.55 || fev1PctPred < 50) {
          score += 30;
          findings.add(ClinicalFinding(
            title: 'Severe Airflow Obstruction (FEV1/FVC: ${(ratio * 100).toStringAsFixed(1)}%)',
            details: 'FEV1/FVC ratio is markedly below 0.70 with FEV1 at ${fev1PctPred.toStringAsFixed(0)}% of predicted. Strong indicator of moderate-to-severe COPD or poorly controlled Asthma.',
            isAbnormal: true,
            isUrgent: true,
          ));
          recommendations.add('Schedule urgent Pulmonologist referral for formal diagnostic spirometry with pre/post bronchodilator reversibility testing.');
        } else {
          score += 20;
          findings.add(ClinicalFinding(
            title: 'Airflow Obstruction Detected (FEV1/FVC: ${(ratio * 100).toStringAsFixed(1)}%)',
            details: 'FEV1/FVC ratio < 70% suggests presence of obstructive airway disease (Asthma or COPD).',
            isAbnormal: true,
          ));
          recommendations.add('Evaluate for inhaled bronchodilator (SABA/LABA) therapy and formal clinical spirometry.');
        }
      } else if (fvcPctPred < 80 && fev1PctPred < 80) {
        hasRestriction = true;
        score += 15;
        findings.add(ClinicalFinding(
          title: 'Possible Restrictive Ventilatory Defect',
          details: 'Normal FEV1/FVC ratio with reduced FVC (${fvcPctPred.toStringAsFixed(0)}% predicted) suggests restrictive chest wall or parenchymal lung involvement.',
          isAbnormal: true,
        ));
        recommendations.add('Consider chest imaging (CXR or high-resolution CT) and plethysmography for total lung capacity.');
      } else {
        findings.add(ClinicalFinding(
          title: 'Normal Spirometry Airflow Indices',
          details: 'FEV1/FVC ratio (${(ratio * 100).toStringAsFixed(1)}%) and lung volumes are within normal predicted ranges.',
          isAbnormal: false,
        ));
      }

      // PEF Analysis
      if (pefPctPred > 0 && pefPctPred < 60) {
        score += 10;
        findings.add(ClinicalFinding(
          title: 'Low Peak Expiratory Flow (${pefPctPred.toStringAsFixed(0)}% predicted)',
          details: 'Peak flow of ${spirometry.pefLpm.toStringAsFixed(0)} L/min is significantly depressed.',
          isAbnormal: true,
        ));
      }
    }

    // 4. Acoustic & Auscultation Analysis
    if (acoustic.coughCount > 0) {
      final pts = (acoustic.coughCount >= 3) ? 8 : 4;
      score += pts;
      findings.add(ClinicalFinding(
        title: 'Cough Events Detected (${acoustic.coughCount} during test)',
        details: 'Frequent acoustic cough bursts indicate bronchial irritability or excessive tracheobronchial secretions.',
        isAbnormal: true,
      ));
    }
    if (acoustic.wheezeDetected) {
      score += 10;
      findings.add(ClinicalFinding(
        title: 'High-Pitched Acoustic Wheeze Detected',
        details: 'Musical adventitious breath sound typical of turbulent airflow in narrowed airways.',
        isAbnormal: true,
      ));
      recommendations.add('Auscultate lung fields for expiratory wheezing, polyphonic rhonchi, or prolonged expiratory phase.');
    }

    // 5. Clinical Questionnaire Scoring
    final sympScore = questionnaire.symptomScore;
    if (sympScore > 14) {
      score += 20;
      findings.add(ClinicalFinding(
        title: 'High Symptom Burden (Score: $sympScore/30)',
        details: 'Significant dyspnea on exertion (mMRC ${questionnaire.mmrcDyspneaGrade}), frequent respiratory symptoms and comorbidity risk.',
        isAbnormal: true,
      ));
    } else if (sympScore >= 7) {
      score += 10;
      findings.add(ClinicalFinding(
        title: 'Moderate Symptom Burden (Score: $sympScore/30)',
        details: 'Frequent cough, sputum, or mild exertion dyspnea reported.',
        isAbnormal: true,
      ));
    }

    // Risk Factor Flags (Smoking & Biomass)
    if (questionnaire.smokingStatus == 2) {
      recommendations.add('Strongly advise smoking cessation counseling and consider pharmacological nicotine replacement support.');
    }
    if (questionnaire.biomassExposure >= 2) {
      recommendations.add('Advise minimization of indoor biomass/chulha smoke exposure with improved home ventilation.');
    }

    // 6. Deduce Clinical Pattern
    ClinicalPattern pattern = ClinicalPattern.normal;
    if (emergencyFlag || (spo2 > 0 && spo2 < 90)) {
      pattern = ClinicalPattern.acuteHypoxemia;
    } else if (hasObstruction) {
      if (hr > 105 || questionnaire.hasHeartDisease) {
        pattern = ClinicalPattern.mixedCardiorespiratory;
      } else {
        pattern = ClinicalPattern.obstructiveAirway;
      }
    } else if (hasRestriction) {
      pattern = ClinicalPattern.restrictivePattern;
    } else if (hr > 105 || questionnaire.chestDiscomfort >= 2) {
      pattern = ClinicalPattern.cardiovascularStrain;
      recommendations.add('Evaluate for cardiovascular etiology including coronary artery disease or heart failure.');
    } else if (score >= 35) {
      pattern = ClinicalPattern.mixedCardiorespiratory;
    } else {
      pattern = ClinicalPattern.normal;
    }

    // Ensure general advice if normal
    if (recommendations.isEmpty) {
      recommendations.add('Cardiopulmonary screening is normal. Maintain active lifestyle, regular exercise, and smoke-free environment.');
      recommendations.add('Repeat routine preventive health screening annually.');
    }

    // Determine Risk Level
    final normalizedScore = score.clamp(0, 100);
    RiskLevel riskLevel;
    if (emergencyFlag || normalizedScore >= 60) {
      riskLevel = emergencyFlag ? RiskLevel.critical : RiskLevel.high;
    } else if (normalizedScore >= 35) {
      riskLevel = RiskLevel.high;
    } else if (normalizedScore >= 18) {
      riskLevel = RiskLevel.moderate;
    } else {
      riskLevel = RiskLevel.low;
    }

    return RiskResult(
      overallScore: normalizedScore,
      riskLevel: riskLevel,
      clinicalPattern: pattern,
      findings: findings,
      recommendations: recommendations,
      emergencyFlag: emergencyFlag,
      heartRate: hr,
      spo2: spo2,
      fev1: spirometry.fev1,
      fvc: spirometry.fvc,
      fev1FvcRatio: spirometry.fev1FvcRatio,
      pefLpm: spirometry.pefLpm,
      fev1PercentPredicted: fev1PctPred,
      fvcPercentPredicted: fvcPctPred,
      pefPercentPredicted: pefPctPred,
      coughCount: acoustic.coughCount,
      symptomScore: sympScore,
    );
  }
}
