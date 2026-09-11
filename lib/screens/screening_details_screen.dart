import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/screening_history_controller.dart';
import '../models/screening_result_model.dart';
import '../models/screening_session_model.dart';
import '../repositories/screening_repository.dart';
import '../theme/app_theme.dart';

class ScreeningDetailsScreen extends StatelessWidget {
  final ScreeningSession session;

  const ScreeningDetailsScreen({super.key, required this.session});

  bool get _isIncomplete =>
      session.status == ScreeningStatus.incomplete ||
      (session.riskCategory ?? session.riskResult.riskCategory).toLowerCase().contains('incomplete');

  Color _getRiskColor(String category) {
    if (_isIncomplete) return AppTheme.riskModerate;
    final lower = category.toLowerCase();
    if (lower.contains('critical') || lower.contains('urgent')) return AppTheme.riskCritical;
    if (lower.contains('high')) return AppTheme.riskHigh;
    if (lower.contains('moderate')) return AppTheme.riskModerate;
    return AppTheme.riskLow;
  }

  void _shareReport() {
    final p = session.patient;
    final r = session.riskResult;
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(session.startedAt);
    final recordId = session.sensorReading?.id.isNotEmpty == true ? session.sensorReading!.id : session.id;

    final buffer = StringBuffer();
    buffer.writeln('=== SWASTHAI CLINICAL SCREENING REPORT ===');
    buffer.writeln('Screening ID: $recordId');
    buffer.writeln('Date/Time: $dateStr');
    if (p != null) {
      buffer.writeln('Patient: ${p.fullName} | Age: ${p.age} | Sex: ${p.gender.name.toUpperCase()}');
      buffer.writeln('Village: ${p.village.isNotEmpty ? p.village : 'N/A'} | Occupation: ${p.occupation.isNotEmpty ? p.occupation : 'N/A'}');
      buffer.writeln('Smoking: ${session.questionnaire.smokingStatus}');
    }
    buffer.writeln('------------------------------------------');
    buffer.writeln('STATUS: ${session.status.label.toUpperCase()}');
    buffer.writeln('RISK CATEGORY: ${session.riskCategory ?? r.riskCategory}');
    buffer.writeln('RISK SCORE: ${session.riskScore != null ? '${session.riskScore} / 100' : '-- / 100'}');
    buffer.writeln('------------------------------------------');
    buffer.writeln('SENSOR OBSERVATIONS:');
    buffer.writeln('• SpO₂: ${session.vitals.spo2 > 0 ? '${session.vitals.spo2}%' : 'Not recorded / NA'}');
    buffer.writeln('• Raw Airflow Feature: ${session.sensorReading?.pressure != null ? '${(session.sensorReading!.pressure! * 10000).toInt()}' : 'Not recorded / NA'} (raw sensor value)');
    buffer.writeln('• Cough Signal: ${session.sensorReading?.coughActivity != null ? '${(session.sensorReading!.coughActivity! * 2000).toInt()}' : (session.acoustic.coughCount > 0 ? '${session.acoustic.coughCount}' : 'Not recorded / NA')} (digital audio feature)');
    buffer.writeln('• Heart Rate: Not Available in BLE packet');
    buffer.writeln('------------------------------------------');
    buffer.writeln('QUESTIONNAIRE SUMMARY:');
    buffer.writeln('• Smoking Status: ${session.questionnaire.smokingStatus}');
    if (session.questionnaire.yearsSmoked > 0) {
      buffer.writeln('• Years Smoked: ${session.questionnaire.yearsSmoked.toStringAsFixed(0)} yrs (${session.questionnaire.cigarettesPerDay} cigs/day)');
    }
    buffer.writeln('• Biomass Exposure: ${session.questionnaire.biomassExposure}');
    buffer.writeln('• Dyspnea mMRC Grade: ${session.questionnaire.breathlessness}');
    buffer.writeln('• Chronic Cough: ${session.questionnaire.chronicCough ? 'Yes' : 'No'}');
    buffer.writeln('• Phlegm: ${session.questionnaire.phlegm ? 'Yes' : 'No'}');
    buffer.writeln('• Wheezing: ${session.questionnaire.wheezing ? 'Yes' : 'No'}');
    buffer.writeln('• Recurrent Problems: ${session.questionnaire.recurrentRespiratoryProblems ? 'Yes' : 'No'}');
    buffer.writeln('------------------------------------------');
    buffer.writeln('CONTRIBUTING FACTORS:');
    for (final factor in r.contributingFactors) {
      buffer.writeln('• $factor');
    }
    buffer.writeln('------------------------------------------');
    buffer.writeln('RECOMMENDATION: ${r.recommendation}');
    buffer.writeln('------------------------------------------');
    buffer.writeln('DISCLAIMER: ${RiskResult.medicalDisclaimer}');
    buffer.writeln('==========================================');

    // ignore: deprecated_member_use
    Share.share(buffer.toString(), subject: 'SwasthAI Screening Report - ${p?.fullName ?? 'Patient'}');
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final patientName = session.patient?.fullName ?? session.patient?.name ?? 'Patient';
    final screeningId = session.sensorReading?.id.isNotEmpty == true ? session.sensorReading!.id : session.id;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.riskCritical),
            SizedBox(width: 10),
            Text('Delete Screening Record?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete screening record ($screeningId) for $patientName?',
              style: const TextStyle(color: AppTheme.textLight, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              '• Patient profile will remain safe.\n• Only this screening session will be removed.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.riskCritical),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final repo = context.read<ScreeningRepository>();
      await repo.deleteScreening(session.id);
      if (context.mounted) {
        context.read<ScreeningHistoryController>().loadHistory();
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = session.patient;
    final r = session.riskResult;
    final category = session.riskCategory ?? r.riskCategory;
    final scoreText = _isIncomplete ? '-- / 100' : (session.riskScore != null ? '${session.riskScore} / 100' : '${r.riskScore} / 100');
    final color = _getRiskColor(category);
    final dateFormatted = DateFormat('dd MMMM yyyy, HH:mm').format(session.startedAt);
    final recordId = session.sensorReading?.id.isNotEmpty == true ? session.sensorReading!.id : session.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screening Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.textLight),
            tooltip: 'Share Report',
            onPressed: _shareReport,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.riskCritical),
            tooltip: 'Delete Screening',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Status & Risk Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withAlpha(80), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isIncomplete ? 'INCOMPLETE' : category.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                        ),
                      ),
                      Text(
                        'Risk Score: $scoreText',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Screening ID: $recordId',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textLight),
                      ),
                      Text(
                        'Status: ${session.status.label}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Session Date: $dateFormatted',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Incomplete Warning Banner if applicable
            if (_isIncomplete) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.riskModerate.withAlpha(80)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.riskModerate, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'One or more sensor measurements were unavailable during this screening test. Please repeat testing if needed.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textLight, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 2. Patient Information Card
            const Text('Patient Information', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildDetailRow('Full Name', p?.fullName ?? p?.name ?? 'Not recorded'),
                    const SizedBox(height: 6),
                    _buildDetailRow('Patient ID', p?.id ?? session.patientId),
                    const SizedBox(height: 6),
                    _buildDetailRow('Age / Gender', p != null ? '${p.age} yrs • ${p.gender.name.toUpperCase()}' : 'Not recorded'),
                    const SizedBox(height: 6),
                    _buildDetailRow('Village / Location', p?.village.isNotEmpty == true ? p!.village : 'Not recorded'),
                    const SizedBox(height: 6),
                    _buildDetailRow('Occupation', p?.occupation.isNotEmpty == true ? p!.occupation : 'Not recorded'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Sensor Observations Card
            const Text('Screening Sensor Observations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSensorBox(
                  'SpO₂ Saturation',
                  session.vitals.spo2 > 0 ? '${session.vitals.spo2}%' : '--',
                  Icons.bloodtype,
                  AppTheme.primaryTeal,
                  subtext: session.vitals.spo2 > 0 ? 'Pulse oximetry' : 'Not recorded / NA',
                ),
                const SizedBox(width: 10),
                _buildSensorBox(
                  'Heart Rate',
                  '--',
                  Icons.favorite_border,
                  AppTheme.textMuted,
                  subtext: 'Not Available in BLE',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildSensorBox(
                  'Raw Airflow Feature',
                  session.sensorReading?.pressure != null
                      ? '${(session.sensorReading!.pressure! * 10000).toInt()}'
                      : '--',
                  Icons.air,
                  AppTheme.primaryBlue,
                  subtext: 'Raw sensor-derived value',
                ),
                const SizedBox(width: 10),
                _buildSensorBox(
                  'Cough Signal',
                  session.sensorReading?.coughActivity != null
                      ? '${(session.sensorReading!.coughActivity! * 2000).toInt()}'
                      : (session.acoustic.coughCount > 0 ? '${session.acoustic.coughCount}' : '--'),
                  Icons.graphic_eq,
                  AppTheme.accentIndigo,
                  subtext: 'Digital audio feature',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Questionnaire Summary Card
            const Text('Questionnaire Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildDetailRow('Smoking Status', session.questionnaire.smokingStatus),
                    if (session.questionnaire.yearsSmoked > 0) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow('Years Smoked', '${session.questionnaire.yearsSmoked.toStringAsFixed(0)} years (${session.questionnaire.cigarettesPerDay} cigs/day)'),
                    ],
                    const SizedBox(height: 6),
                    _buildDetailRow('Biomass Exposure', session.questionnaire.biomassExposure),
                    const SizedBox(height: 6),
                    _buildDetailRow('Dyspnea Grade (mMRC)', 'Grade ${session.questionnaire.breathlessness}'),
                    const SizedBox(height: 6),
                    _buildDetailRow('Chronic Cough', session.questionnaire.chronicCough ? 'Yes' : 'No'),
                    const SizedBox(height: 6),
                    _buildDetailRow('Phlegm / Sputum', session.questionnaire.phlegm ? 'Yes' : 'No'),
                    const SizedBox(height: 6),
                    _buildDetailRow('Wheezing', session.questionnaire.wheezing ? 'Yes' : 'No'),
                    const SizedBox(height: 6),
                    _buildDetailRow('Recurrent Problems', session.questionnaire.recurrentRespiratoryProblems ? 'Yes' : 'No'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Contributing Factors Card
            if (r.contributingFactors.isNotEmpty) ...[
              const Text('Contributing Factors', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: r.contributingFactors
                        .map((f) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                                  Expanded(child: Text(f, style: const TextStyle(fontSize: 13, color: AppTheme.textLight))),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 6. Recommendation Card
            const Text('Recommendation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.recommend, color: AppTheme.primaryTeal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.recommendation.isNotEmpty ? r.recommendation : 'Maintain healthy lifestyle and schedule periodic screening.',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textLight, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 7. Clinical Notes (if any)
            if (session.clinicalNotes.isNotEmpty) ...[
              const Text('Clinical Notes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.note_alt_outlined, color: AppTheme.textMuted, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(session.clinicalNotes, style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 8. Medical Disclaimer Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.riskModerate.withAlpha(50)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppTheme.riskModerate, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      RiskResult.medicalDisclaimer,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
      ],
    );
  }

  Widget _buildSensorBox(String title, String val, IconData icon, Color color, {String? subtext}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 6),
            Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
            if (subtext != null) ...[
              const SizedBox(height: 2),
              Text(subtext, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
