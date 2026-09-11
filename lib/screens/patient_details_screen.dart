import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/current_screening_controller.dart';
import '../controllers/patient_provider.dart';
import '../models/patient_model.dart';
import '../models/screening_session_model.dart';
import '../repositories/screening_repository.dart';
import '../theme/app_theme.dart';
import 'add_edit_patient_screen.dart';
import 'live_screening_screen.dart';
import 'screening_details_screen.dart';

class PatientDetailsScreen extends StatefulWidget {
  final Patient patient;

  const PatientDetailsScreen({super.key, required this.patient});

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  late Patient _patient;
  List<ScreeningSession> _patientScreenings = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
    _loadPatientHistory();
  }

  Future<void> _loadPatientHistory() async {
    setState(() => _isLoadingHistory = true);
    final repo = context.read<ScreeningRepository>();
    final list = await repo.getScreeningsForPatient(_patient.id);
    setState(() {
      _patientScreenings = list;
      _isLoadingHistory = false;
    });
  }

  void _startNewScreening() {
    final screeningCtrl = context.read<CurrentScreeningController>();
    screeningCtrl.startNewSession(_patient);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveScreeningScreen(patient: _patient),
      ),
    ).then((_) => _loadPatientHistory());
  }

  Future<void> _editPatient() async {
    final updated = await Navigator.push<Patient>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditPatientScreen(patient: _patient),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _patient = updated);
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.riskCritical),
            SizedBox(width: 10),
            Text('Delete Patient?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${_patient.fullName}?\n\nExisting screening records associated with this patient may also be affected.',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
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

    if (confirm == true && mounted) {
      final provider = context.read<PatientProvider>();
      final ok = await provider.deletePatient(_patient.id);
      if (mounted && ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient deleted successfully.')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_patient.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.textLight),
            tooltip: 'Edit Profile',
            onPressed: _editPatient,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.riskCritical),
            tooltip: 'Delete Patient',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Demographic Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.primaryTeal.withAlpha(40),
                          child: Text(
                            _patient.fullName.isNotEmpty ? _patient.fullName[0].toUpperCase() : 'P',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _patient.fullName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_patient.age} yrs • ${_patient.gender.name.toUpperCase()} • ${_patient.smokingStatus}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF334155), height: 24),
                    _buildInfoRow('Village / Location', _patient.village.isNotEmpty ? _patient.village : 'Not specified'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Occupation', _patient.occupation.isNotEmpty ? _patient.occupation : 'Not specified'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Physical Metrics', '${_patient.heightCm.toStringAsFixed(0)} cm • ${_patient.weightKg.toStringAsFixed(0)} kg (BMI: ${_patient.bmi.toStringAsFixed(1)})'),
                    if (_patient.medicalHistory.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Medical History', _patient.medicalHistory),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Start New Screening CTA Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startNewScreening,
                icon: const Icon(Icons.play_circle_fill, size: 22),
                label: const Text('Start New Screening Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Screening History Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Screening History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                Text(
                  '${_patientScreenings.length} total',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_isLoadingHistory)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
              )
            else if (_patientScreenings.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 36, color: AppTheme.textMuted),
                    SizedBox(height: 8),
                    Text('No previous screenings recorded for this patient.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
              )
            else
              ..._patientScreenings.map((s) {
                final r = s.riskResult;
                final category = s.riskCategory ?? r.riskCategory;
                final isInc = s.status == ScreeningStatus.incomplete || category.toLowerCase().contains('incomplete');
                
                Color color = AppTheme.riskLow;
                final lower = category.toLowerCase();
                if (isInc) {
                  color = AppTheme.riskModerate;
                } else if (lower.contains('high') || lower.contains('critical')) {
                  color = AppTheme.riskHigh;
                } else if (lower.contains('moderate')) {
                  color = AppTheme.riskModerate;
                }

                final scoreDisplay = isInc ? '--' : '${s.riskScore ?? r.riskScore} / 100';
                final spo2Display = s.vitals.spo2 > 0 ? '${s.vitals.spo2}%' : '--';
                final airflowDisplay = s.sensorReading?.pressure != null
                    ? '${(s.sensorReading!.pressure! * 10000).toInt()}'
                    : '--';
                final coughDisplay = s.sensorReading?.coughActivity != null
                    ? '${(s.sensorReading!.coughActivity! * 2000).toInt()}'
                    : (s.acoustic.coughCount > 0 ? '${s.acoustic.coughCount}' : '--');
                final dateFormatted = DateFormat('dd MMM yyyy, HH:mm').format(s.startedAt);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(35),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withAlpha(90)),
                          ),
                          child: Text(
                            isInc ? 'INCOMPLETE' : category.toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11),
                          ),
                        ),
                        Text(
                          'Score: $scoreDisplay',
                          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SpO₂: $spo2Display • Airflow: $airflowDisplay • Cough: $coughDisplay',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textLight, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormatted,
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScreeningDetailsScreen(
                            session: s.copyWith(patient: _patient),
                          ),
                        ),
                      ).then((_) => _loadPatientHistory());
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
        ),
      ],
    );
  }
}
