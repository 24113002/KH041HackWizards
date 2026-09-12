enum RiskLevel {
  low,
  moderate,
  high,
  critical,
}

extension RiskLevelExtension on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'Low Risk / Normal';
      case RiskLevel.moderate:
        return 'Moderate Risk';
      case RiskLevel.high:
        return 'High Risk';
      case RiskLevel.critical:
        return 'Critical / Urgent Referral';
    }
  }

  String get shortLabel {
    switch (this) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.moderate:
        return 'Moderate';
      case RiskLevel.high:
        return 'High';
      case RiskLevel.critical:
        return 'Critical';
    }
  }
}

enum ClinicalPattern {
  normal,
  obstructiveAirway, // Typical for Asthma or COPD
  restrictivePattern, // Reduced lung volumes with normal ratio
  acuteHypoxemia, // Low SpO2, respiratory distress
  cardiovascularStrain, // Tachycardia/irregular HR with chest tightness
  mixedCardiorespiratory, // Combined airflow & cardiovascular flags
}

extension ClinicalPatternExtension on ClinicalPattern {
  String get displayName {
    switch (this) {
      case ClinicalPattern.normal:
        return 'Normal Cardiopulmonary Function';
      case ClinicalPattern.obstructiveAirway:
        return 'Obstructive Airway Pattern (Asthma/COPD suspected)';
      case ClinicalPattern.restrictivePattern:
        return 'Possible Restrictive Lung Pattern';
      case ClinicalPattern.acuteHypoxemia:
        return 'Acute Hypoxemic Respiratory Distress';
      case ClinicalPattern.cardiovascularStrain:
        return 'Cardiovascular Strain / Arrhythmia Alert';
      case ClinicalPattern.mixedCardiorespiratory:
        return 'Mixed Cardiorespiratory Risk Profile';
    }
  }
}

class ClinicalFinding {
  final String title;
  final String details;
  final bool isAbnormal;
  final bool isUrgent;

  const ClinicalFinding({
    required this.title,
    required this.details,
    this.isAbnormal = false,
    this.isUrgent = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'details': details,
      'is_abnormal': isAbnormal ? 1 : 0,
      'is_urgent': isUrgent ? 1 : 0,
    };
  }

  factory ClinicalFinding.fromMap(Map<String, dynamic> map) {
    return ClinicalFinding(
      title: map['title'] as String,
      details: map['details'] as String,
      isAbnormal: (map['is_abnormal'] as num?)?.toInt() == 1,
      isUrgent: (map['is_urgent'] as num?)?.toInt() == 1,
    );
  }
}

class RiskResult {
  final int overallScore; // 0 (healthy) to 100 (critical)
  final RiskLevel riskLevel;
  final ClinicalPattern clinicalPattern;
  final List<ClinicalFinding> findings;
  final List<String> recommendations;
  final bool emergencyFlag;

  // Key quantified metrics for quick reference
  final int heartRate;
  final int spo2;
  final double fev1;
  final double fvc;
  final double fev1FvcRatio;
  final double pefLpm;
  final double fev1PercentPredicted;
  final double fvcPercentPredicted;
  final double pefPercentPredicted;
  final int coughCount;
  final int symptomScore;

  const RiskResult({
    required this.overallScore,
    required this.riskLevel,
    required this.clinicalPattern,
    required this.findings,
    required this.recommendations,
    required this.emergencyFlag,
    required this.heartRate,
    required this.spo2,
    required this.fev1,
    required this.fvc,
    required this.fev1FvcRatio,
    required this.pefLpm,
    required this.fev1PercentPredicted,
    required this.fvcPercentPredicted,
    required this.pefPercentPredicted,
    required this.coughCount,
    required this.symptomScore,
  });

  Map<String, dynamic> toMap() {
    return {
      'overall_score': overallScore,
      'risk_level': riskLevel.name,
      'clinical_pattern': clinicalPattern.name,
      'findings': findings.map((f) => f.toMap()).toList(),
      'recommendations': recommendations,
      'emergency_flag': emergencyFlag ? 1 : 0,
      'heart_rate': heartRate,
      'spo2': spo2,
      'fev1': fev1,
      'fvc': fvc,
      'fev1_fvc_ratio': fev1FvcRatio,
      'pef_lpm': pefLpm,
      'fev1_percent_predicted': fev1PercentPredicted,
      'fvc_percent_predicted': fvcPercentPredicted,
      'pef_percent_predicted': pefPercentPredicted,
      'cough_count': coughCount,
      'symptom_score': symptomScore,
    };
  }

  factory RiskResult.fromMap(Map<String, dynamic> map) {
    return RiskResult(
      overallScore: (map['overall_score'] as num?)?.toInt() ?? 0,
      riskLevel: RiskLevel.values.firstWhere(
        (r) => r.name == (map['risk_level'] as String?),
        orElse: () => RiskLevel.low,
      ),
      clinicalPattern: ClinicalPattern.values.firstWhere(
        (c) => c.name == (map['clinical_pattern'] as String?),
        orElse: () => ClinicalPattern.normal,
      ),
      findings: ((map['findings'] as List<dynamic>?) ?? [])
          .map((item) => ClinicalFinding.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      recommendations: List<String>.from((map['recommendations'] as List<dynamic>?) ?? []),
      emergencyFlag: (map['emergency_flag'] as num?)?.toInt() == 1,
      heartRate: (map['heart_rate'] as num?)?.toInt() ?? 0,
      spo2: (map['spo2'] as num?)?.toInt() ?? 0,
      fev1: (map['fev1'] as num?)?.toDouble() ?? 0.0,
      fvc: (map['fvc'] as num?)?.toDouble() ?? 0.0,
      fev1FvcRatio: (map['fev1_fvc_ratio'] as num?)?.toDouble() ?? 0.0,
      pefLpm: (map['pef_lpm'] as num?)?.toDouble() ?? 0.0,
      fev1PercentPredicted: (map['fev1_percent_predicted'] as num?)?.toDouble() ?? 0.0,
      fvcPercentPredicted: (map['fvc_percent_predicted'] as num?)?.toDouble() ?? 0.0,
      pefPercentPredicted: (map['pef_percent_predicted'] as num?)?.toDouble() ?? 0.0,
      coughCount: (map['cough_count'] as num?)?.toInt() ?? 0,
      symptomScore: (map['symptom_score'] as num?)?.toInt() ?? 0,
    );
  }
}
