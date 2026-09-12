import 'package:flutter/material.dart';
import '../engine/risk_assessment_engine.dart';
import '../models/patient_model.dart';
import '../models/questionnaire_model.dart';
import '../models/sensor_data_model.dart';
import '../theme/app_theme.dart';
import 'screening_result_screen.dart';

class QuestionnaireScreen extends StatefulWidget {
  final Patient patient;
  final VitalsReading vitals;
  final SpirometrySummary spirometry;
  final AcousticSummary acoustic;

  const QuestionnaireScreen({
    super.key,
    required this.patient,
    required this.vitals,
    required this.spirometry,
    required this.acoustic,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  int _mmrcGrade = 1;
  int _coughFrequency = 1;
  int _sputumType = 0;
  int _wheezeSeverity = 0;
  int _chestDiscomfort = 0;
  int _smokingStatus = 0;
  double _packYears = 0.0;
  int _biomassExposure = 0;

  bool _hasAsthma = false;
  bool _hasCopd = false;
  bool _hasHypertension = false;
  bool _hasDiabetes = false;
  bool _hasHeartDisease = false;
  bool _hasTbHistory = false;

  void _runRiskAssessment() {
    final response = QuestionnaireResponse(
      mmrcDyspneaGrade: _mmrcGrade,
      coughFrequency: _coughFrequency,
      sputumType: _sputumType,
      wheezeSeverity: _wheezeSeverity,
      chestDiscomfort: _chestDiscomfort,
      smokingStatus: _smokingStatus,
      packYears: _packYears,
      biomassExposure: _biomassExposure,
      hasAsthma: _hasAsthma,
      hasCopd: _hasCopd,
      hasHypertension: _hasHypertension,
      hasDiabetes: _hasDiabetes,
      hasHeartDisease: _hasHeartDisease,
      hasTbHistory: _hasTbHistory,
    );

    final result = RiskAssessmentEngine.evaluate(
      patient: widget.patient,
      vitals: widget.vitals,
      spirometry: widget.spirometry,
      acoustic: widget.acoustic,
      questionnaire: response,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreeningResultScreen(
          patient: widget.patient,
          vitals: widget.vitals,
          spirometry: widget.spirometry,
          acoustic: widget.acoustic,
          questionnaire: response,
          riskResult: result,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Questionnaire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient summary pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: AppTheme.primaryTeal, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.patient.name} • ${widget.patient.age} yrs • SpO2: ${widget.vitals.spo2}% • FEV1/FVC: ${(widget.spirometry.fev1FvcRatio * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textLight, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 1. Shortness of Breath (mMRC Scale)
            _buildSectionCard(
              title: 'Shortness of Breath (mMRC Dyspnea Scale)',
              icon: Icons.air,
              child: Column(
                children: [
                  _buildOptionTile(
                    groupVal: _mmrcGrade,
                    val: 0,
                    label: 'Grade 0: Only with strenuous physical exercise',
                    onChanged: (v) => setState(() => _mmrcGrade = v!),
                  ),
                  _buildOptionTile(
                    groupVal: _mmrcGrade,
                    val: 1,
                    label: 'Grade 1: Hurrying on level ground or walking up slight hill',
                    onChanged: (v) => setState(() => _mmrcGrade = v!),
                  ),
                  _buildOptionTile(
                    groupVal: _mmrcGrade,
                    val: 2,
                    label: 'Grade 2: Walks slower than peers on level or stops for breath',
                    onChanged: (v) => setState(() => _mmrcGrade = v!),
                  ),
                  _buildOptionTile(
                    groupVal: _mmrcGrade,
                    val: 3,
                    label: 'Grade 3: Stops for breath after walking ~100m or few minutes',
                    onChanged: (v) => setState(() => _mmrcGrade = v!),
                  ),
                  _buildOptionTile(
                    groupVal: _mmrcGrade,
                    val: 4,
                    label: 'Grade 4: Too breathless to leave house or when dressing',
                    onChanged: (v) => setState(() => _mmrcGrade = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Cough & Sputum
            _buildSectionCard(
              title: 'Cough & Sputum Symptoms',
              icon: Icons.masks_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cough Frequency:', style: TextStyle(fontSize: 13, color: AppTheme.textLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip('None', 0, _coughFrequency, (v) => setState(() => _coughFrequency = v)),
                      _buildChip('Occasional', 1, _coughFrequency, (v) => setState(() => _coughFrequency = v)),
                      _buildChip('Daily', 2, _coughFrequency, (v) => setState(() => _coughFrequency = v)),
                      _buildChip('Chronic (>3 wks)', 3, _coughFrequency, (v) => setState(() => _coughFrequency = v)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Sputum / Phlegm:', style: TextStyle(fontSize: 13, color: AppTheme.textLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip('None', 0, _sputumType, (v) => setState(() => _sputumType = v)),
                      _buildChip('Clear / White', 1, _sputumType, (v) => setState(() => _sputumType = v)),
                      _buildChip('Yellow / Green', 2, _sputumType, (v) => setState(() => _sputumType = v)),
                      _buildChip('Blood-streaked', 3, _sputumType, (v) => setState(() => _sputumType = v)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Wheeze & Chest Tightness
            _buildSectionCard(
              title: 'Auscultation & Chest Symptoms',
              icon: Icons.hearing,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Wheezing / Whistling Chest Sound:', style: TextStyle(fontSize: 13, color: AppTheme.textLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip('Never', 0, _wheezeSeverity, (v) => setState(() => _wheezeSeverity = v)),
                      _buildChip('Triggered by cold/dust', 1, _wheezeSeverity, (v) => setState(() => _wheezeSeverity = v)),
                      _buildChip('Frequent / Nightly', 2, _wheezeSeverity, (v) => setState(() => _wheezeSeverity = v)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Chest Tightness / Discomfort:', style: TextStyle(fontSize: 13, color: AppTheme.textLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip('None', 0, _chestDiscomfort, (v) => setState(() => _chestDiscomfort = v)),
                      _buildChip('On exertion', 1, _chestDiscomfort, (v) => setState(() => _chestDiscomfort = v)),
                      _buildChip('At rest / Severe', 2, _chestDiscomfort, (v) => setState(() => _chestDiscomfort = v)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Exposure & Smoking
            _buildSectionCard(
              title: 'Environmental Exposure & Tobacco',
              icon: Icons.smoke_free,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tobacco Smoking Status:', style: TextStyle(fontSize: 13, color: AppTheme.textLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip('Non-smoker', 0, _smokingStatus, (v) => setState(() => _smokingStatus = v)),
                      _buildChip('Former smoker', 1, _smokingStatus, (v) => setState(() => _smokingStatus = v)),
                      _buildChip('Current smoker', 2, _smokingStatus, (v) => setState(() => _smokingStatus = v)),
                    ],
                  ),
                  if (_smokingStatus > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Pack-Years:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        Text('${_packYears.toStringAsFixed(0)} pack-years', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                      ],
                    ),
                    Slider(
                      value: _packYears,
                      min: 0,
                      max: 60,
                      divisions: 12,
                      activeColor: AppTheme.primaryTeal,
                      onChanged: (v) => setState(() => _packYears = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text('Biomass / Chulha / Solid Fuel Smoke Exposure:', style: TextStyle(fontSize: 13, color: AppTheme.textLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip('None', 0, _biomassExposure, (v) => setState(() => _biomassExposure = v)),
                      _buildChip('Occasional', 1, _biomassExposure, (v) => setState(() => _biomassExposure = v)),
                      _buildChip('Daily / High', 2, _biomassExposure, (v) => setState(() => _biomassExposure = v)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Pre-existing Conditions
            _buildSectionCard(
              title: 'Pre-existing Medical Conditions',
              icon: Icons.health_and_safety_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Asthma'),
                    selected: _hasAsthma,
                    selectedColor: AppTheme.primaryTeal.withAlpha(50),
                    onSelected: (v) => setState(() => _hasAsthma = v),
                  ),
                  FilterChip(
                    label: const Text('COPD'),
                    selected: _hasCopd,
                    selectedColor: AppTheme.primaryTeal.withAlpha(50),
                    onSelected: (v) => setState(() => _hasCopd = v),
                  ),
                  FilterChip(
                    label: const Text('Hypertension'),
                    selected: _hasHypertension,
                    selectedColor: AppTheme.primaryTeal.withAlpha(50),
                    onSelected: (v) => setState(() => _hasHypertension = v),
                  ),
                  FilterChip(
                    label: const Text('Diabetes'),
                    selected: _hasDiabetes,
                    selectedColor: AppTheme.primaryTeal.withAlpha(50),
                    onSelected: (v) => setState(() => _hasDiabetes = v),
                  ),
                  FilterChip(
                    label: const Text('Heart Disease'),
                    selected: _hasHeartDisease,
                    selectedColor: AppTheme.primaryTeal.withAlpha(50),
                    onSelected: (v) => setState(() => _hasHeartDisease = v),
                  ),
                  FilterChip(
                    label: const Text('Past Tuberculosis (TB)'),
                    selected: _hasTbHistory,
                    selectedColor: AppTheme.primaryTeal.withAlpha(50),
                    onSelected: (v) => setState(() => _hasTbHistory = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _runRiskAssessment,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Generate Offline Risk Assessment', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      color: AppTheme.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryTeal, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required int groupVal,
    required int val,
    required String label,
    required ValueChanged<int?> onChanged,
  }) {
    final isSelected = (groupVal == val);
    return InkWell(
      onTap: () => onChanged(val),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
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
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? AppTheme.textLight : AppTheme.textMuted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, int value, int current, ValueChanged<int> onSelect) {
    final isSelected = (value == current);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryTeal.withAlpha(60),
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : AppTheme.textMuted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => onSelect(value),
    );
  }
}
