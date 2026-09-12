import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sensor_data_model.dart';
import '../models/sensor_reading_model.dart';
import '../models/swaas_ai_ble_result.dart';
import 'ble_service.dart';

enum WifiConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class WifiDeviceService extends ChangeNotifier {
  WifiConnectionState _state = WifiConnectionState.disconnected;
  WifiConnectionState get state => _state;

  String _targetIp = '192.168.4.1';
  int _targetPort = 80;
  String get targetIp => _targetIp;
  int get targetPort => _targetPort;
  String get baseUrl => 'http://$_targetIp:$_targetPort';

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int? _lastPingMs;
  int? get lastPingMs => _lastPingMs;

  DateTime? _lastPacketTime;
  DateTime? get lastPacketTime => _lastPacketTime;

  String? _lastRawPacket;
  String? get lastRawPacket => _lastRawPacket;

  Timer? _pollingTimer;
  bool _isPolling = false;

  // Stream Controllers
  final _connectionStateController = StreamController<BleConnectionState>.broadcast();
  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;

  final _sensorReadingController = StreamController<SensorReading>.broadcast();
  Stream<SensorReading> get sensorReadingStream => _sensorReadingController.stream;

  final _vitalsController = StreamController<VitalsReading>.broadcast();
  Stream<VitalsReading> get vitalsStream => _vitalsController.stream;

  final _spirometryController = StreamController<SpirometryPoint>.broadcast();
  Stream<SpirometryPoint> get spirometryStream => _spirometryController.stream;

  final _acousticController = StreamController<AcousticReading>.broadcast();
  Stream<AcousticReading> get acousticStream => _acousticController.stream;

  final _screeningResultController = StreamController<SwaasAiBleResult>.broadcast();
  Stream<SwaasAiBleResult> get screeningResultStream => _screeningResultController.stream;

  // Cached states
  VitalsReading _latestVitals = VitalsReading.initial();
  VitalsReading get latestVitals => _latestVitals;

  AcousticReading _latestAcoustic = AcousticReading.initial();
  AcousticReading get latestAcoustic => _latestAcoustic;

  final List<SpirometryPoint> _currentBlowPoints = [];
  List<SpirometryPoint> get currentBlowPoints => List.unmodifiable(_currentBlowPoints);

  int _sessionCoughCount = 0;
  int get sessionCoughCount => _sessionCoughCount;

  bool _isBlowing = false;
  bool get isBlowing => _isBlowing;

  SwaasAiBleResult? _latestScreeningResult;
  SwaasAiBleResult? get latestScreeningResult => _latestScreeningResult;

  bool get isConnected => _state == WifiConnectionState.connected;

  /// Quick network ping to check if the ESP32 is reachable
  Future<bool> ping({String? ip, int? port}) async {
    final host = ip ?? _targetIp;
    final p = port ?? _targetPort;
    final endpoints = ['/data', '/vitals', '/'];

    final stopwatch = Stopwatch()..start();
    for (final ep in endpoints) {
      try {
        final url = Uri.parse('http://$host:$p$ep');
        final response = await http.get(url).timeout(const Duration(seconds: 2));
        if (response.statusCode == 200 || response.statusCode == 204) {
          stopwatch.stop();
          _lastPingMs = stopwatch.elapsedMilliseconds;
          _errorMessage = null;
          notifyListeners();
          return true;
        }
      } catch (e) {
        debugPrint('[WifiDeviceService] Ping to http://$host:$p$ep failed: $e');
      }
    }
    stopwatch.stop();
    _lastPingMs = null;
    _errorMessage = 'ESP32 not responding at http://$host:$p. If mobile data is ON, turn it OFF so phone uses Wi-Fi.';
    notifyListeners();
    return false;
  }

  /// Connect and start periodic polling of sensor readings
  Future<bool> connect({
    String ip = '192.168.4.1',
    int port = 80,
    Duration pollInterval = const Duration(milliseconds: 150),
  }) async {
    _targetIp = ip.trim();
    _targetPort = port;
    _state = WifiConnectionState.connecting;
    _connectionStateController.add(BleConnectionState.connecting);
    notifyListeners();

    final ok = await ping(ip: _targetIp, port: _targetPort);
    if (!ok) {
      _state = WifiConnectionState.error;
      _errorMessage = 'Could not reach ESP32 at $baseUrl. Ensure Mobile Data is OFF and phone is connected to SwasthAI_Screener Wi-Fi.';
      _connectionStateController.add(BleConnectionState.error);
      notifyListeners();
      return false;
    }

    _state = WifiConnectionState.connected;
    _errorMessage = null;
    _connectionStateController.add(BleConnectionState.ready);
    notifyListeners();

    _startPolling(pollInterval);
    return true;
  }

  void _startPolling(Duration interval) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) => _pollSensorData());
  }

  Future<void> _pollSensorData() async {
    if (_isPolling || !isConnected) return;
    _isPolling = true;

    try {
      final url = Uri.parse('$baseUrl/data');
      final response = await http.get(url).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        _lastPacketTime = DateTime.now();
        _lastRawPacket = response.body;
        _parseAndEmitPayload(response.body);
      }
    } catch (e) {
      debugPrint('[WifiDeviceService] Poll tick warning: $e');
    } finally {
      _isPolling = false;
    }
  }

  void _parseAndEmitPayload(String body) {
    try {
      final data = json.decode(body);
      if (data is! Map<String, dynamic>) return;

      final now = DateTime.now();

      // 1. Parse Vitals (Heart Rate, SpO2, PPG)
      final hr = (data['hr'] ?? data['heart_rate'] ?? data['heartRate']) as num?;
      final spo2 = (data['spo2'] ?? data['spO2'] ?? data['oxygen']) as num?;
      final ppg = (data['ppg'] ?? data['ppgValue']) as num?;

      if (hr != null || spo2 != null || ppg != null) {
        _latestVitals = VitalsReading(
          heartRate: hr?.toInt() ?? _latestVitals.heartRate,
          spo2: spo2?.toInt() ?? _latestVitals.spo2,
          ppgValue: (ppg?.toDouble() ?? _latestVitals.ppgValue).clamp(0.0, 1.0),
          timestamp: now,
        );
        _vitalsController.add(_latestVitals);
      }

      // 2. Parse Acoustic / Cough
      final isCough = (data['cough'] == 1 || data['is_cough'] == true || data['cough'] == true);
      final micRms = (data['rms'] ?? data['mic_rms'] ?? data['loudness'] ?? 0.0) as num;
      final freq = (data['freq'] ?? 350.0) as num;

      if (isCough) {
        _sessionCoughCount++;
      }

      _latestAcoustic = AcousticReading(
        rmsAmplitude: micRms.toDouble(),
        dominantFreqHz: freq.toDouble(),
        coughDetected: isCough,
        timestamp: now,
      );
      _acousticController.add(_latestAcoustic);

      // 3. Parse Spirometry Airflow
      final isBlowActive = (data['is_blowing'] == true || data['blowing'] == 1 || data['isBlowing'] == true);
      final flowLps = (data['flow'] ?? data['flowLps'] ?? data['airflow'] ?? 0.0) as num;
      final volumeL = (data['volume'] ?? data['volumeLiters'] ?? 0.0) as num;
      final timeSec = (data['timeSec'] ?? data['t'] ?? 0.0) as num;

      _isBlowing = isBlowActive;

      if (isBlowActive && flowLps.toDouble() > 0.05) {
        final point = SpirometryPoint(
          timeSec: timeSec.toDouble(),
          flowLps: flowLps.toDouble(),
          volumeLiters: volumeL.toDouble(),
        );
        _currentBlowPoints.add(point);
        _spirometryController.add(point);
      }

      // 4. Parse Screening Summary Result if provided by ESP32 ML
      final riskScore = (data['risk'] ?? data['risk_score']) as num?;
      final statusStr = (data['status'] ?? data['risk_category'] ?? 'LOW').toString();

      if (riskScore != null) {
        final status = _parseStatus(statusStr);
        _latestScreeningResult = SwaasAiBleResult(
          id: data['id']?.toString() ?? 'WIFI_${now.millisecondsSinceEpoch}',
          airflow: (flowLps.toDouble() * 1000).toInt(),
          spo2: spo2?.toInt() ?? 98,
          cough: _sessionCoughCount,
          risk: riskScore.toInt(),
          status: status,
          receivedAt: now,
          rawPacket: body,
        );
        _screeningResultController.add(_latestScreeningResult!);
      }

      // 5. Emit SensorReading composite
      _sensorReadingController.add(
        SensorReading(
          id: now.millisecondsSinceEpoch.toString(),
          screeningId: 'wifi_sess_${now.millisecondsSinceEpoch}',
          timestamp: now,
          spo2: _latestVitals.spo2,
          heartRate: _latestVitals.heartRate,
          pressure: flowLps.toDouble(),
          coughActivity: isCough ? 1.0 : micRms.toDouble(),
        ),
      );

      notifyListeners();
    } catch (e) {
      debugPrint('[WifiDeviceService] JSON parse error: $e');
    }
  }

  SwaasAiStatus _parseStatus(String str) {
    switch (str.toUpperCase()) {
      case 'HIGH':
        return SwaasAiStatus.high;
      case 'MODERATE':
        return SwaasAiStatus.moderate;
      case 'INCOMPLETE':
        return SwaasAiStatus.incomplete;
      case 'LOW':
      default:
        return SwaasAiStatus.low;
    }
  }

  SpirometrySummary computeSpirometrySummary() {
    if (_currentBlowPoints.isEmpty) {
      return SpirometrySummary.empty();
    }

    double peakFlowLps = 0.0;
    double fvc = 0.0;
    double fev1 = 0.0;
    double fet = 0.0;

    for (final p in _currentBlowPoints) {
      if (p.flowLps > peakFlowLps) peakFlowLps = p.flowLps;
      if (p.volumeLiters > fvc) fvc = p.volumeLiters;
      if (p.timeSec <= 1.05 && p.volumeLiters > fev1) fev1 = p.volumeLiters;
      if (p.timeSec > fet) fet = p.timeSec;
    }

    if (fev1 <= 0.0 && fvc > 0.0) {
      fev1 = fvc * 0.82;
    }

    final ratio = fvc > 0.0 ? (fev1 / fvc) : 0.0;
    final pefLpm = peakFlowLps * 60.0;

    return SpirometrySummary(
      fev1: fev1,
      fvc: fvc,
      fev1FvcRatio: ratio,
      pefLpm: pefLpm,
      forcedExpiratoryTimeSec: fet,
    );
  }

  void resetSessionCounters() {
    _currentBlowPoints.clear();
    _sessionCoughCount = 0;
    notifyListeners();
  }

  void disconnect() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _state = WifiConnectionState.disconnected;
    _connectionStateController.add(BleConnectionState.disconnected);
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _sensorReadingController.close();
    _vitalsController.close();
    _spirometryController.close();
    _acousticController.close();
    _screeningResultController.close();
    super.dispose();
  }
}
