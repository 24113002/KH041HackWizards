import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../models/patient_model.dart';
import '../models/screening_result_model.dart';
import '../models/screening_session_model.dart';
import '../theme/app_theme.dart';
import '../widgets/ble_scan_sheet.dart';
import '../widgets/ble_status_card.dart';
import '../widgets/patient_select_dialog.dart';
import 'history_screen.dart';
import 'live_screening_screen.dart';
import 'screening_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, int> _stats = {
    'total_patients': 0,
    'total_screenings': 0,
    'low_risk': 0,
    'high_risk': 0,
    'critical_risk': 0,
  };
  List<ScreeningSession> _recentScreenings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final stats = await DatabaseHelper.instance.getDashboardStats();
    final recent = await DatabaseHelper.instance.getAllScreenings(limit: 5);
    setState(() {
      _stats = stats;
      _recentScreenings = recent;
      _isLoading = false;
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LiveScreeningScreen(patient: patient)),
      ).then((_) => _refreshData());
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalScreened = _stats['total_screenings'] ?? 0;
    final lowRisk = _stats['low_risk'] ?? 0;
    final highCritical = (_stats['high_risk'] ?? 0) + (_stats['critical_risk'] ?? 0);

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
                  'Point-of-Care Health Triage',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppTheme.textLight),
            tooltip: 'Screening History',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))
                  .then((_) => _refreshData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textLight),
            tooltip: 'Refresh',
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryTeal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BLE Status & Simulator Switch Card
              BleStatusCard(onOpenScanner: _openScanner),
              const SizedBox(height: 16),

              // Hero CTA Card: Start Screening
              InkWell(
                onTap: _startNewScreening,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 18),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Health Screening',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Record MAX30102 vitals, spirometry airflow exhalation, and auscultation',
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
              const Text('Screening Analytics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildStatCard('Total Screened', '$totalScreened', Icons.people_outline, AppTheme.primaryBlue),
                  const SizedBox(width: 10),
                  _buildStatCard('Low Risk / Normal', '$lowRisk', Icons.check_circle_outline, AppTheme.riskLow),
                  const SizedBox(width: 10),
                  _buildStatCard('High / Urgent', '$highCritical', Icons.warning_amber_outlined, AppTheme.riskCritical),
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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))
                          .then((_) => _refreshData());
                    },
                    child: const Text('View All', style: TextStyle(color: AppTheme.primaryTeal, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppTheme.primaryTeal),
                  ),
                )
              else if (_recentScreenings.isEmpty)
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
                        'Tap "Start Health Screening" to test live sensors and questionnaire triage.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ..._recentScreenings.map((s) {
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
                              p?.name ?? 'Unknown',
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
                              r.riskLevel.shortLabel.toUpperCase(),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 3),
                          Text(r.clinicalPattern.displayName, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                          const SizedBox(height: 2),
                          Text(
                            'SpO2: ${s.vitals.spo2}% • FEV1/FVC: ${(s.spirometry.fev1FvcRatio * 100).toStringAsFixed(0)}% • ${DateFormat('dd MMM, HH:mm').format(s.timestamp)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: AppTheme.textMuted),
                      onTap: () {
                        if (p != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScreeningResultScreen(
                                patient: p,
                                vitals: s.vitals,
                                spirometry: s.spirometry,
                                acoustic: s.acoustic,
                                questionnaire: s.questionnaire,
                                riskResult: s.riskResult,
                              ),
                            ),
                          ).then((_) => _refreshData());
                        }
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted), maxLines: 1),
          ],
        ),
      ),
    );
  }
}
