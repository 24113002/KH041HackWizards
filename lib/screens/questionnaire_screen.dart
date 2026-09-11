import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/assessment_controller.dart';
import '../controllers/current_screening_controller.dart';
import '../controllers/questionnaire_controller.dart';
import '../models/patient_model.dart';
import '../models/risk_assessment_input.dart';
import '../models/sensor_data_model.dart';
import '../models/swaas_ai_ble_result.dart';
import '../theme/app_theme.dart';
import 'screening_result_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  final Patient patient;
  final VitalsReading? vitals;
  final SpirometrySummary? spirometry;
  final AcousticSummary? acoustic;
  final SwaasAiBleResult? bleResult;

  const QuestionnaireScreen({
    super.key,
    required this.patient,
    this.vitals,
    this.spirometry,
    this.acoustic,
    this.bleResult,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  late QuestionnaireController _controller;
  late AssessmentController _assessmentController;

  @override
  void initState() {
    super.initState();
    final screeningController = context.read<CurrentScreeningController>();
    _controller = QuestionnaireController(screeningId: screeningController.session?.id ?? '');
    _assessmentController = AssessmentController();

    // Populate with existing answers if present in session
    if (screeningController.questionnaire.screeningId.isNotEmpty ||
        screeningController.questionnaire.smokingStatus != 'Non-smoker' ||
        screeningController.questionnaire.breathlessness > 0) {
      _controller.initializeWithResponse(
        screeningController.questionnaire,
        screeningId: screeningController.session?.id,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _assessmentController.dispose();
    super.dispose();
  }

  void _onRunAssessment() async {
    final validationError = _controller.validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: AppTheme.riskCritical,
        ),
      );
      return;
    }

    final screeningController = context.read<CurrentScreeningController>();
    final qResponse = _controller.toResponse();

    // Sync to session controller
    screeningController.updateQuestionnaire(qResponse);

    final input = RiskAssessmentInput(
      screeningId: screeningController.session?.id ?? 'sess_${widget.patient.id}',
      patient: widget.patient,
      questionnaire: qResponse,
      bleResult: widget.bleResult ?? screeningController.bleResult,
    );

    // Show Loading Modal
    _showAssessmentLoadingDialog();

    final result = await _assessmentController.runAssessment(
      input: input,
      currentScreeningController: screeningController,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading modal

    if (result != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ScreeningResultScreen(
            patient: widget.patient,
            vitals: screeningController.vitals,
            spirometry: screeningController.spirometry,
            acoustic: screeningController.acoustic,
            questionnaire: qResponse,
            riskResult: result,
            bleResult: widget.bleResult ?? screeningController.bleResult,
          ),
        ),
      );
    } else {
      _showAssessmentErrorDialog(_assessmentController.errorMessage ?? 'Unable to complete screening assessment.');
    }
  }

  void _showAssessmentLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryTeal, strokeWidth: 3),
                SizedBox(height: 20),
                Text(
                  'Preparing screening assessment...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                ),
                SizedBox(height: 8),
                Text(
                  'Processing screening information and sensor observations...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAssessmentErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.riskCritical),
            SizedBox(width: 8),
            Text('Assessment Error', style: TextStyle(color: AppTheme.textLight, fontSize: 16)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Review Data', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onRunAssessment();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screeningController = context.watch<CurrentScreeningController>();
    final bleResult = widget.bleResult ?? screeningController.bleResult;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isReview = _controller.isReviewMode;
        final step = _controller.currentStep;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'COPD Screening Questionnaire',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            actions: [
              if (!isReview)
                TextButton(
                  onPressed: _controller.enterReviewMode,
                  child: const Text('Review', style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          body: Column(
            children: [
              // Header Patient Banner
              _buildPatientHeader(bleResult),

              // Medical Disclaimer Caption
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: AppTheme.primaryTeal.withAlpha(15),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppTheme.primaryTeal),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This questionnaire supports respiratory risk screening and does not provide a diagnosis.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ),

              // Progress Bar if in question wizard mode
              if (!isReview) ...[
                LinearProgressIndicator(
                  value: (step + 1) / QuestionnaireController.totalQuestions,
                  backgroundColor: AppTheme.surfaceDark,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                  minHeight: 4,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'QUESTION ${step + 1} OF ${QuestionnaireController.totalQuestions}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                      ),
                      Text(
                        'Step ${step + 1} / 9',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],

              // Content Area
              Expanded(
                child: isReview
                    ? _buildReviewScreen(bleResult)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildQuestionStep(step),
                      ),
              ),

              // Bottom Navigation Bar
              _buildBottomBar(isReview, step),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPatientHeader(SwaasAiBleResult? bleResult) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(10))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryTeal.withAlpha(30),
            child: Text(
              widget.patient.name.isNotEmpty ? widget.patient.name[0].toUpperCase() : 'P',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.patient.name} (${widget.patient.age}y, ${widget.patient.gender.name.toUpperCase()})',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textLight),
                ),
                Text(
                  'Village: ${widget.patient.village.isNotEmpty ? widget.patient.village : 'N/A'} • SpO₂: ${bleResult?.formattedSpo2 ?? '--'}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionStep(int step) {
    switch (step) {
      case 0:
        return _buildSmokingQuestion();
      case 1:
        return _buildSmokerDetailsQuestion();
      case 2:
        return _buildBiomassQuestion();
      case 3:
        return _buildBreathlessnessQuestion();
      case 4:
        return _buildChronicCoughQuestion();
      case 5:
        return _buildPhlegmQuestion();
      case 6:
        return _buildWheezingQuestion();
      case 7:
        return _buildRecurrentProblemsQuestion();
      case 8:
        return _buildComorbiditiesQuestion();
      default:
        return const SizedBox.shrink();
    }
  }

  // 1. Smoking Status
  Widget _buildSmokingQuestion() {
    return _buildQuestionCard(
      title: 'Tobacco Smoking Status',
      subtitle: 'Does the patient currently smoke or have a history of smoking tobacco (bidis/cigarettes)?',
      icon: Icons.smoke_free,
      child: Column(
        children: [
          _buildOptionTile(
            title: 'Never smoked (Non-smoker)',
            subtitle: 'No significant lifetime tobacco smoking history',
            isSelected: _controller.smokingStatus == 'Non-smoker',
            onTap: () => _controller.setSmokingStatus('Non-smoker'),
          ),
          const SizedBox(height: 10),
          _buildOptionTile(
            title: 'Former smoker',
            subtitle: 'Previously smoked tobacco regularly but has quit',
            isSelected: _controller.smokingStatus == 'Former smoker',
            onTap: () => _controller.setSmokingStatus('Former smoker'),
          ),
          const SizedBox(height: 10),
          _buildOptionTile(
            title: 'Current smoker',
            subtitle: 'Regularly smokes cigarettes, bidis, or hookah',
            isSelected: _controller.smokingStatus == 'Current smoker',
            onTap: () => _controller.setSmokingStatus('Current smoker'),
          ),
        ],
      ),
    );
  }

  // 2. Smoker Details (Years smoked & Cigarettes/day)
  Widget _buildSmokerDetailsQuestion() {
    if (!_controller.isSmoker) {
      return _buildQuestionCard(
        title: 'Smoking Exposure Details',
        subtitle: 'Not applicable for non-smoker.',
        icon: Icons.check_circle_outline,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.check, color: AppTheme.riskLow, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Patient is recorded as a Non-smoker. You may proceed to the next question.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildQuestionCard(
      title: 'Smoking Exposure Intensity',
      subtitle: 'Specify the total duration and daily quantity of smoking.',
      icon: Icons.smoking_rooms,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Years Smoked:', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textLight)),
              Text('${_controller.yearsSmoked.toStringAsFixed(0)} years', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
            ],
          ),
          Slider(
            value: _controller.yearsSmoked,
            min: 0,
            max: 60,
            divisions: 60,
            activeColor: AppTheme.primaryTeal,
            onChanged: _controller.setYearsSmoked,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cigarettes / Bidis per Day:', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textLight)),
              Text('${_controller.cigarettesPerDay} / day', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
            ],
          ),
          Slider(
            value: _controller.cigarettesPerDay.toDouble(),
            min: 0,
            max: 50,
            divisions: 50,
            activeColor: AppTheme.primaryTeal,
            onChanged: (v) => _controller.setCigarettesPerDay(v.round()),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Estimated Pack-Years:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                Text(
                  '${((_controller.yearsSmoked * _controller.cigarettesPerDay) / 20.0).toStringAsFixed(1)} pack-years',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Biomass Smoke Exposure
  Widget _buildBiomassQuestion() {
    return _buildQuestionCard(
      title: 'Biomass Smoke Exposure',
      subtitle: 'Is the patient regularly exposed to smoke from chulha, wood, dung cakes, or crop burning?',
      icon: Icons.fireplace,
      child: Column(
        children: [
          _buildOptionTile(
            title: 'None (No exposure)',
            subtitle: 'Uses clean cooking fuel (LPG/electricity); no indoor smoke',
            isSelected: _controller.biomassExposure == 'None',
            onTap: () => _controller.setBiomassExposure('None'),
          ),
          const SizedBox(height: 10),
          _buildOptionTile(
            title: 'Moderate exposure',
            subtitle: 'Occasional cooking with biomass, well-ventilated kitchen',
            isSelected: _controller.biomassExposure == 'Moderate',
            onTap: () => _controller.setBiomassExposure('Moderate'),
          ),
          const SizedBox(height: 10),
          _buildOptionTile(
            title: 'High / Daily exposure',
            subtitle: 'Daily indoor cooking with wood/dung in poorly ventilated space',
            isSelected: _controller.biomassExposure == 'High/Daily',
            onTap: () => _controller.setBiomassExposure('High/Daily'),
          ),
        ],
      ),
    );
  }

  // 4. Breathlessness (mMRC Dyspnea Grade)
  Widget _buildBreathlessnessQuestion() {
    return _buildQuestionCard(
      title: 'Breathlessness (mMRC Dyspnea Scale)',
      subtitle: 'How does shortness of breath affect the patient\'s daily physical activity?',
      icon: Icons.air,
      child: Column(
        children: [
          _buildOptionTile(
            title: 'Grade 0: Only with strenuous exercise',
            subtitle: 'No trouble walking or climbing stairs at normal pace',
            isSelected: _controller.breathlessness == 0,
            onTap: () => _controller.setBreathlessness(0),
          ),
          const SizedBox(height: 10),
          _buildOptionTile(
            title: 'Grade 1: Hurrying on level ground / slight hill',
            subtitle: 'Short of breath when hurrying or walking up a slight incline',
            isSelected: _controller.breathlessness == 1,
            onTap: () => _controller.setBreathlessness(1),
          ),
          const SizedBox(height: 10),
          _buildOptionTile(
            title: 'Grade 2: Walks slower than peers',
            subtitle: 'Walks slower than people of same age or has to stop for breath',
            isSelected: _controller.breathlessness == 2,
            onTap: () => _controller.setBreathlessness(2),
          ),
          const SizedBox(height: 10),
          _buildOptionTile(
            title: 'Grade 3: Stops for breath after ~100 meters',
            subtitle: 'Stops for breath after walking 100m or after a few minutes on level ground',
            isSelected: _controller.breathlessness == 3,
            onTap: () => _controller.setBreathlessness(3),
          ),
          const SizedBox(height: 10),
          _buildOptionTile(
            title: 'Grade 4: Too breathless to leave house',
            subtitle: 'Breathless when dressing, undressing, or carrying out basic home tasks',
            isSelected: _controller.breathlessness == 4,
            onTap: () => _controller.setBreathlessness(4),
          ),
        ],
      ),
    );
  }

  // 5. Chronic Cough
  Widget _buildChronicCoughQuestion() {
    return _buildQuestionCard(
      title: 'Chronic Cough',
      subtitle: 'Does the patient have a persistent cough on most days for several weeks or months?',
      icon: Icons.masks_outlined,
      child: Row(
        children: [
          Expanded(
            child: _buildChoiceCard(
              title: 'Yes',
              subtitle: 'Frequent or daily cough',
              isSelected: _controller.chronicCough,
              onTap: () => _controller.setChronicCough(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildChoiceCard(
              title: 'No',
              subtitle: 'No chronic cough',
              isSelected: !_controller.chronicCough,
              onTap: () => _controller.setChronicCough(false),
            ),
          ),
        ],
      ),
    );
  }

  // 6. Phlegm / Sputum
  Widget _buildPhlegmQuestion() {
    return _buildQuestionCard(
      title: 'Phlegm / Sputum Production',
      subtitle: 'Does the patient bring up phlegm, mucus, or sputum from the chest on most days?',
      icon: Icons.water_drop_outlined,
      child: Row(
        children: [
          Expanded(
            child: _buildChoiceCard(
              title: 'Yes',
              subtitle: 'Regular sputum production',
              isSelected: _controller.phlegm,
              onTap: () => _controller.setPhlegm(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildChoiceCard(
              title: 'No',
              subtitle: 'Dry cough or no sputum',
              isSelected: !_controller.phlegm,
              onTap: () => _controller.setPhlegm(false),
            ),
          ),
        ],
      ),
    );
  }

  // 7. Wheezing
  Widget _buildWheezingQuestion() {
    return _buildQuestionCard(
      title: 'Wheezing / Whistling Chest Sound',
      subtitle: 'Does the patient experience whistling, musical sounds, or wheezing when breathing?',
      icon: Icons.hearing,
      child: Row(
        children: [
          Expanded(
            child: _buildChoiceCard(
              title: 'Yes',
              subtitle: 'Wheezing sounds present',
              isSelected: _controller.wheezing,
              onTap: () => _controller.setWheezing(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildChoiceCard(
              title: 'No',
              subtitle: 'No wheezing reported',
              isSelected: !_controller.wheezing,
              onTap: () => _controller.setWheezing(false),
            ),
          ),
        ],
      ),
    );
  }

  // 8. Recurrent Respiratory Problems
  Widget _buildRecurrentProblemsQuestion() {
    return _buildQuestionCard(
      title: 'Recurrent Respiratory Problems',
      subtitle: 'Does the patient frequently suffer from chest colds, bronchitis, or chest infections?',
      icon: Icons.healing,
      child: Row(
        children: [
          Expanded(
            child: _buildChoiceCard(
              title: 'Yes',
              subtitle: 'Repeated chest infections',
              isSelected: _controller.recurrentRespiratoryProblems,
              onTap: () => _controller.setRecurrentRespiratoryProblems(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildChoiceCard(
              title: 'No',
              subtitle: 'No frequent infections',
              isSelected: !_controller.recurrentRespiratoryProblems,
              onTap: () => _controller.setRecurrentRespiratoryProblems(false),
            ),
          ),
        ],
      ),
    );
  }

  // 9. Pre-existing Conditions
  Widget _buildComorbiditiesQuestion() {
    return _buildQuestionCard(
      title: 'Pre-existing Medical Conditions',
      subtitle: 'Select any diagnosed medical history (optional context):',
      icon: Icons.medical_services_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: const Text('Asthma'),
            selected: _controller.hasAsthma,
            selectedColor: AppTheme.primaryTeal.withAlpha(60),
            onSelected: _controller.toggleAsthma,
          ),
          FilterChip(
            label: const Text('COPD'),
            selected: _controller.hasCopd,
            selectedColor: AppTheme.primaryTeal.withAlpha(60),
            onSelected: _controller.toggleCopd,
          ),
          FilterChip(
            label: const Text('Hypertension'),
            selected: _controller.hasHypertension,
            selectedColor: AppTheme.primaryTeal.withAlpha(60),
            onSelected: _controller.toggleHypertension,
          ),
          FilterChip(
            label: const Text('Diabetes'),
            selected: _controller.hasDiabetes,
            selectedColor: AppTheme.primaryTeal.withAlpha(60),
            onSelected: _controller.toggleDiabetes,
          ),
          FilterChip(
            label: const Text('Heart Disease'),
            selected: _controller.hasHeartDisease,
            selectedColor: AppTheme.primaryTeal.withAlpha(60),
            onSelected: _controller.toggleHeartDisease,
          ),
          FilterChip(
            label: const Text('Past TB'),
            selected: _controller.hasTbHistory,
            selectedColor: AppTheme.primaryTeal.withAlpha(60),
            onSelected: _controller.toggleTbHistory,
          ),
        ],
      ),
    );
  }

  // ===================================================
  // REVIEW SCREEN
  // ===================================================
  Widget _buildReviewScreen(SwaasAiBleResult? bleResult) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryTeal.withAlpha(60)),
            ),
            child: const Row(
              children: [
                Icon(Icons.fact_check_outlined, color: AppTheme.primaryTeal, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REVIEW SCREENING INFORMATION',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight),
                      ),
                      Text(
                        'Verify all collected questionnaire responses and sensor readings before assessment.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. Patient Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Patient Demographics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryTeal)),
                  const Divider(color: Color(0xFF334155), height: 18),
                  _buildReviewRow('Full Name', widget.patient.name),
                  _buildReviewRow('Age / Gender', '${widget.patient.age} years • ${widget.patient.gender.name.toUpperCase()}'),
                  _buildReviewRow('Village / Locality', widget.patient.village.isNotEmpty ? widget.patient.village : 'N/A'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Sensor Observations Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sensor Observations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
                  const Divider(color: Color(0xFF334155), height: 18),
                  _buildReviewRow('SpO₂ (Pulse Oximetry)', bleResult?.formattedSpo2 ?? '--'),
                  _buildReviewRow('Raw Airflow Feature', bleResult?.formattedAirflow ?? '--'),
                  _buildReviewRow('Cough Signal', bleResult?.formattedCough ?? '--'),
                  _buildReviewRow('Heart Rate', '-- / Not Available in BLE packet'),
                  if (bleResult != null) _buildReviewRow('ESP32 Record ID', bleResult.id),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Questionnaire Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Questionnaire Responses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.accentIndigo)),
                      TextButton.icon(
                        onPressed: () => _controller.exitReviewMode(step: 0),
                        icon: const Icon(Icons.edit, size: 14, color: AppTheme.primaryTeal),
                        label: const Text('Edit', style: TextStyle(fontSize: 12, color: AppTheme.primaryTeal)),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155), height: 12),
                  _buildReviewRow('Smoking Status', _controller.smokingStatus),
                  if (_controller.isSmoker) ...[
                    _buildReviewRow('Years Smoked', '${_controller.yearsSmoked.toStringAsFixed(0)} years'),
                    _buildReviewRow('Cigarettes / Day', '${_controller.cigarettesPerDay} / day'),
                  ],
                  _buildReviewRow('Biomass Exposure', _controller.biomassExposure),
                  _buildReviewRow('Breathlessness', 'Grade ${_controller.breathlessness} (mMRC)'),
                  _buildReviewRow('Chronic Cough', _controller.chronicCough ? 'Yes' : 'No'),
                  _buildReviewRow('Phlegm / Sputum', _controller.phlegm ? 'Yes' : 'No'),
                  _buildReviewRow('Wheezing', _controller.wheezing ? 'Yes' : 'No'),
                  _buildReviewRow('Recurrent Problems', _controller.recurrentRespiratoryProblems ? 'Yes' : 'No'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textLight),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildQuestionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.primaryTeal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4)),
            const Divider(color: Color(0xFF334155), height: 28),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryTeal.withAlpha(35) : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryTeal : Colors.white.withAlpha(15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primaryTeal : AppTheme.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryTeal),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppTheme.textLight : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryTeal.withAlpha(40) : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryTeal : Colors.white.withAlpha(15),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.primaryTeal : AppTheme.textMuted,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.textLight : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isReview, int step) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: Colors.white.withAlpha(15))),
      ),
      child: isReview
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _controller.exitReviewMode(step: 0),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.textMuted),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Edit Questionnaire', style: TextStyle(color: AppTheme.textLight)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _onRunAssessment,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Continue to Assessment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (step > 0)
                  OutlinedButton.icon(
                    onPressed: _controller.previousStep,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.textMuted),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                ElevatedButton.icon(
                  onPressed: _controller.nextStep,
                  icon: Icon(step == QuestionnaireController.totalQuestions - 1 ? Icons.fact_check : Icons.arrow_forward, size: 16),
                  label: Text(step == QuestionnaireController.totalQuestions - 1 ? 'Review' : 'Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
    );
  }
}
