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
        return 'Low Risk';
      case RiskLevel.moderate:
        return 'Moderate Risk';
      case RiskLevel.high:
        return 'High Risk';
      case RiskLevel.critical:
        return 'Critical / Urgent Triage';
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
  obstructiveAirway,
  restrictivePattern,
  acuteHypoxemia,
  cardiovascularStrain,
  mixedCardiorespiratory,
}

extension ClinicalPatternExtension on ClinicalPattern {
  String get displayName {
    switch (this) {
      case ClinicalPattern.normal:
        return 'Normal Cardiopulmonary Function';
      case ClinicalPattern.obstructiveAirway:
        return 'Obstructive Airway Pattern (Asthma/COPD risk)';
      case ClinicalPattern.restrictivePattern:
        return 'Possible Restrictive Lung Pattern';
      case ClinicalPattern.acuteHypoxemia:
        return 'Acute Hypoxemic Respiratory Distress';
      case ClinicalPattern.cardiovascularStrain:
        return 'Cardiovascular Strain Alert';
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
      title: (map['title'] as String?) ?? '',
      details: (map['details'] as String?) ?? '',
      isAbnormal: (map['is_abnormal'] as num?)?.toInt() == 1,
      isUrgent: (map['is_urgent'] as num?)?.toInt() == 1,
    );
  }
}

class RiskResult {
  static const String medicalDisclaimer =
      "SwasthAI is a screening-support application, NOT a diagnostic medical device. Confirmatory clinical evaluation and spirometry may be required.";

  final String screeningId;
  final int riskScore; // 0 to 100
  final String riskCategory; // Low Risk, Moderate Risk, High Risk, Critical Risk
  final List<String> contributingFactors;
  final String recommendation;
  final DateTime? createdAt;

  // Compatibility fields
  final RiskLevel riskLevel;
  final ClinicalPattern clinicalPattern;
  final List<ClinicalFinding> findings;
  final List<String> recommendations;
  final bool emergencyFlag;
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
    this.screeningId = '',
    int? riskScore,
    int? overallScore,
    this.riskCategory = 'Low Risk',
    this.riskLevel = RiskLevel.low,
    this.contributingFactors = const [],
    this.recommendation = 'Maintain healthy lifestyle and schedule periodic screening.',
    this.createdAt,
    this.clinicalPattern = ClinicalPattern.normal,
    this.findings = const [],
    this.recommendations = const ['Maintain healthy lifestyle and schedule periodic screening.'],
    this.emergencyFlag = false,
    this.heartRate = 75,
    this.spo2 = 98,
    this.fev1 = 3.2,
    this.fvc = 4.0,
    this.fev1FvcRatio = 0.80,
    this.pefLpm = 450.0,
    this.fev1PercentPredicted = 95.0,
    this.fvcPercentPredicted = 95.0,
    this.pefPercentPredicted = 95.0,
    this.coughCount = 0,
    this.symptomScore = 0,
  }) : riskScore = overallScore ?? riskScore ?? 0;

  static RiskLevel _resolveRiskLevel(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('critical') || lower.contains('urgent')) return RiskLevel.critical;
    if (lower.contains('high')) return RiskLevel.high;
    if (lower.contains('moderate')) return RiskLevel.moderate;
    return RiskLevel.low;
  }

  int get overallScore => riskScore;
  DateTime get createdDateTime => createdAt ?? DateTime.now();

  factory RiskResult.mock({required String screeningId, int? score, String? category}) {
    final finalScore = score ?? 14;
    final finalCategory = category ?? 'Low Risk';
    return RiskResult(
      screeningId: screeningId,
      riskScore: finalScore,
      riskCategory: finalCategory,
      riskLevel: _resolveRiskLevel(finalCategory),
      contributingFactors: const ['Normal SpO2 saturation', 'Unremarkable cough activity'],
      recommendation: 'Screening parameters are within normal limits. Repeat routine annual screening.',
      recommendations: const ['Screening parameters are within normal limits. Repeat routine annual screening.'],
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'screening_id': screeningId,
      'risk_score': riskScore,
      'risk_category': riskCategory,
      'contributing_factors': contributingFactors,
      'recommendation': recommendation,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
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
    final cat = (map['risk_category'] as String?) ?? (map['risk_level'] as String?) ?? 'Low Risk';
    final score = (map['risk_score'] as num?)?.toInt() ?? (map['overall_score'] as num?)?.toInt() ?? 0;
    final factors = List<String>.from((map['contributing_factors'] as List<dynamic>?) ?? []);
    final rec = (map['recommendation'] as String?) ??
        (((map['recommendations'] as List<dynamic>?)?.isNotEmpty == true)
            ? (map['recommendations'] as List<dynamic>).first as String
            : 'Routine follow-up.');

    return RiskResult(
      screeningId: (map['screening_id'] as String?) ?? '',
      riskScore: score,
      riskCategory: cat,
      riskLevel: RiskLevel.values.firstWhere(
        (r) => r.name == (map['risk_level'] as String?),
        orElse: () => _resolveRiskLevel(cat),
      ),
      contributingFactors: factors,
      recommendation: rec,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      clinicalPattern: ClinicalPattern.values.firstWhere(
        (c) => c.name == (map['clinical_pattern'] as String?),
        orElse: () => ClinicalPattern.normal,
      ),
      findings: ((map['findings'] as List<dynamic>?) ?? [])
          .map((item) => ClinicalFinding.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      recommendations: List<String>.from((map['recommendations'] as List<dynamic>?) ?? [rec]),
      emergencyFlag: (map['emergency_flag'] as num?)?.toInt() == 1,
      heartRate: (map['heart_rate'] as num?)?.toInt() ?? 75,
      spo2: (map['spo2'] as num?)?.toInt() ?? 98,
      fev1: (map['fev1'] as num?)?.toDouble() ?? 3.2,
      fvc: (map['fvc'] as num?)?.toDouble() ?? 4.0,
      fev1FvcRatio: (map['fev1_fvc_ratio'] as num?)?.toDouble() ?? 0.80,
      pefLpm: (map['pef_lpm'] as num?)?.toDouble() ?? 450.0,
      fev1PercentPredicted: (map['fev1_percent_predicted'] as num?)?.toDouble() ?? 95.0,
      fvcPercentPredicted: (map['fvc_percent_predicted'] as num?)?.toDouble() ?? 95.0,
      pefPercentPredicted: (map['pef_percent_predicted'] as num?)?.toDouble() ?? 95.0,
      coughCount: (map['cough_count'] as num?)?.toInt() ?? 0,
      symptomScore: (map['symptom_score'] as num?)?.toInt() ?? 0,
    );
  }

  /// Deserializes risk result from FastAPI RiskResultResponse schema
  factory RiskResult.fromApiJson(Map<String, dynamic> json, {String? localScreeningId}) {
    final cat = (json['risk_category'] as String?) ?? 'Low Risk';
    final score = (json['risk_score'] as num?)?.round() ?? 0;
    final factors = List<String>.from((json['contributing_factors'] as List<dynamic>?) ?? []);
    final rec = (json['recommendation'] as String?) ?? 'Routine follow-up screening recommended.';

    return RiskResult(
      screeningId: localScreeningId ?? json['screening_id']?.toString() ?? '',
      riskScore: score,
      overallScore: score,
      riskCategory: cat,
      riskLevel: _resolveRiskLevel(cat),
      contributingFactors: factors,
      recommendation: rec,
      recommendations: [rec],
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

