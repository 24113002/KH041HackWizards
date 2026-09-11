import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/current_screening_controller.dart';
import '../controllers/screening_history_controller.dart';
import '../models/patient_model.dart';
import '../models/questionnaire_model.dart';
import '../models/screening_result_model.dart';
import '../models/screening_session_model.dart';
import '../models/sensor_data_model.dart';
import '../models/swaas_ai_ble_result.dart';
import '../repositories/screening_repository.dart';
import '../theme/app_theme.dart';
import 'screening_details_screen.dart';

class ScreeningResultScreen extends StatefulWidget {
  final Patient patient;
  final VitalsReading vitals;
  final SpirometrySummary spirometry;
  final AcousticSummary acoustic;
  final QuestionnaireResponse questionnaire;
  final RiskResult riskResult;
  final SwaasAiBleResult? bleResult;

  const ScreeningResultScreen({
    super.key,
    required this.patient,
    required this.vitals,
    required this.spirometry,
    required this.acoustic,
    required this.questionnaire,
    required this.riskResult,
    this.bleResult,
  });

  @override
  State<ScreeningResultScreen> createState() => _ScreeningResultScreenState();
}

class _ScreeningResultScreenState extends State<ScreeningResultScreen> {
  final _notesController = TextEditingController();
  bool _isSaved = false;
  bool _isSaving = false;

  bool get _isIncomplete =>
      widget.bleResult?.isIncomplete == true ||
      widget.riskResult.riskCategory.toLowerCase().contains('incomplete');

  Color get _riskColor {
    if (_isIncomplete) return AppTheme.riskModerate;
    final cat = widget.bleResult?.status.label ?? widget.riskResult.riskCategory;
    final lower = cat.toLowerCase();
    if (lower.contains('critical') || lower.contains('urgent') || lower.contains('high')) {
      return lower.contains('critical') ? AppTheme.riskCritical : AppTheme.riskHigh;
    }
    if (lower.contains('moderate')) {
      return AppTheme.riskModerate;
    }
    return AppTheme.riskLow;
  }

  Future<void> _saveScreening() async {
    if (_isSaving || _isSaved) return;
    setState(() => _isSaving = true);

    final screeningController = context.read<CurrentScreeningController>();
    final screeningRepo = context.read<ScreeningRepository>();
    final historyController = context.read<ScreeningHistoryController>();

    final sessionId = screeningController.session?.id ?? 'sess_${widget.patient.id}_${DateTime.now().millisecondsSinceEpoch}';

    final session = ScreeningSession(
      id: sessionId,
      patientId: widget.patient.id,
      startedAt: widget.bleResult?.receivedAt ?? screeningController.session?.startedAt ?? DateTime.now(),
      completedAt: DateTime.now(),
      status: _isIncomplete ? ScreeningStatus.cancelled : ScreeningStatus.completed,
      riskScore: _isIncomplete ? null : (widget.bleResult?.risk ?? widget.riskResult.riskScore),
      riskCategory: _isIncomplete ? 'Incomplete' : (widget.bleResult?.status.label ?? widget.riskResult.riskCategory),
      patient: widget.patient,
      vitals: widget.vitals,
      spirometry: widget.spirometry,
      acoustic: widget.acoustic,
      questionnaire: widget.questionnaire,
      riskResult: widget.riskResult,
      clinicalNotes: _notesController.text.trim(),
    );

    try {
      await screeningRepo.createScreening(session);
      await historyController.loadHistory();

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSaved = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Screening session saved successfully to offline database!'),
            backgroundColor: AppTheme.riskLow,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving screening session: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save screening session: $e'),
            backgroundColor: AppTheme.riskCritical,
          ),
        );
      }
    }
  }

  void _navigateToDetails() {
    final screeningController = context.read<CurrentScreeningController>();
    final sessionId = screeningController.session?.id ?? 'sess_${widget.patient.id}';

    final session = ScreeningSession(
      id: sessionId,
      patientId: widget.patient.id,
      startedAt: widget.bleResult?.receivedAt ?? screeningController.session?.startedAt ?? DateTime.now(),
      completedAt: DateTime.now(),
      status: _isIncomplete ? ScreeningStatus.cancelled : ScreeningStatus.completed,
      riskScore: _isIncomplete ? null : (widget.bleResult?.risk ?? widget.riskResult.riskScore),
      riskCategory: _isIncomplete ? 'Incomplete' : (widget.bleResult?.status.label ?? widget.riskResult.riskCategory),
      patient: widget.patient,
      vitals: widget.vitals,
      spirometry: widget.spirometry,
      acoustic: widget.acoustic,
      questionnaire: widget.questionnaire,
      riskResult: widget.riskResult,
      clinicalNotes: _notesController.text.trim(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScreeningDetailsScreen(session: session),
      ),
    );
  }

  void _shareReport() {
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
    final r = widget.riskResult;
    final p = widget.patient;
    final ble = widget.bleResult;

    final buffer = StringBuffer();
    buffer.writeln('=== SWASTHAI RESPIRATORY SCREENING REPORT ===');
    buffer.writeln('Date/Time: $dateStr');
    buffer.writeln('Patient: ${p.name} | Age: ${p.age} | Sex: ${p.gender.name.toUpperCase()}');
    buffer.writeln('Village/Location: ${p.village.isNotEmpty ? p.village : 'N/A'}');
    buffer.writeln('------------------------------------------');
    if (_isIncomplete) {
      buffer.writeln('STATUS: SCREENING INCOMPLETE');
      buffer.writeln('Risk Score: Not Available (-- / 100)');
      buffer.writeln('Missing data: One or more sensor measurements were unavailable.');
    } else {
      buffer.writeln('RISK CATEGORY: ${ble?.status.label ?? r.riskCategory}');
      buffer.writeln('RISK SCORE: ${ble?.risk ?? r.riskScore} / 100');
    }
    buffer.writeln('------------------------------------------');
    buffer.writeln('SCREENING OBSERVATIONS:');
    buffer.writeln('• SpO₂: ${ble?.formattedSpo2 ?? '${widget.vitals.spo2}%'}');
    buffer.writeln('• Raw Airflow Feature: ${ble?.formattedAirflow ?? '--'} (raw sensor-derived value)');
    buffer.writeln('• Cough Signal: ${ble?.formattedCough ?? '--'} (digital audio feature)');
    buffer.writeln('• Heart Rate: Not Available in BLE packet');
    buffer.writeln('------------------------------------------');
    buffer.writeln('QUESTIONNAIRE HIGHLIGHTS:');
    buffer.writeln('• Smoking: ${widget.questionnaire.smokingStatus}${widget.questionnaire.yearsSmoked > 0 ? ' (${widget.questionnaire.yearsSmoked.toStringAsFixed(0)} yrs)' : ''}');
    buffer.writeln('• Biomass Exposure: ${widget.questionnaire.biomassExposure}');
    buffer.writeln('• Breathlessness: Grade ${widget.questionnaire.breathlessness} (mMRC)');
    buffer.writeln('• Chronic Cough: ${widget.questionnaire.chronicCough ? 'Yes' : 'No'}');
    buffer.writeln('• Wheezing: ${widget.questionnaire.wheezing ? 'Yes' : 'No'}');
    buffer.writeln('------------------------------------------');
    buffer.writeln('CONTRIBUTING FACTORS:');
    for (final factor in r.contributingFactors) {
      buffer.writeln('• $factor');
    }
    buffer.writeln('------------------------------------------');
    buffer.writeln('RECOMMENDATION:');
    for (final rec in r.recommendations) {
      buffer.writeln('• $rec');
    }
    if (_notesController.text.isNotEmpty) {
      buffer.writeln('------------------------------------------');
      buffer.writeln('CLINICAL NOTES: ${_notesController.text.trim()}');
    }
    buffer.writeln('==========================================');
    buffer.writeln('DISCLAIMER: ${RiskResult.medicalDisclaimer}');
    buffer.writeln('Generated by SwasthAI Offline Point-of-Care System');

    // ignore: deprecated_member_use
    Share.share(buffer.toString(), subject: 'SwasthAI Screening Report - ${p.name}');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.riskResult;
    final p = widget.patient;
    final ble = widget.bleResult;
    final dateStr = DateFormat('dd MMM yyyy • hh:mm a').format(DateTime.now());

    final statusText = _isIncomplete ? 'INCOMPLETE' : (ble?.status.label.toUpperCase() ?? r.riskCategory.toUpperCase());
    final scoreDisplay = _isIncomplete ? '-- / 100' : '${ble?.risk ?? r.riskScore} / 100';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.textLight),
            tooltip: 'Share Report',
            onPressed: _shareReport,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Patient & Timestamp Bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryTeal.withAlpha(30),
                    child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                        style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textLight)),
                        Text('${p.age} yrs • ${p.gender.name.toUpperCase()} • Screening: $dateStr',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Main Risk Score Hero Card
            if (_isIncomplete)
              _buildIncompleteBanner(ble)
            else
              _buildCompleteHeroCard(statusText, scoreDisplay, ble),

            const SizedBox(height: 16),

            // 3. Screening Observations Card
            _buildObservationsCard(ble),
            const SizedBox(height: 16),

            // 4. Contributing Factors Card
            _buildContributingFactorsCard(r),
            const SizedBox(height: 16),

            // 5. Clinical Recommendation Card
            _buildRecommendationCard(r),
            const SizedBox(height: 16),

            // 6. Clinical Notes Field
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Clinical Notes (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textLight)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Add healthcare worker observations or referral notes...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 7. Medical Safety Disclaimer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(15)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.textMuted, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IMPORTANT MEDICAL DISCLAIMER',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                        SizedBox(height: 4),
                        Text(
                          RiskResult.medicalDisclaimer,
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 8. Bottom Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _navigateToDetails,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.primaryTeal),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaved ? null : _saveScreening,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_isSaved ? Icons.check : Icons.save_outlined, size: 18),
                    label: Text(_isSaved ? 'Saved' : 'Save Screening'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSaved ? AppTheme.riskLow : AppTheme.primaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildIncompleteBanner(SwaasAiBleResult? ble) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.riskModerate.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.riskModerate.withAlpha(90), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.riskModerate, size: 26),
              SizedBox(width: 10),
              Text(
                'SCREENING INCOMPLETE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Some required sensor measurements were not available during physical testing. A risk score cannot be accurately calculated from missing data.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'Please repeat the required measurement or proceed according to the healthcare worker\'s protocol.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteHeroCard(String statusText, String scoreDisplay, SwaasAiBleResult? ble) {
    final score = ble?.risk ?? widget.riskResult.riskScore;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_riskColor.withAlpha(45), AppTheme.surfaceElevated],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _riskColor.withAlpha(90), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _riskColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                ),
              ),
              Text(
                'Risk Score: $scoreDisplay',
                style: TextStyle(fontWeight: FontWeight.bold, color: _riskColor, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Progress bar for score visualization
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (score / 100.0).clamp(0.0, 1.0),
              backgroundColor: AppTheme.surfaceDark,
              valueColor: AlwaysStoppedAnimation<Color>(_riskColor),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Screening assessment indicates ${statusText.toLowerCase()} priority.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.textLight, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationsCard(SwaasAiBleResult? ble) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sensors, color: AppTheme.primaryTeal, size: 20),
                SizedBox(width: 8),
                Text('Screening Observations',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 20),
            _buildObservationRow(
              icon: Icons.bloodtype,
              label: 'SpO₂ (Blood Oxygen)',
              value: ble != null ? ble.formattedSpo2 : '${widget.vitals.spo2}%',
              subtext: ble?.spo2 != null ? 'Pulse oximetry' : 'Not Available (NA)',
              color: AppTheme.primaryTeal,
            ),
            const SizedBox(height: 10),
            _buildObservationRow(
              icon: Icons.air,
              label: 'Raw Airflow Feature',
              value: ble?.formattedAirflow ?? '--',
              subtext: 'Raw sensor-derived value; not calibrated clinical airflow.',
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(height: 10),
            _buildObservationRow(
              icon: Icons.graphic_eq,
              label: 'Cough Signal',
              value: ble?.formattedCough ?? '--',
              subtext: 'Digital audio feature; not a clinically validated cough severity score.',
              color: AppTheme.accentIndigo,
            ),
            const SizedBox(height: 10),
            _buildObservationRow(
              icon: Icons.favorite_border,
              label: 'Heart Rate',
              value: '--',
              subtext: 'Not Available in BLE packet',
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObservationRow({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
                    Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtext, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributingFactorsCard(RiskResult r) {
    final factors = r.contributingFactors.isNotEmpty
        ? r.contributingFactors
        : const ['Contributing factors not available.'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.list_alt, color: AppTheme.primaryBlue, size: 20),
                SizedBox(width: 8),
                Text('Contributing Factors',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 20),
            ...factors.map((factor) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: AppTheme.primaryTeal, fontSize: 14, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(factor, style: const TextStyle(fontSize: 13, color: AppTheme.textLight, height: 1.3)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(RiskResult r) {
    final recs = r.recommendations.isNotEmpty ? r.recommendations : [r.recommendation];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.recommend, color: AppTheme.riskLow, size: 20),
                SizedBox(width: 8),
                Text('Recommendation',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 20),
            ...recs.map((rec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right, color: AppTheme.riskLow, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(rec, style: const TextStyle(fontSize: 13, color: AppTheme.textLight, height: 1.4)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
