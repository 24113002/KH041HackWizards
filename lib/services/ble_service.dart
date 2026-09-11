import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/sensor_data_model.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}

class BleService extends ChangeNotifier {
  static const String swasthaiServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String vitalsCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String airflowCharUuid = '1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e';
  static const String acousticCharUuid = 'd271607c-9204-4769-a038-0796d5147a4b';

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  BleConnectionState get connectionState => _connectionState;

  bool _isSimulatorMode = true; // Default to simulator mode for instant testing!
  bool get isSimulatorMode => _isSimulatorMode;

  String? _connectedDeviceName;
  String? get connectedDeviceName => _connectedDeviceName;

  BluetoothDevice? _connectedDevice;
  final List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => _scanResults;

  // Real-time sensor state
  VitalsReading _latestVitals = VitalsReading.initial();
  VitalsReading get latestVitals => _latestVitals;

  AcousticReading _latestAcoustic = AcousticReading.initial();
  AcousticReading get latestAcoustic => _latestAcoustic;

  // Stream Controllers
  final _vitalsController = StreamController<VitalsReading>.broadcast();
  Stream<VitalsReading> get vitalsStream => _vitalsController.stream;

  final _spirometryController = StreamController<SpirometryPoint>.broadcast();
  Stream<SpirometryPoint> get spirometryStream => _spirometryController.stream;

  final _acousticController = StreamController<AcousticReading>.broadcast();
  Stream<AcousticReading> get acousticStream => _acousticController.stream;

  // Simulation Timers
  Timer? _vitalsSimTimer;
  Timer? _acousticSimTimer;
  Timer? _blowSimTimer;
  double _simTime = 0.0;
  bool _isBlowing = false;
  bool get isBlowing => _isBlowing;

  // Spirometry session accumulator
  final List<SpirometryPoint> _currentBlowPoints = [];
  List<SpirometryPoint> get currentBlowPoints => _currentBlowPoints;

  // Acoustic session accumulator
  int _sessionCoughCount = 0;
  int get sessionCoughCount => _sessionCoughCount;

  BleService() {
    if (_isSimulatorMode) {
      _startSimulator();
    }
  }

  void toggleSimulatorMode(bool enable) {
    if (_isSimulatorMode == enable) return;
    _isSimulatorMode = enable;
    if (_isSimulatorMode) {
      disconnect();
      _startSimulator();
    } else {
      _stopSimulator();
      _connectionState = BleConnectionState.disconnected;
      _connectedDeviceName = null;
      notifyListeners();
    }
  }

  // ==========================================
  // REAL BLE IMPLEMENTATION
  // ==========================================

  Future<void> startScan({Duration timeout = const Duration(seconds: 6)}) async {
    if (_isSimulatorMode) return;
    try {
      _scanResults.clear();
      _connectionState = BleConnectionState.scanning;
      notifyListeners();

      await FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: [Guid(swasthaiServiceUuid)],
      );

      FlutterBluePlus.scanResults.listen((results) {
        _scanResults.clear();
        _scanResults.addAll(results);
        notifyListeners();
      });

      await Future.delayed(timeout);
      if (_connectionState == BleConnectionState.scanning) {
        _connectionState = BleConnectionState.disconnected;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('BLE Scan error: $e');
      _connectionState = BleConnectionState.disconnected;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      if (_connectionState == BleConnectionState.scanning) {
        _connectionState = BleConnectionState.disconnected;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (_isSimulatorMode) return false;
    try {
      _connectionState = BleConnectionState.connecting;
      notifyListeners();

      await device.connect(autoConnect: false);
      _connectedDevice = device;
      _connectedDeviceName = device.platformName.isNotEmpty ? device.platformName : 'SWASTHAI ESP32';
      _connectionState = BleConnectionState.connected;
      notifyListeners();

      await _discoverAndSubscribeServices(device);
      return true;
    } catch (e) {
      debugPrint('BLE Connect error: $e');
      _connectionState = BleConnectionState.disconnected;
      _connectedDevice = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> _discoverAndSubscribeServices(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid == Guid(swasthaiServiceUuid)) {
          for (final char in service.characteristics) {
            if (char.uuid == Guid(vitalsCharUuid)) {
              await char.setNotifyValue(true);
              char.lastValueStream.listen(_handleVitalsPacket);
            } else if (char.uuid == Guid(airflowCharUuid)) {
              await char.setNotifyValue(true);
              char.lastValueStream.listen(_handleAirflowPacket);
            } else if (char.uuid == Guid(acousticCharUuid)) {
              await char.setNotifyValue(true);
              char.lastValueStream.listen(_handleAcousticPacket);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error subscribing to characteristics: $e');
    }
  }

  void _handleVitalsPacket(List<int> bytes) {
    if (bytes.isEmpty) return;
    try {
      // Packet format: ASCII JSON e.g. {"hr":76,"spo2":98,"ppg":520} or binary
      final str = utf8.decode(bytes);
      final json = jsonDecode(str) as Map<String, dynamic>;
      final reading = VitalsReading(
        heartRate: (json['hr'] as num?)?.toInt() ?? 75,
        spo2: (json['spo2'] as num?)?.toInt() ?? 98,
        ppgValue: (json['ppg'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.now(),
      );
      _latestVitals = reading;
      _vitalsController.add(reading);
      notifyListeners();
    } catch (e) {
      // Fallback binary packet: [hr, spo2, ppgHigh, ppgLow]
      if (bytes.length >= 4) {
        final hr = bytes[0];
        final spo2 = bytes[1];
        final ppg = ((bytes[2] << 8) | bytes[3]).toDouble();
        final reading = VitalsReading(
          heartRate: hr,
          spo2: spo2,
          ppgValue: ppg,
          timestamp: DateTime.now(),
        );
        _latestVitals = reading;
        _vitalsController.add(reading);
        notifyListeners();
      }
    }
  }

  void _handleAirflowPacket(List<int> bytes) {
    if (bytes.isEmpty) return;
    try {
      final str = utf8.decode(bytes);
      final json = jsonDecode(str) as Map<String, dynamic>;
      final point = SpirometryPoint(
        timeSec: (json['t'] as num).toDouble(),
        flowLps: (json['f'] as num).toDouble(),
        volumeLiters: (json['v'] as num).toDouble(),
      );
      _currentBlowPoints.add(point);
      _spirometryController.add(point);
    } catch (_) {}
  }

  void _handleAcousticPacket(List<int> bytes) {
    if (bytes.isEmpty) return;
    try {
      final str = utf8.decode(bytes);
      final json = jsonDecode(str) as Map<String, dynamic>;
      final reading = AcousticReading(
        rmsAmplitude: (json['rms'] as num?)?.toDouble() ?? 0.0,
        coughDetected: (json['cough'] as num?)?.toInt() == 1,
        dominantFreqHz: (json['freq'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.now(),
      );
      if (reading.coughDetected) {
        _sessionCoughCount++;
      }
      _latestAcoustic = reading;
      _acousticController.add(reading);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
      _connectedDevice = null;
    }
    _connectionState = BleConnectionState.disconnected;
    _connectedDeviceName = null;
    notifyListeners();
  }

  // ==========================================
  // SIMULATOR IMPLEMENTATION (OFFLINE DEMO)
  // ==========================================

  void _startSimulator() {
    _connectionState = BleConnectionState.connected;
    _connectedDeviceName = 'SWASTHAI-ESP32 (Hardware Simulator)';
    notifyListeners();

    _simTime = 0.0;
    _vitalsSimTimer?.cancel();
    _acousticSimTimer?.cancel();

    // Stream realistic PPG wave at 25 Hz
    _vitalsSimTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      _simTime += 0.04;
      final hr = 74 + (sin(_simTime * 0.5) * 3).round();
      final spo2 = 98 - (sin(_simTime * 0.2) > 0.8 ? 1 : 0);

      // Realistic PPG pulse with systolic peak & dicrotic notch
      final phase = (_simTime * (hr / 60.0)) % 1.0;
      double ppg;
      if (phase < 0.25) {
        ppg = sin(phase / 0.25 * pi * 0.5); // Sharp systolic upstroke
      } else if (phase < 0.45) {
        ppg = cos((phase - 0.25) / 0.20 * pi * 0.5) * 0.7; // Fall towards notch
      } else if (phase < 0.60) {
        ppg = 0.35 + sin((phase - 0.45) / 0.15 * pi) * 0.2; // Dicrotic wave rebound
      } else {
        ppg = 0.35 * (1.0 - (phase - 0.60) / 0.40); // Diastolic decay
      }
      ppg += (Random().nextDouble() - 0.5) * 0.04; // Natural micro-noise

      final reading = VitalsReading(
        heartRate: hr,
        spo2: spo2,
        ppgValue: ppg.clamp(0.0, 1.0),
        timestamp: DateTime.now(),
      );
      _latestVitals = reading;
      _vitalsController.add(reading);
      notifyListeners();
    });

    // Stream ambient acoustic levels at 5 Hz
    _acousticSimTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final baseRms = 0.06 + Random().nextDouble() * 0.05;
      final reading = AcousticReading(
        rmsAmplitude: baseRms,
        coughDetected: false,
        dominantFreqHz: 200 + Random().nextDouble() * 150,
        timestamp: DateTime.now(),
      );
      _latestAcoustic = reading;
      _acousticController.add(reading);
      notifyListeners();
    });
  }

  void _stopSimulator() {
    _vitalsSimTimer?.cancel();
    _acousticSimTimer?.cancel();
    _blowSimTimer?.cancel();
    _isBlowing = false;
  }

  /// Triggers a simulated Forced Expiratory Spirometry test (e.g. forced exhalation into mouthpiece)
  /// [simulateObstruction]: if true, produces an obstructive pattern (reduced FEV1 & scooped flow)
  void startSimulatedSpirometryBlow({bool simulateObstruction = false}) {
    if (_isBlowing) return;
    _isBlowing = true;
    _currentBlowPoints.clear();
    notifyListeners();

    double blowTime = 0.0;
    double currentVolume = 0.0;
    const dt = 0.05; // 20 Hz curve sampling

    // Target parameters for standard healthy vs obstructive adult
    final peakFlow = simulateObstruction ? 4.2 : 7.8; // L/s
    final totalTargetVol = simulateObstruction ? 3.3 : 4.2; // L
    final decayRate = simulateObstruction ? 0.75 : 1.45;

    _blowSimTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      blowTime += dt;

      double flow;
      if (blowTime < 0.15) {
        // Fast blast up to PEF (Peak Expiratory Flow)
        flow = (blowTime / 0.15) * peakFlow;
      } else {
        // Exhalation exponential curve
        final tAfterPeak = blowTime - 0.15;
        flow = peakFlow * exp(-decayRate * tAfterPeak);
      }

      flow += (Random().nextDouble() - 0.5) * 0.15;
      if (flow < 0.0) flow = 0.0;

      currentVolume += flow * dt;
      if (currentVolume > totalTargetVol) {
        currentVolume = totalTargetVol;
        flow = 0.0;
      }

      final point = SpirometryPoint(
        timeSec: blowTime,
        flowLps: double.parse(flow.toStringAsFixed(2)),
        volumeLiters: double.parse(currentVolume.toStringAsFixed(2)),
      );

      _currentBlowPoints.add(point);
      _spirometryController.add(point);
      notifyListeners();

      // Stop blow test after 4.5 seconds or when flow stops
      if (blowTime >= 4.5 || (blowTime > 1.0 && flow <= 0.05)) {
        timer.cancel();
        _isBlowing = false;
        notifyListeners();
      }
    });
  }

  /// Calculates the final summary indices from the current blow points
  SpirometrySummary computeSpirometrySummary() {
    if (_currentBlowPoints.isEmpty) {
      return SpirometrySummary.empty();
    }

    double maxFlow = 0.0;
    double fev1 = 0.0;
    double fvc = 0.0;
    double fet = _currentBlowPoints.last.timeSec;

    for (final pt in _currentBlowPoints) {
      if (pt.flowLps > maxFlow) {
        maxFlow = pt.flowLps;
      }
      if (pt.timeSec <= 1.05 && pt.timeSec >= 0.95) {
        fev1 = pt.volumeLiters;
      }
      if (pt.volumeLiters > fvc) {
        fvc = pt.volumeLiters;
      }
    }

    if (fev1 == 0.0 && _currentBlowPoints.isNotEmpty) {
      // Find closest point to 1.0s
      final closest = _currentBlowPoints.reduce(
        (a, b) => (a.timeSec - 1.0).abs() < (b.timeSec - 1.0).abs() ? a : b,
      );
      fev1 = closest.volumeLiters;
    }

    // PEF in Liters per minute = maxFlow (L/s) * 60
    final pefLpm = maxFlow * 60.0;
    final ratio = fvc > 0.1 ? (fev1 / fvc) : 0.0;

    return SpirometrySummary(
      fev1: double.parse(fev1.toStringAsFixed(2)),
      fvc: double.parse(fvc.toStringAsFixed(2)),
      fev1FvcRatio: double.parse(ratio.toStringAsFixed(2)),
      pefLpm: double.parse(pefLpm.toStringAsFixed(1)),
      forcedExpiratoryTimeSec: double.parse(fet.toStringAsFixed(2)),
    );
  }

  /// Simulates an acoustic cough trigger
  void triggerSimulatedCough() {
    _sessionCoughCount++;
    final reading = AcousticReading(
      rmsAmplitude: 0.88,
      coughDetected: true,
      dominantFreqHz: 450,
      timestamp: DateTime.now(),
    );
    _latestAcoustic = reading;
    _acousticController.add(reading);
    notifyListeners();
  }

  void resetSessionCounters() {
    _sessionCoughCount = 0;
    _currentBlowPoints.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _vitalsSimTimer?.cancel();
    _acousticSimTimer?.cancel();
    _blowSimTimer?.cancel();
    _vitalsController.close();
    _spirometryController.close();
    _acousticController.close();
    super.dispose();
  }
}
