import 'package:flutter/foundation.dart';
import '../models/questionnaire_model.dart';

class QuestionnaireController extends ChangeNotifier {
  String _screeningId = '';
  String get screeningId => _screeningId;

  // 1. Current/former smoking: 'Non-smoker', 'Former smoker', 'Current smoker'
  String _smokingStatus = 'Non-smoker';
  String get smokingStatus => _smokingStatus;

  // 2. Years smoked (applicable only if former/current smoker)
  double _yearsSmoked = 0.0;
  double get yearsSmoked => _yearsSmoked;

  // 3. Cigarettes per day (applicable only if former/current smoker)
  int _cigarettesPerDay = 0;
  int get cigarettesPerDay => _cigarettesPerDay;

  // 4. Biomass smoke exposure: 'None', 'Moderate', 'High/Daily'
  String _biomassExposure = 'None';
  String get biomassExposure => _biomassExposure;

  // 5. Breathlessness (mMRC grade 0-4)
  int _breathlessness = 0;
  int get breathlessness => _breathlessness;

  // 6. Chronic cough (>= 3 weeks)
  bool _chronicCough = false;
  bool get chronicCough => _chronicCough;

  // 7. Phlegm / sputum
  bool _phlegm = false;
  bool get phlegm => _phlegm;

  // 8. Wheezing / whistling chest sound
  bool _wheezing = false;
  bool get wheezing => _wheezing;

  // 9. Recurrent respiratory problems / infections
  bool _recurrentRespiratoryProblems = false;
  bool get recurrentRespiratoryProblems => _recurrentRespiratoryProblems;

  // Pre-existing medical conditions
  bool _hasAsthma = false;
  bool get hasAsthma => _hasAsthma;

  bool _hasCopd = false;
  bool get hasCopd => _hasCopd;

  bool _hasHypertension = false;
  bool get hasHypertension => _hasHypertension;

  bool _hasDiabetes = false;
  bool get hasDiabetes => _hasDiabetes;

  bool _hasHeartDisease = false;
  bool get hasHeartDisease => _hasHeartDisease;

  bool _hasTbHistory = false;
  bool get hasTbHistory => _hasTbHistory;

  // Wizard step management
  int _currentStep = 0;
  int get currentStep => _currentStep;
  static const int totalQuestions = 9;

  bool _isReviewMode = false;
  bool get isReviewMode => _isReviewMode;

  QuestionnaireController({String screeningId = ''}) {
    _screeningId = screeningId;
  }

  void initializeWithResponse(QuestionnaireResponse response, {String? screeningId}) {
    _screeningId = screeningId ?? response.screeningId;
    _smokingStatus = response.smokingStatus;
    _yearsSmoked = response.yearsSmoked;
    _cigarettesPerDay = response.cigarettesPerDay;
    _biomassExposure = response.biomassExposure;
    _breathlessness = response.breathlessness;
    _chronicCough = response.chronicCough;
    _phlegm = response.phlegm;
    _wheezing = response.wheezing;
    _recurrentRespiratoryProblems = response.recurrentRespiratoryProblems;
    _hasAsthma = response.hasAsthma;
    _hasCopd = response.hasCopd;
    _hasHypertension = response.hasHypertension;
    _hasDiabetes = response.hasDiabetes;
    _hasHeartDisease = response.hasHeartDisease;
    _hasTbHistory = response.hasTbHistory;
    _isReviewMode = false;
    _currentStep = 0;
    notifyListeners();
  }

  // --- Field Mutators ---

  void setSmokingStatus(String status) {
    _smokingStatus = status;
    if (status == 'Non-smoker') {
      _yearsSmoked = 0.0;
      _cigarettesPerDay = 0;
    } else if (_yearsSmoked == 0.0) {
      _yearsSmoked = 5.0; // Sensible default for former/current smoker
      _cigarettesPerDay = _cigarettesPerDay == 0 ? 5 : _cigarettesPerDay;
    }
    notifyListeners();
  }

  void setYearsSmoked(double years) {
    _yearsSmoked = years.clamp(0.0, 70.0);
    notifyListeners();
  }

  void setCigarettesPerDay(int count) {
    _cigarettesPerDay = count.clamp(0, 100);
    notifyListeners();
  }

  void setBiomassExposure(String exposure) {
    _biomassExposure = exposure;
    notifyListeners();
  }

  void setBreathlessness(int grade) {
    _breathlessness = grade.clamp(0, 4);
    notifyListeners();
  }

  void setChronicCough(bool value) {
    _chronicCough = value;
    notifyListeners();
  }

  void setPhlegm(bool value) {
    _phlegm = value;
    notifyListeners();
  }

  void setWheezing(bool value) {
    _wheezing = value;
    notifyListeners();
  }

  void setRecurrentRespiratoryProblems(bool value) {
    _recurrentRespiratoryProblems = value;
    notifyListeners();
  }

  void toggleAsthma(bool value) {
    _hasAsthma = value;
    notifyListeners();
  }

  void toggleCopd(bool value) {
    _hasCopd = value;
    notifyListeners();
  }

  void toggleHypertension(bool value) {
    _hasHypertension = value;
    notifyListeners();
  }

  void toggleDiabetes(bool value) {
    _hasDiabetes = value;
    notifyListeners();
  }

  void toggleHeartDisease(bool value) {
    _hasHeartDisease = value;
    notifyListeners();
  }

  void toggleTbHistory(bool value) {
    _hasTbHistory = value;
    notifyListeners();
  }

  // --- Step & Navigation Controls ---

  void nextStep() {
    if (_currentStep < totalQuestions - 1) {
      _currentStep++;
      notifyListeners();
    } else {
      _isReviewMode = true;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_isReviewMode) {
      _isReviewMode = false;
      _currentStep = totalQuestions - 1;
      notifyListeners();
    } else if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  void goToStep(int step) {
    if (step >= 0 && step < totalQuestions) {
      _currentStep = step;
      _isReviewMode = false;
      notifyListeners();
    }
  }

  void enterReviewMode() {
    _isReviewMode = true;
    notifyListeners();
  }

  void exitReviewMode({int step = 0}) {
    _isReviewMode = false;
    _currentStep = step;
    notifyListeners();
  }

  // --- Validation ---

  bool get isSmoker => _smokingStatus == 'Current smoker' || _smokingStatus == 'Former smoker';

  /// Validates all required fields according to clinical screening rules.
  /// Returns null if valid, or a descriptive error message.
  String? validate() {
    if (_smokingStatus.isEmpty) {
      return 'Please specify the patient\'s smoking status.';
    }

    if (isSmoker) {
      if (_yearsSmoked <= 0) {
        return 'Please enter the number of years smoked.';
      }
      if (_cigarettesPerDay <= 0) {
        return 'Please enter the estimated cigarettes / bidis per day.';
      }
    }

    if (_biomassExposure.isEmpty) {
      return 'Please select biomass smoke exposure level.';
    }

    if (_breathlessness < 0 || _breathlessness > 4) {
      return 'Please select a valid breathlessness grade (0 to 4).';
    }

    return null;
  }

  bool get isValid => validate() == null;

  /// Creates an immutable [QuestionnaireResponse] snapshot from current answers.
  QuestionnaireResponse toResponse() {
    return QuestionnaireResponse(
      screeningId: _screeningId,
      smokingStatus: _smokingStatus,
      yearsSmoked: isSmoker ? _yearsSmoked : 0.0,
      cigarettesPerDay: isSmoker ? _cigarettesPerDay : 0,
      biomassExposure: _biomassExposure,
      breathlessness: _breathlessness,
      chronicCough: _chronicCough,
      phlegm: _phlegm,
      wheezing: _wheezing,
      recurrentRespiratoryProblems: _recurrentRespiratoryProblems,
      hasAsthma: _hasAsthma,
      hasCopd: _hasCopd,
      hasHypertension: _hasHypertension,
      hasDiabetes: _hasDiabetes,
      hasHeartDisease: _hasHeartDisease,
      hasTbHistory: _hasTbHistory,
    );
  }
}
