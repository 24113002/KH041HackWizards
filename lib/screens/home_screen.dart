import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/current_screening_controller.dart';
import '../controllers/patient_provider.dart';
import '../controllers/screening_history_controller.dart';
import '../models/patient_model.dart';
import '../models/screening_result_model.dart';
import '../theme/app_theme.dart';
import '../widgets/ble_scan_sheet.dart';
import '../widgets/ble_status_card.dart';
import '../widgets/patient_select_dialog.dart';
import 'history_screen.dart';
import 'live_screening_screen.dart';
import 'patients_screen.dart';
import 'screening_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PatientProvider>().loadPatients();
        context.read<ScreeningHistoryController>().loadHistory();
      }
    });
  }

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BleScanSheet(),
    );
  }

  Future<void> _startNewScreening() async {
    final patient = await showDialog<Patient>(
      context: context,
      builder: (_) => const PatientSelectDialog(),
    );

    if (patient != null && mounted) {
      context.read<CurrentScreeningController>().startNewSession(patient);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LiveScreeningScreen(patient: patient)),
      ).then((_) {
        if (mounted) {
          context.read<ScreeningHistoryController>().loadHistory();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientProv = context.watch<PatientProvider>();
    final historyCtrl = context.watch<ScreeningHistoryController>();

    final totalPatients = patientProv.patients.length;
    final totalScreenings = historyCtrl.history.length;
    final recentScreenings = historyCtrl.history.take(5).toList();

    int lowRiskCount = 0;
    int highCriticalCount = 0;
    for (final s in historyCtrl.history) {
      final r = s.riskResult.riskLevel;
      if (r == RiskLevel.low) {
        lowRiskCount++;
      } else if (r == RiskLevel.high || r == RiskLevel.critical) {
        highCriticalCount++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.monitor_heart, color: AppTheme.primaryTeal, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SWASTHAI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppTheme.textLight),
                ),
                Text(
                  'Offline COPD Risk Screener',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined, color: AppTheme.textLight),
            tooltip: 'Patients Directory',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: AppTheme.textLight),
            tooltip: 'Screening History',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await patientProv.loadPatients();
          await historyCtrl.loadHistory();
        },
        color: AppTheme.primaryTeal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OFFLINE MODE Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryTeal.withAlpha(50)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.offline_pin, size: 16, color: AppTheme.primaryTeal),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'OFFLINE MODE: All patient records and screening sessions are stored locally.',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                      ),
                    ),
                  ],
                ),
              ),

              // BLE Status & Simulator Switch Card
              BleStatusCard(onOpenScanner: _openScanner),
              const SizedBox(height: 16),

              // Hero CTA Card: Start Screening
              InkWell(
                onTap: _startNewScreening,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF0F766E), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryTeal.withAlpha(50),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start New Screening',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Vitals • Breathing Test • Cough Test • Questionnaire',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Overview Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                  TextButton.icon(
                    icon: const Icon(Icons.folder_shared_outlined, size: 16, color: AppTheme.primaryTeal),
                    label: const Text('Patient Directory', style: TextStyle(color: AppTheme.primaryTeal, fontSize: 13)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientsScreen()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatCard('Registered Patients', '$totalPatients', Icons.people_outline, AppTheme.primaryBlue),
                  const SizedBox(width: 10),
                  _buildStatCard('Total Screenings', '$totalScreenings', Icons.assignment_outlined, AppTheme.primaryTeal),
                  const SizedBox(width: 10),
                  _buildStatCard('Low Risk', '$lowRiskCount', Icons.check_circle_outline, AppTheme.riskLow),
                  const SizedBox(width: 10),
                  _buildStatCard('High Risk', '$highCriticalCount', Icons.warning_amber_outlined, AppTheme.riskCritical),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Screenings Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Screenings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                    },
                    child: const Text('View All History', style: TextStyle(color: AppTheme.primaryTeal, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (historyCtrl.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppTheme.primaryTeal),
                  ),
                )
              else if (recentScreenings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.assignment_outlined, size: 40, color: AppTheme.textMuted.withAlpha(80)),
                      const SizedBox(height: 10),
                      const Text('No screenings performed yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap "Start New Screening" to register a patient and begin triage.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ...recentScreenings.map((s) {
                  final p = s.patient;
                  final r = s.riskResult;
                  Color color;
                  switch (r.riskLevel) {
                    case RiskLevel.low:
                      color = AppTheme.riskLow;
                      break;
                    case RiskLevel.moderate:
                      color = AppTheme.riskModerate;
                      break;
                    case RiskLevel.high:
                      color = AppTheme.riskHigh;
                      break;
                    case RiskLevel.critical:
                      color = AppTheme.riskCritical;
                      break;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: color.withAlpha(35),
                        child: Icon(Icons.person, color: color, size: 20),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              p?.fullName ?? p?.name ?? 'Unknown Patient',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withAlpha(40),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r.riskCategory.toUpperCase(),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 3),
                          Text(
                            'SpO₂: ${s.vitals.spo2 > 0 ? '${s.vitals.spo2}%' : '--'} • Airflow: ${s.sensorReading?.pressure != null ? '${(s.sensorReading!.pressure! * 10000).toInt()}' : '--'} • ${DateFormat('dd MMM, HH:mm').format(s.startedAt)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: AppTheme.textMuted),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScreeningDetailsScreen(session: s),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted), maxLines: 1),
          ],
        ),
      ),
    );
  }
}
