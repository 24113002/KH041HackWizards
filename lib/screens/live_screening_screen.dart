import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/current_screening_controller.dart';
import '../models/patient_model.dart';
import '../models/swaas_ai_ble_result.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';
import 'questionnaire_screen.dart';

class LiveScreeningScreen extends StatefulWidget {
  final Patient patient;

  const LiveScreeningScreen({super.key, required this.patient});

  @override
  State<LiveScreeningScreen> createState() => _LiveScreeningScreenState();
}

class _LiveScreeningScreenState extends State<LiveScreeningScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<SwaasAiBleResult>? _resultSub;
  bool _isReading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final screeningController = context.read<CurrentScreeningController>();
    if (!screeningController.isSessionActive) {
      screeningController.startNewSession(widget.patient);
    }

    final ble = context.read<BleService>();
    ble.resetSessionCounters();

    // Listen for NOTIFY packets from ESP32
    _resultSub = ble.screeningResultStream.listen((result) {
      if (mounted) {
        _onScreeningResultReceived(result, isNotify: true);
      }
    });

    // Check if a result is already available on initial load
    if (ble.latestScreeningResult != null && screeningController.bleResult == null) {
      screeningController.applyBleResult(ble.latestScreeningResult!);
    }
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onScreeningResultReceived(SwaasAiBleResult result, {bool isNotify = false}) {
    final screeningController = context.read<CurrentScreeningController>();
    screeningController.applyBleResult(result);

    if (isNotify && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('New screening result received: Record ${result.id} (${result.formattedStatus})'),
            ],
          ),
          backgroundColor: AppTheme.primaryTeal,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _manualReadResult() async {
    if (_isReading) return;
    setState(() => _isReading = true);

    final ble = context.read<BleService>();
    final result = await ble.readLatestResult();

    if (mounted) {
      setState(() => _isReading = false);
      if (result != null) {
        _onScreeningResultReceived(result, isNotify: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Screening result read successfully: Record ${result.id}'),
            backgroundColor: AppTheme.riskLow,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No completed result received from device yet.'),
            backgroundColor: AppTheme.riskModerate,
          ),
        );
      }
    }
  }

  void _proceedToQuestionnaire() {
    final screeningController = context.read<CurrentScreeningController>();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionnaireScreen(
          patient: widget.patient,
          vitals: screeningController.vitals,
          spirometry: screeningController.spirometry,
          acoustic: screeningController.acoustic,
          bleResult: screeningController.bleResult,
        ),
      ),
    );
  }

  void _proceedToDirectResult(SwaasAiBleResult bleResult) {
    _proceedToQuestionnaire();
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final screeningController = context.watch<CurrentScreeningController>();
    final bleResult = screeningController.bleResult;

    final isDisconnected = ble.connectionState == BleConnectionState.connectionLost ||
        ble.connectionState == BleConnectionState.disconnected ||
        ble.connectionState == BleConnectionState.error;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ESP32 Screening Receiver', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              'Patient: ${widget.patient.name} (${widget.patient.age}y, ${widget.patient.gender.name.toUpperCase()})',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isReading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Read Latest Result from Device',
            onPressed: isDisconnected ? null : _manualReadResult,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryTeal,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.assignment_turned_in), text: 'Screening Result'),
            Tab(icon: Icon(Icons.air), text: 'Raw Airflow'),
            Tab(icon: Icon(Icons.graphic_eq), text: 'Cough Signal'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Connection Lost / Disconnected Banner with Reconnect Action
          if (isDisconnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.riskCritical.withAlpha(40),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20, color: AppTheme.riskCritical),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device disconnected.',
                          style: TextStyle(color: AppTheme.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Collected patient data is preserved.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => ble.startScan(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    child: const Text('Reconnect', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScreeningResultTab(ble, bleResult),
                _buildAirflowTab(ble, bleResult),
                _buildCoughTab(ble, bleResult),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          border: Border(top: BorderSide(color: Colors.white.withAlpha(15))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bleResult != null
                      ? 'Record: ${bleResult.id} • Status: ${bleResult.formattedStatus}'
                      : 'Waiting for ESP32 screening...',
                  style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  bleResult != null
                      ? 'Risk: ${bleResult.formattedRisk} | SpO₂: ${bleResult.formattedSpo2}'
                      : 'BLE Service: ${ble.connectionState.label}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
            if (bleResult != null)
              ElevatedButton.icon(
                onPressed: () => _proceedToDirectResult(bleResult),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue to Questionnaire'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
              )
            else
              ElevatedButton.icon(
                onPressed: _proceedToQuestionnaire,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Questionnaire'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentIndigo),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: HARDWARE SCREENING RESULT & VITALS
  // ==========================================
  Widget _buildScreeningResultTab(BleService ble, SwaasAiBleResult? result) {
    final statusColor = result != null ? _getRiskColor(result.status) : AppTheme.textMuted;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ESP32 Screening Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withAlpha(80), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          result != null ? Icons.verified : Icons.hourglass_top_rounded,
                          color: statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          result != null ? 'SCREENING RESULT RECEIVED' : 'WAITING FOR SCREENING RESULT...',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    if (result != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          result.formattedStatus,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                if (result == null) ...[
                  const Text(
                    'Instruct the patient to perform the physical screening on the SwaasAI ESP32 hardware.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textLight),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The ESP32 will automatically transmit the completed packet via BLE NOTIFY once the test finishes.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isReading ? null : _manualReadResult,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Read from Device'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                      ),
                      if (ble.isSimulatorMode) ...[
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () {
                            ble.emitMockScreeningResult(rawPacket: 'R01,42350,97,1860,42,MODERATE');
                          },
                          child: const Text('Simulate R01'),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  // Result Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultStat(
                          label: 'Record ID',
                          value: result.id,
                          subText: 'Hardware session',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildResultStat(
                          label: 'Risk Score',
                          value: result.formattedRisk,
                          subText: result.risk != null ? 'Calculated score' : 'Unavailable (NA)',
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultStat(
                          label: 'Blood Oxygen (SpO₂)',
                          value: result.formattedSpo2,
                          subText: result.spo2 != null ? 'Unit: %' : 'Unavailable (NA)',
                          color: result.spo2 != null ? AppTheme.primaryTeal : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildResultStat(
                          label: 'Heart Rate',
                          value: '--',
                          subText: 'Not in BLE packet',
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultStat(
                          label: 'Raw Airflow Feature',
                          value: result.formattedAirflow,
                          subText: 'Raw sensor value',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildResultStat(
                          label: 'Cough Signal',
                          value: result.formattedCough,
                          subText: 'Digital audio feature',
                        ),
                      ),
                    ],
                  ),

                  if (result.isIncomplete) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.riskModerate.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.riskModerate.withAlpha(60)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.riskModerate, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Screening incomplete. One or more sensor measurements were missing (NA) from the hardware.',
                              style: TextStyle(fontSize: 12, color: AppTheme.riskModerate, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Medical Safety & Labeling Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.health_and_safety_outlined, color: AppTheme.primaryTeal, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Screening Parameter Guidelines',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Raw Airflow Feature: Raw sensor-derived value; not calibrated clinical airflow.\n'
                  '• Cough Signal: Digital audio feature; not a clinically validated cough severity score.\n'
                  '• SwasthAI is a screening-support application, NOT a diagnostic medical device.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStat({
    required String label,
    required String value,
    required String subText,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color ?? AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(subText, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: RAW AIRFLOW FEATURE
  // ==========================================
  Widget _buildAirflowTab(BleService ble, SwaasAiBleResult? result) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.air, color: AppTheme.primaryBlue, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Raw Airflow Feature',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Raw sensor-derived value; not calibrated clinical airflow.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Text('Airflow Sensor Value', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        const SizedBox(height: 6),
                        Text(
                          result?.formattedAirflow ?? '--',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result?.airflow != null ? 'Acquired from ESP32 differential sensor' : 'Awaiting hardware packet',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: COUGH SIGNAL FEATURE
  // ==========================================
  Widget _buildCoughTab(BleService ble, SwaasAiBleResult? result) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.graphic_eq, color: AppTheme.accentIndigo, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Cough Signal',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Digital audio feature; not a clinically validated cough severity score.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Text('Audio Feature Amplitude', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        const SizedBox(height: 6),
                        Text(
                          result?.formattedCough ?? '--',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.accentIndigo),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result?.cough != null ? 'Digitized acoustic feature from ESP32 mic' : 'Awaiting hardware packet',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(SwaasAiStatus status) {
    switch (status) {
      case SwaasAiStatus.low:
        return AppTheme.riskLow;
      case SwaasAiStatus.moderate:
        return AppTheme.riskModerate;
      case SwaasAiStatus.high:
        return AppTheme.riskHigh;
      case SwaasAiStatus.incomplete:
      case SwaasAiStatus.unknown:
        return AppTheme.riskModerate;
    }
  }
}
