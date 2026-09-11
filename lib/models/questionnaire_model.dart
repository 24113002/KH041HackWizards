class QuestionnaireResponse {
  // mMRC Dyspnea scale (0: None, 1: Strenuous exercise, 2: Hurrying on level, 3: Stops after 100m, 4: Housebound)
  final int mmrcDyspneaGrade;

  // Cough frequency (0: None, 1: Occasional, 2: Daily, 3: Chronic >3 weeks)
  final int coughFrequency;

  // Sputum (0: None, 1: Clear/Mucoid, 2: Purulent/Yellow-Green, 3: Hemoptysis/Blood-tinged)
  final int sputumType;

  // Wheezing episodes (0: Never, 1: Triggered by cold/dust, 2: Recurrent/Frequent)
  final int wheezeSeverity;

  // Chest tightness/discomfort (0: None, 1: Exertional, 2: Rest/Severe)
  final int chestDiscomfort;

  // Smoking history (0: Non-smoker, 1: Former smoker, 2: Current smoker)
  final int smokingStatus;
  final double packYears;

  // Biomass / Chulha / Indoor wood smoke exposure (0: None, 1: Moderate, 2: High/Daily)
  final int biomassExposure;

  // Comorbidities
  final bool hasAsthma;
  final bool hasCopd;
  final bool hasHypertension;
  final bool hasDiabetes;
  final bool hasHeartDisease;
  final bool hasTbHistory;

  const QuestionnaireResponse({
    this.mmrcDyspneaGrade = 0,
    this.coughFrequency = 0,
    this.sputumType = 0,
    this.wheezeSeverity = 0,
    this.chestDiscomfort = 0,
    this.smokingStatus = 0,
    this.packYears = 0.0,
    this.biomassExposure = 0,
    this.hasAsthma = false,
    this.hasCopd = false,
    this.hasHypertension = false,
    this.hasDiabetes = false,
    this.hasHeartDisease = false,
    this.hasTbHistory = false,
  });

  /// Computes a normalized clinical symptom burden score (0 to 30)
  int get symptomScore {
    int score = 0;
    // Dyspnea (weight up to 8)
    score += mmrcDyspneaGrade * 2;
    // Cough (0-3)
    score += coughFrequency;
    // Sputum (0-3)
    score += sputumType;
    // Wheeze (0-4)
    score += wheezeSeverity * 2;
    // Chest discomfort (0-4)
    score += chestDiscomfort * 2;
    // Smoking impact
    if (smokingStatus == 2) {
      score += (packYears > 10) ? 3 : 2;
    } else if (smokingStatus == 1) {
      score += 1;
    }
    // Biomass exposure
    score += biomassExposure * 2;
    // Comorbidities
    if (hasAsthma) score += 2;
    if (hasCopd) score += 3;
    if (hasHeartDisease) score += 3;
    if (hasHypertension) score += 1;
    if (hasTbHistory) score += 2;

    return score;
  }

  Map<String, dynamic> toMap() {
    return {
      'mmrc_dyspnea_grade': mmrcDyspneaGrade,
      'cough_frequency': coughFrequency,
      'sputum_type': sputumType,
      'wheeze_severity': wheezeSeverity,
      'chest_discomfort': chestDiscomfort,
      'smoking_status': smokingStatus,
      'pack_years': packYears,
      'biomass_exposure': biomassExposure,
      'has_asthma': hasAsthma ? 1 : 0,
      'has_copd': hasCopd ? 1 : 0,
      'has_hypertension': hasHypertension ? 1 : 0,
      'has_diabetes': hasDiabetes ? 1 : 0,
      'has_heart_disease': hasHeartDisease ? 1 : 0,
      'has_tb_history': hasTbHistory ? 1 : 0,
    };
  }

  factory QuestionnaireResponse.fromMap(Map<String, dynamic> map) {
    return QuestionnaireResponse(
      mmrcDyspneaGrade: (map['mmrc_dyspnea_grade'] as num?)?.toInt() ?? 0,
      coughFrequency: (map['cough_frequency'] as num?)?.toInt() ?? 0,
      sputumType: (map['sputum_type'] as num?)?.toInt() ?? 0,
      wheezeSeverity: (map['wheeze_severity'] as num?)?.toInt() ?? 0,
      chestDiscomfort: (map['chest_discomfort'] as num?)?.toInt() ?? 0,
      smokingStatus: (map['smoking_status'] as num?)?.toInt() ?? 0,
      packYears: (map['pack_years'] as num?)?.toDouble() ?? 0.0,
      biomassExposure: (map['biomass_exposure'] as num?)?.toInt() ?? 0,
      hasAsthma: (map['has_asthma'] as num?)?.toInt() == 1,
      hasCopd: (map['has_copd'] as num?)?.toInt() == 1,
      hasHypertension: (map['has_hypertension'] as num?)?.toInt() == 1,
      hasDiabetes: (map['has_diabetes'] as num?)?.toInt() == 1,
      hasHeartDisease: (map['has_heart_disease'] as num?)?.toInt() == 1,
      hasTbHistory: (map['has_tb_history'] as num?)?.toInt() == 1,
    );
  }
}
