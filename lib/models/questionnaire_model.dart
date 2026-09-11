class QuestionnaireResponse {
  final String screeningId;

  // 1. Current/former smoking
  final String smokingStatus; // Non-smoker, Former smoker, Current smoker
  // 2. Years smoked
  final double yearsSmoked;
  // 3. Cigarettes per day
  final int cigarettesPerDay;
  // 4. Biomass smoke exposure
  final String biomassExposure; // None, Moderate, High/Daily
  // 5. Breathlessness (mMRC grade 0-4)
  final int breathlessness;
  // 6. Chronic cough
  final bool chronicCough;
  // 7. Phlegm / sputum
  final bool phlegm;
  // 8. Wheezing
  final bool wheezing;
  // 9. Recurrent respiratory problems
  final bool recurrentRespiratoryProblems;

  // Additional comorbidity flags
  final bool hasAsthma;
  final bool hasCopd;
  final bool hasHypertension;
  final bool hasDiabetes;
  final bool hasHeartDisease;
  final bool hasTbHistory;

  const QuestionnaireResponse({
    this.screeningId = '',
    dynamic smokingStatus = 'Non-smoker',
    this.yearsSmoked = 0.0,
    this.cigarettesPerDay = 0,
    dynamic biomassExposure = 'None',
    int? breathlessness,
    int? mmrcDyspneaGrade,
    bool? chronicCough,
    int? coughFrequency,
    bool? phlegm,
    int? sputumType,
    bool? wheezing,
    int? wheezeSeverity,
    bool? recurrentRespiratoryProblems,
    int? chestDiscomfort,
    double? packYears,
    this.hasAsthma = false,
    this.hasCopd = false,
    this.hasHypertension = false,
    this.hasDiabetes = false,
    this.hasHeartDisease = false,
    this.hasTbHistory = false,
  })  : smokingStatus = (smokingStatus == 2 || smokingStatus == 'Current smoker')
            ? 'Current smoker'
            : (smokingStatus == 1 || smokingStatus == 'Former smoker')
                ? 'Former smoker'
                : 'Non-smoker',
        biomassExposure = (biomassExposure == 2 || biomassExposure == 'High/Daily')
            ? 'High/Daily'
            : (biomassExposure == 1 || biomassExposure == 'Moderate')
                ? 'Moderate'
                : 'None',
        breathlessness = breathlessness ?? mmrcDyspneaGrade ?? 0,
        chronicCough = chronicCough ?? (coughFrequency != null && coughFrequency > 0),
        phlegm = phlegm ?? (sputumType != null && sputumType > 0),
        wheezing = wheezing ?? (wheezeSeverity != null && wheezeSeverity > 0),
        recurrentRespiratoryProblems = recurrentRespiratoryProblems ?? (chestDiscomfort != null && chestDiscomfort > 0);

  // --- Backward Compatibility Aliases ---
  int get mmrcDyspneaGrade => breathlessness;
  int get coughFrequency => chronicCough ? 2 : 0;
  int get sputumType => phlegm ? 1 : 0;
  int get wheezeSeverity => wheezing ? 2 : 0;
  int get chestDiscomfort => recurrentRespiratoryProblems ? 1 : 0;
  int get smokingStatusCode => smokingStatus == 'Current smoker' ? 2 : (smokingStatus == 'Former smoker' ? 1 : 0);
  int get biomassExposureLevel => biomassExposure == 'High/Daily' ? 2 : (biomassExposure == 'Moderate' ? 1 : 0);
  double get packYears => (yearsSmoked * cigarettesPerDay) / 20.0;

  int get symptomScore {
    int score = 0;
    score += breathlessness * 2;
    if (chronicCough) score += 2;
    if (phlegm) score += 2;
    if (wheezing) score += 3;
    if (recurrentRespiratoryProblems) score += 3;
    if (smokingStatus == 'Current smoker') {
      score += (yearsSmoked > 10) ? 4 : 2;
    }
    if (biomassExposure == 'High/Daily') score += 3;
    return score;
  }

  QuestionnaireResponse copyWith({
    String? screeningId,
    dynamic smokingStatus,
    double? yearsSmoked,
    int? cigarettesPerDay,
    dynamic biomassExposure,
    int? breathlessness,
    bool? chronicCough,
    bool? phlegm,
    bool? wheezing,
    bool? recurrentRespiratoryProblems,
    bool? hasAsthma,
    bool? hasCopd,
    bool? hasHypertension,
    bool? hasDiabetes,
    bool? hasHeartDisease,
    bool? hasTbHistory,
  }) {
    return QuestionnaireResponse(
      screeningId: screeningId ?? this.screeningId,
      smokingStatus: smokingStatus ?? this.smokingStatus,
      yearsSmoked: yearsSmoked ?? this.yearsSmoked,
      cigarettesPerDay: cigarettesPerDay ?? this.cigarettesPerDay,
      biomassExposure: biomassExposure ?? this.biomassExposure,
      breathlessness: breathlessness ?? this.breathlessness,
      chronicCough: chronicCough ?? this.chronicCough,
      phlegm: phlegm ?? this.phlegm,
      wheezing: wheezing ?? this.wheezing,
      recurrentRespiratoryProblems: recurrentRespiratoryProblems ?? this.recurrentRespiratoryProblems,
      hasAsthma: hasAsthma ?? this.hasAsthma,
      hasCopd: hasCopd ?? this.hasCopd,
      hasHypertension: hasHypertension ?? this.hasHypertension,
      hasDiabetes: hasDiabetes ?? this.hasDiabetes,
      hasHeartDisease: hasHeartDisease ?? this.hasHeartDisease,
      hasTbHistory: hasTbHistory ?? this.hasTbHistory,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'screening_id': screeningId,
      'smoking_status': smokingStatus,
      'years_smoked': yearsSmoked,
      'cigarettes_per_day': cigarettesPerDay,
      'biomass_exposure': biomassExposure,
      'breathlessness': breathlessness,
      'chronic_cough': chronicCough ? 1 : 0,
      'phlegm': phlegm ? 1 : 0,
      'wheezing': wheezing ? 1 : 0,
      'recurrent_respiratory_problems': recurrentRespiratoryProblems ? 1 : 0,
      'has_asthma': hasAsthma ? 1 : 0,
      'has_copd': hasCopd ? 1 : 0,
      'has_hypertension': hasHypertension ? 1 : 0,
      'has_diabetes': hasDiabetes ? 1 : 0,
      'has_heart_disease': hasHeartDisease ? 1 : 0,
      'has_tb_history': hasTbHistory ? 1 : 0,
    };
  }

  factory QuestionnaireResponse.fromMap(Map<String, dynamic> map) {
    final sStatus = (map['smoking_status'] as String?) ?? 'Non-smoker';
    final bExposure = (map['biomass_exposure'] as String?) ?? 'None';
    return QuestionnaireResponse(
      screeningId: (map['screening_id'] as String?) ?? '',
      smokingStatus: sStatus,
      yearsSmoked: (map['years_smoked'] as num?)?.toDouble() ?? 0.0,
      cigarettesPerDay: (map['cigarettes_per_day'] as num?)?.toInt() ?? 0,
      biomassExposure: bExposure,
      breathlessness: (map['breathlessness'] as num?)?.toInt() ?? (map['mmrc_dyspnea_grade'] as num?)?.toInt() ?? 0,
      chronicCough: (map['chronic_cough'] as num?)?.toInt() == 1 || ((map['cough_frequency'] as num?)?.toInt() ?? 0) > 0,
      phlegm: (map['phlegm'] as num?)?.toInt() == 1 || ((map['sputum_type'] as num?)?.toInt() ?? 0) > 0,
      wheezing: (map['wheezing'] as num?)?.toInt() == 1 || ((map['wheeze_severity'] as num?)?.toInt() ?? 0) > 0,
      recurrentRespiratoryProblems: (map['recurrent_respiratory_problems'] as num?)?.toInt() == 1 || ((map['chest_discomfort'] as num?)?.toInt() ?? 0) > 0,
      hasAsthma: (map['has_asthma'] as num?)?.toInt() == 1,
      hasCopd: (map['has_copd'] as num?)?.toInt() == 1,
      hasHypertension: (map['has_hypertension'] as num?)?.toInt() == 1,
      hasDiabetes: (map['has_diabetes'] as num?)?.toInt() == 1,
      hasHeartDisease: (map['has_heart_disease'] as num?)?.toInt() == 1,
      hasTbHistory: (map['has_tb_history'] as num?)?.toInt() == 1,
    );
  }
}
