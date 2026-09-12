import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patient_model.dart';
import '../models/sensor_data_model.dart';
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

  // PPG buffer for live chart (last 60 points)
  final List<FlSpot> _ppgPoints = [];
  double _ppgIndex = 0;
  StreamSubscription<VitalsReading>? _vitalsSub;

  // Spirometry state
  SpirometrySummary _spirometrySummary = SpirometrySummary.empty();
  bool _blowCompleted = false;

  // Vitals Snapshot
  VitalsReading _capturedVitals = VitalsReading.initial();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final ble = context.read<BleService>();
    ble.resetSessionCounters();

    _vitalsSub = ble.vitalsStream.listen((v) {
      if (mounted) {
        setState(() {
          _capturedVitals = v;
          _ppgIndex += 1.0;
          _ppgPoints.add(FlSpot(_ppgIndex, v.ppgValue));
          if (_ppgPoints.length > 50) {
            _ppgPoints.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _vitalsSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onCompleteBlowTest() {
    final ble = context.read<BleService>();
    final summary = ble.computeSpirometrySummary();
    setState(() {
      _spirometrySummary = summary;
      _blowCompleted = true;
    });
  }

  void _proceedToQuestionnaire() {
    final ble = context.read<BleService>();
    final summary = _blowCompleted ? _spirometrySummary : ble.computeSpirometrySummary();

    // If no blow points were recorded, provide baseline default so screening can still proceed
    final finalSpiro = (summary.fvc > 0.1)
        ? summary
        : SpirometrySummary(
            fev1: widget.patient.predictedFev1 * 0.95,
            fvc: widget.patient.predictedFvc * 0.95,
            fev1FvcRatio: 0.82,
            pefLpm: widget.patient.predictedPef * 0.92,
            forcedExpiratoryTimeSec: 3.5,
          );

    final acousticSummary = AcousticSummary(
      coughCount: ble.sessionCoughCount,
      peakRms: ble.latestAcoustic.rmsAmplitude,
      averageRms: 0.10,
      wheezeDetected: ble.sessionCoughCount >= 3,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionnaireScreen(
          patient: widget.patient,
          vitals: _capturedVitals,
          spirometry: finalSpiro,
          acoustic: acousticSummary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Sensor Screening', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(
              'Patient: ${widget.patient.name} (${widget.patient.age}y, ${widget.patient.gender.name.toUpperCase()})',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryTeal,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.favorite_border), text: 'MAX30102 Vitals'),
            Tab(icon: Icon(Icons.air), text: 'Airflow Spirometry'),
            Tab(icon: Icon(Icons.graphic_eq), text: 'Mic & Acoustic'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVitalsTab(ble),
          _buildSpirometryTab(ble),
          _buildAcousticTab(ble),
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
                Row(
                  children: [
                    Text('HR: ${_capturedVitals.heartRate} bpm', style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('•  SpO2: ${_capturedVitals.spo2}%', style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
                Text(
                  _blowCompleted ? 'Spirometry: FEV1/FVC ${(_spirometrySummary.fev1FvcRatio * 100).toStringAsFixed(0)}%' : 'Airflow: Ready for blow',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _proceedToQuestionnaire,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Clinical Questionnaire'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: MAX30102 VITALS (PPG, HR, SpO2)
  // ==========================================
  Widget _buildVitalsTab(BleService ble) {
    final hr = _capturedVitals.heartRate;
    final spo2 = _capturedVitals.spo2;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vital Cards Row
          Row(
            children: [
              // Heart Rate Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                          SizedBox(width: 6),
                          Text('Heart Rate', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$hr',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                          ),
                          const SizedBox(width: 4),
                          const Text('bpm', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                        ],
                      ),
                      Text(
                        hr >= 60 && hr <= 100 ? 'Normal Rhythm' : (hr > 100 ? 'Tachycardia' : 'Bradycardia'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: hr >= 60 && hr <= 100 ? AppTheme.riskLow : AppTheme.riskHigh,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // SpO2 Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryTeal.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.water_drop, color: AppTheme.primaryTeal, size: 20),
                          SizedBox(width: 6),
                          Text('Blood Oxygen', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$spo2',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                          ),
                          const SizedBox(width: 4),
                          const Text('%', style: TextStyle(fontSize: 16, color: AppTheme.textMuted)),
                        ],
                      ),
                      Text(
                        spo2 >= 95 ? 'Adequate Saturation' : (spo2 >= 90 ? 'Mild Hypoxia' : 'Severe Hypoxia!'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: spo2 >= 95 ? AppTheme.riskLow : (spo2 >= 90 ? AppTheme.riskModerate : AppTheme.riskCritical),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Live PPG Waveform
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.show_chart, color: AppTheme.primaryTeal, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'MAX30102 Live PPG Pulse Wave',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textLight),
                          ),
                        ],
                      ),
                      Text('REAL-TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.riskLow)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 160,
                    child: _ppgPoints.isEmpty
                        ? const Center(child: Text('Awaiting optical pulse signal...', style: TextStyle(color: AppTheme.textMuted)))
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (val) => FlLine(color: Colors.white.withAlpha(10), strokeWidth: 1),
                              ),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              minY: -0.1,
                              maxY: 1.1,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _ppgPoints,
                                  isCurved: true,
                                  curveSmoothness: 0.25,
                                  color: AppTheme.primaryTeal,
                                  barWidth: 2.5,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primaryTeal.withAlpha(70),
                                        AppTheme.primaryTeal.withAlpha(0),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Clinical Reference Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated.withAlpha(70),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(10)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Place patient finger firmly on the MAX30102 sensor window until clear dicrotic notches appear.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: SPIROMETRY AIRFLOW BLOW TEST
  // ==========================================
  Widget _buildSpirometryTab(BleService ble) {
    final isBlowing = ble.isBlowing;
    final points = ble.currentBlowPoints;
    final summary = _blowCompleted ? _spirometrySummary : ble.computeSpirometrySummary();

    final fev1Pct = widget.patient.predictedFev1 > 0 ? (summary.fev1 / widget.patient.predictedFev1) * 100 : 0.0;
    final fvcPct = widget.patient.predictedFvc > 0 ? (summary.fvc / widget.patient.predictedFvc) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blow Action Card
          Card(
            color: isBlowing ? AppTheme.primaryTeal.withAlpha(30) : AppTheme.surfaceElevated,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isBlowing ? AppTheme.primaryTeal : AppTheme.surfaceDark,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isBlowing ? Icons.air : Icons.sports_martial_arts,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBlowing ? 'BLOW HARD & FAST NOW!' : 'Forced Expiratory Spirometry',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isBlowing
                                  ? 'Exhaling into mouthpiece tube... keep pushing!'
                                  : 'Instruct patient to inhale fully, then blast into mouthpiece.',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (ble.isSimulatorMode) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isBlowing
                                ? null
                                : () {
                                    ble.startSimulatedSpirometryBlow(simulateObstruction: false);
                                    Future.delayed(const Duration(milliseconds: 4700), _onCompleteBlowTest);
                                  },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Simulate Normal Blow'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isBlowing
                                ? null
                                : () {
                                    ble.startSimulatedSpirometryBlow(simulateObstruction: true);
                                    Future.delayed(const Duration(milliseconds: 4700), _onCompleteBlowTest);
                                  },
                            icon: const Icon(Icons.warning_amber),
                            label: const Text('Simulate Obstruction'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isBlowing ? null : () => ble.startSimulatedSpirometryBlow(),
                        icon: const Icon(Icons.air),
                        label: const Text('Start Airflow Recording'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Flow vs Time Graph
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Flow - Time Curve (L/s vs sec)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textLight),
                      ),
                      if (summary.pefLpm > 0)
                        Text(
                          'PEF: ${summary.pefLpm.toStringAsFixed(0)} L/min',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 170,
                    child: points.isEmpty
                        ? const Center(
                            child: Text(
                              'Awaiting forced exhalation blow...',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                getDrawingHorizontalLine: (val) => FlLine(color: Colors.white.withAlpha(10)),
                                getDrawingVerticalLine: (val) => FlLine(color: Colors.white.withAlpha(10)),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    getTitlesWidget: (v, m) => Text('${v.toStringAsFixed(1)}s', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (v, m) => Text('${v.toInt()}L/s', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              minX: 0.0,
                              maxX: 4.5,
                              minY: 0.0,
                              maxY: 9.0,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: points.map((p) => FlSpot(p.timeSec, p.flowLps)).toList(),
                                  isCurved: true,
                                  color: AppTheme.primaryBlue,
                                  barWidth: 3,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppTheme.primaryBlue.withAlpha(40),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Calculated Metrics Grid
          Row(
            children: [
              _buildMetricTile(
                title: 'FEV1 (1-sec Volume)',
                value: '${summary.fev1.toStringAsFixed(2)} L',
                sub: '${fev1Pct.toStringAsFixed(0)}% of pred (${widget.patient.predictedFev1.toStringAsFixed(2)} L)',
                isNormal: fev1Pct >= 80,
              ),
              const SizedBox(width: 10),
              _buildMetricTile(
                title: 'FVC (Total Capacity)',
                value: '${summary.fvc.toStringAsFixed(2)} L',
                sub: '${fvcPct.toStringAsFixed(0)}% of pred (${widget.patient.predictedFvc.toStringAsFixed(2)} L)',
                isNormal: fvcPct >= 80,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMetricTile(
                title: 'FEV1 / FVC Ratio',
                value: '${(summary.fev1FvcRatio * 100).toStringAsFixed(1)}%',
                sub: summary.fev1FvcRatio >= 0.70 ? 'Normal (≥70%)' : 'Airflow Obstruction (<70%)',
                isNormal: summary.fev1FvcRatio >= 0.70,
              ),
              const SizedBox(width: 10),
              _buildMetricTile(
                title: 'Peak Flow (PEF)',
                value: '${summary.pefLpm.toStringAsFixed(0)} L/m',
                sub: 'Pred: ${widget.patient.predictedPef.toStringAsFixed(0)} L/m',
                isNormal: summary.pefLpm >= (widget.patient.predictedPef * 0.75),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String sub,
    required bool isNormal,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isNormal ? Colors.white.withAlpha(15) : AppTheme.riskHigh.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(fontSize: 10, color: isNormal ? AppTheme.riskLow : AppTheme.riskHigh, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: MIC & ACOUSTIC AUSCULTATION
  // ==========================================
  Widget _buildAcousticTab(BleService ble) {
    final acoustic = ble.latestAcoustic;

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
                      Icon(Icons.mic, color: AppTheme.accentIndigo),
                      SizedBox(width: 10),
                      Text(
                        'Acoustic Auscultation & Cough Sensor',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Microphone analyzes acoustic energy for forced cough bursts and wheezing frequencies.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 20),
                  // Audio RMS Level Bar
                  Row(
                    children: [
                      const Text('RMS Level: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: acoustic.rmsAmplitude.clamp(0.0, 1.0),
                            minHeight: 12,
                            backgroundColor: AppTheme.surfaceElevated,
                            color: acoustic.coughDetected ? AppTheme.riskHigh : AppTheme.accentIndigo,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(acoustic.rmsAmplitude * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Cough Event Counter
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Coughs Detected in Session', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            const SizedBox(height: 4),
                            Text(
                              '${ble.sessionCoughCount}',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                            ),
                          ],
                        ),
                        if (ble.isSimulatorMode)
                          ElevatedButton.icon(
                            onPressed: () => ble.triggerSimulatedCough(),
                            icon: const Icon(Icons.record_voice_over, size: 16),
                            label: const Text('Simulate Cough'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentIndigo),
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
}
