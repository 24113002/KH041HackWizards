import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config/ble_config.dart';
import '../models/ble_device_model.dart';
import '../models/sensor_data_model.dart';
import '../models/sensor_reading_model.dart';
import 'sensor_data_parser.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  connectionLost,
}

/// Abstract BLE Service contract required for hardware-to-mobile sensor acquisition.
abstract class BleService extends ChangeNotifier {
  BleConnectionState get connectionState;
  Stream<BleConnectionState> get connectionStateStream;
  Stream<SensorReading> get sensorReadingStream;
  Stream<VitalsReading> get vitalsStream;
  Stream<SpirometryPoint> get spirometryStream;
  Stream<AcousticReading> get acousticStream;

  VitalsReading get latestVitals;
  AcousticReading get latestAcoustic;
  List<SpirometryPoint> get currentBlowPoints;
  int get sessionCoughCount;
  bool get isSimulatorMode;
  bool get isBlowing;
  String? get connectedDeviceName;
  String? get errorMessage;
  List<BleDeviceModel> get discoveredDevices;

  Future<void> startScan({Duration timeout = BleConfig.scanTimeout});
  Future<void> stopScan();
  Future<void> connectToDevice(dynamic device);
  Future<void> disconnect();
  void toggleSimulatorMode(bool enable);
  void resetSessionCounters();
  SpirometrySummary computeSpirometrySummary();
  void triggerSimulatorBlow({bool simulateObstruction = false});
  void startSimulatedSpirometryBlow({bool simulateObstruction = false});
  void triggerSimulatedCough();
}

/// Real BLE Service implementation communicating with physical ESP32 via flutter_blue_plus.
class RealBleService extends ChangeNotifier implements BleService {
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  @override
  BleConnectionState get connectionState => _connectionState;

  @override
  bool get isSimulatorMode => false;

  String? _connectedDeviceName;
  @override
  String? get connectedDeviceName => _connectedDeviceName;

  String? _errorMessage;
  @override
  String? get errorMessage => _errorMessage;

  BluetoothDevice? _connectedDevice;
  final List<BleDeviceModel> _discoveredDevices = [];
  @override
  List<BleDeviceModel> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  VitalsReading _latestVitals = VitalsReading.initial();
  @override
  VitalsReading get latestVitals => _latestVitals;

  AcousticReading _latestAcoustic = AcousticReading.initial();
  @override
  AcousticReading get latestAcoustic => _latestAcoustic;

  final _connectionStateController = StreamController<BleConnectionState>.broadcast();
  @override
  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;

  final _sensorReadingController = StreamController<SensorReading>.broadcast();
  @override
  Stream<SensorReading> get sensorReadingStream => _sensorReadingController.stream;

  final _vitalsController = StreamController<VitalsReading>.broadcast();
  @override
  Stream<VitalsReading> get vitalsStream => _vitalsController.stream;

  final _spirometryController = StreamController<SpirometryPoint>.broadcast();
  @override
  Stream<SpirometryPoint> get spirometryStream => _spirometryController.stream;

  final _acousticController = StreamController<AcousticReading>.broadcast();
  @override
  Stream<AcousticReading> get acousticStream => _acousticController.stream;

  final List<SpirometryPoint> _currentBlowPoints = [];
  @override
  List<SpirometryPoint> get currentBlowPoints => List.unmodifiable(_currentBlowPoints);

  int _sessionCoughCount = 0;
  @override
  int get sessionCoughCount => _sessionCoughCount;

  @override
  bool get isBlowing => false;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  final List<StreamSubscription> _characteristicSubscriptions = [];
  int _autoReconnectAttempts = 0;

  void _setConnectionState(BleConnectionState state, {String? error}) {
    _connectionState = state;
    _errorMessage = error;
    _connectionStateController.add(state);
    notifyListeners();
  }

  @override
  Future<void> startScan({Duration timeout = BleConfig.scanTimeout}) async {
    try {
      _discoveredDevices.clear();
      _errorMessage = null;

      // 1. Verify Bluetooth Hardware Support
      if (await FlutterBluePlus.isSupported == false) {
        _setConnectionState(
          BleConnectionState.disconnected,
          error: 'Bluetooth Low Energy is not supported on this device.',
        );
        return;
      }

      // 2. Verify Bluetooth Power State
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _setConnectionState(
          BleConnectionState.disconnected,
          error: 'Bluetooth is turned off. Please enable Bluetooth to connect the screening device.',
        );
        return;
      }

      _setConnectionState(BleConnectionState.scanning);

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final devName = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;

          final matchesPrefix = BleConfig.devicePrefixes.any(
            (prefix) => devName.toLowerCase().startsWith(prefix.toLowerCase()),
          );

          final matchesService = r.advertisementData.serviceUuids.any(
            (uuid) => uuid.toString().toLowerCase() == BleConfig.serviceUuid.toLowerCase(),
          );

          // Filter by SwasthAI device name, prefix or advertised service UUID
          if (matchesPrefix || matchesService || devName.isNotEmpty) {
            final model = BleDeviceModel(
              id: r.device.remoteId.str,
              name: devName.isNotEmpty ? devName : 'SwasthAI Device',
              rssi: r.rssi,
              platformDevice: r.device,
            );

            final existingIndex = _discoveredDevices.indexWhere((d) => d.id == model.id);
            if (existingIndex >= 0) {
              _discoveredDevices[existingIndex] = model;
            } else {
              _discoveredDevices.add(model);
            }
            notifyListeners();
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: timeout);
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      if (_connectionState == BleConnectionState.scanning) {
        _setConnectionState(BleConnectionState.disconnected);
      }
    } catch (e) {
      debugPrint('[RealBleService] Scan error: $e');
      _setConnectionState(
        BleConnectionState.disconnected,
        error: 'Bluetooth access is required to connect SwasthAI to the screening device.',
      );
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_connectionState == BleConnectionState.scanning) {
      _setConnectionState(BleConnectionState.disconnected);
    }
  }

  @override
  Future<void> connectToDevice(dynamic device) async {
    _autoReconnectAttempts = 0;

    BluetoothDevice? targetBleDevice;
    if (device is BleDeviceModel && device.platformDevice is BluetoothDevice) {
      targetBleDevice = device.platformDevice as BluetoothDevice;
    } else if (device is BluetoothDevice) {
      targetBleDevice = device;
    }

    if (targetBleDevice == null) {
      _setConnectionState(
        BleConnectionState.disconnected,
        error: 'Invalid device selected.',
      );
      return;
    }

    try {
      await stopScan();
      _setConnectionState(BleConnectionState.connecting);
      _connectedDevice = targetBleDevice;
      _connectedDeviceName = targetBleDevice.platformName.isNotEmpty
          ? targetBleDevice.platformName
          : BleConfig.targetDeviceName;

      // Connect with configured timeout
      await targetBleDevice.connect(timeout: BleConfig.connectTimeout, autoConnect: false);

      // Listen for unexpected connection drops
      _deviceStateSubscription?.cancel();
      _deviceStateSubscription = targetBleDevice.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('[RealBleService] Device disconnected.');
          _handleDisconnection();
        }
      });

      // Request MTU negotiation (512 for optimal sensor packets)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await targetBleDevice.requestMtu(512);
        } catch (_) {}
      }

      // Discover GATT Services
      final services = await targetBleDevice.discoverServices();
      await _setupCharacteristics(services);

      _setConnectionState(BleConnectionState.connected);
    } catch (e) {
      debugPrint('[RealBleService] Connection error: $e');
      _setConnectionState(
        BleConnectionState.disconnected,
        error: 'Failed to connect to SwasthAI device. Make sure the device is powered on.',
      );
    }
  }

  Future<void> _setupCharacteristics(List<BluetoothService> services) async {
    for (final sub in _characteristicSubscriptions) {
      await sub.cancel();
    }
    _characteristicSubscriptions.clear();

    for (final s in services) {
      for (final c in s.characteristics) {
        final charUuidStr = c.uuid.toString().toLowerCase();

        // 1. Vitals characteristic
        if (charUuidStr == BleConfig.vitalsCharacteristicUuid.toLowerCase()) {
          await c.setNotifyValue(true);
          final sub = c.onValueReceived.listen((bytes) {
            _onVitalsPacketReceived(bytes);
          });
          _characteristicSubscriptions.add(sub);
        }

        // 2. Airflow characteristic
        if (charUuidStr == BleConfig.airflowCharacteristicUuid.toLowerCase()) {
          await c.setNotifyValue(true);
          final sub = c.onValueReceived.listen((bytes) {
            _onAirflowPacketReceived(bytes);
          });
          _characteristicSubscriptions.add(sub);
        }

        // 3. Acoustic characteristic
        if (charUuidStr == BleConfig.acousticCharacteristicUuid.toLowerCase()) {
          await c.setNotifyValue(true);
          final sub = c.onValueReceived.listen((bytes) {
            _onAcousticPacketReceived(bytes);
          });
          _characteristicSubscriptions.add(sub);
        }
      }
    }
  }

  void _onVitalsPacketReceived(List<int> bytes) {
    final vitals = SensorDataParser.parseVitals(bytes);
    if (vitals != null) {
      _latestVitals = vitals;
      _vitalsController.add(vitals);

      final sensorReading = SensorDataParser.parseSensorReading(
        bytes,
        screeningId: 'live_ble_stream',
      );
      if (sensorReading != null) {
        _sensorReadingController.add(sensorReading);
      }
      notifyListeners();
    }
  }

  void _onAirflowPacketReceived(List<int> bytes) {
    final point = SensorDataParser.parseSpirometryPoint(bytes);
    if (point != null) {
      _currentBlowPoints.add(point);
      _spirometryController.add(point);
      notifyListeners();
    }
  }

  void _onAcousticPacketReceived(List<int> bytes) {
    final acoustic = SensorDataParser.parseAcousticReading(bytes);
    if (acoustic != null) {
      _latestAcoustic = acoustic;
      if (acoustic.coughDetected) {
        _sessionCoughCount++;
      }
      _acousticController.add(acoustic);
      notifyListeners();
    }
  }

  void _handleDisconnection() {
    _cleanSubscriptions();
    if (_autoReconnectAttempts < BleConfig.maxAutoReconnectAttempts && _connectedDevice != null) {
      _autoReconnectAttempts++;
      debugPrint('[RealBleService] Auto-reconnecting attempt $_autoReconnectAttempts...');
      _setConnectionState(
        BleConnectionState.connecting,
        error: 'Reconnecting to device ($_autoReconnectAttempts/${BleConfig.maxAutoReconnectAttempts})...',
      );
      connectToDevice(_connectedDevice!);
    } else {
      _setConnectionState(
        BleConnectionState.connectionLost,
        error: 'Connection lost. Please reconnect the device.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    _autoReconnectAttempts = BleConfig.maxAutoReconnectAttempts;
    _cleanSubscriptions();

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
      _connectedDevice = null;
    }

    _connectedDeviceName = null;
    _setConnectionState(BleConnectionState.disconnected);
  }

  void _cleanSubscriptions() {
    for (final sub in _characteristicSubscriptions) {
      sub.cancel();
    }
    _characteristicSubscriptions.clear();
    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
  }

  @override
  void resetSessionCounters() {
    _currentBlowPoints.clear();
    _sessionCoughCount = 0;
    notifyListeners();
  }

  @override
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

  @override
  void toggleSimulatorMode(bool enable) {
    // Controlled via AppBleService
  }

  @override
  void triggerSimulatorBlow({bool simulateObstruction = false}) {}

  @override
  void startSimulatedSpirometryBlow({bool simulateObstruction = false}) {}

  @override
  void triggerSimulatedCough() {}

  @override
  void dispose() {
    _cleanSubscriptions();
    _scanSubscription?.cancel();
    _connectionStateController.close();
    _sensorReadingController.close();
    _vitalsController.close();
    _spirometryController.close();
    _acousticController.close();
    super.dispose();
  }
}

/// Mock BLE Service implementation simulating ESP32 hardware for testing and development.
class MockBleService extends ChangeNotifier implements BleService {
  BleConnectionState _connectionState = BleConnectionState.connected;
  @override
  BleConnectionState get connectionState => _connectionState;

  @override
  bool get isSimulatorMode => true;

  String? _connectedDeviceName = 'SWASTHAI_ESP32 (Simulated)';
  @override
  String? get connectedDeviceName => _connectedDeviceName;

  @override
  String? get errorMessage => null;

  final List<BleDeviceModel> _discoveredDevices = [
    const BleDeviceModel(
      id: 'MOCK_ESP32_01',
      name: BleConfig.targetDeviceName,
      rssi: -58,
      isConnected: true,
    ),
  ];
  @override
  List<BleDeviceModel> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  VitalsReading _latestVitals = VitalsReading.initial();
  @override
  VitalsReading get latestVitals => _latestVitals;

  AcousticReading _latestAcoustic = AcousticReading.initial();
  @override
  AcousticReading get latestAcoustic => _latestAcoustic;

  final _connectionStateController = StreamController<BleConnectionState>.broadcast();
  @override
  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;

  final _sensorReadingController = StreamController<SensorReading>.broadcast();
  @override
  Stream<SensorReading> get sensorReadingStream => _sensorReadingController.stream;

  final _vitalsController = StreamController<VitalsReading>.broadcast();
  @override
  Stream<VitalsReading> get vitalsStream => _vitalsController.stream;

  final _spirometryController = StreamController<SpirometryPoint>.broadcast();
  @override
  Stream<SpirometryPoint> get spirometryStream => _spirometryController.stream;

  final _acousticController = StreamController<AcousticReading>.broadcast();
  @override
  Stream<AcousticReading> get acousticStream => _acousticController.stream;

  final List<SpirometryPoint> _currentBlowPoints = [];
  @override
  List<SpirometryPoint> get currentBlowPoints => List.unmodifiable(_currentBlowPoints);

  int _sessionCoughCount = 0;
  @override
  int get sessionCoughCount => _sessionCoughCount;

  bool _isBlowing = false;
  @override
  bool get isBlowing => _isBlowing;

  Timer? _vitalsSimTimer;
  Timer? _acousticSimTimer;
  Timer? _blowSimTimer;
  double _simPhase = 0.0;

  MockBleService({bool startConnected = true}) {
    if (startConnected) {
      _startSimulator();
    } else {
      _connectionState = BleConnectionState.disconnected;
      _connectedDeviceName = null;
    }
  }

  void startSimulator() {
    _startSimulator();
    notifyListeners();
  }

  void _startSimulator() {
    _connectionState = BleConnectionState.connected;
    _connectedDeviceName = 'SWASTHAI_ESP32 (Simulated)';
    _connectionStateController.add(_connectionState);

    _vitalsSimTimer?.cancel();
    _vitalsSimTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_connectionState != BleConnectionState.connected) return;

      _simPhase += 0.25;
      final ppg = (sin(_simPhase) * 0.4 + sin(_simPhase * 2) * 0.15 + 0.5).clamp(0.05, 0.95);
      final hrJitter = (sin(_simPhase * 0.1) * 2).round();
      final hr = (82 + hrJitter).clamp(78, 86);

      _latestVitals = VitalsReading(
        heartRate: hr,
        spo2: 97,
        ppgValue: ppg,
        timestamp: DateTime.now(),
      );

      _vitalsController.add(_latestVitals);

      _sensorReadingController.add(
        SensorReading(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          screeningId: 'simulator_stream',
          timestamp: DateTime.now(),
          spo2: 97,
          heartRate: hr,
          pressure: 1.84,
          coughActivity: 0.72,
        ),
      );

      notifyListeners();
    });

    _acousticSimTimer?.cancel();
    _acousticSimTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_connectionState != BleConnectionState.connected) return;
      _latestAcoustic = AcousticReading(
        rmsAmplitude: 0.12,
        coughDetected: false,
        dominantFreqHz: 280.0,
        timestamp: DateTime.now(),
      );
      _acousticController.add(_latestAcoustic);
    });
  }

  void _stopSimulator() {
    _vitalsSimTimer?.cancel();
    _vitalsSimTimer = null;
    _acousticSimTimer?.cancel();
    _acousticSimTimer = null;
    _blowSimTimer?.cancel();
    _blowSimTimer = null;
  }

  @override
  Future<void> startScan({Duration timeout = BleConfig.scanTimeout}) async {
    _connectionState = BleConnectionState.scanning;
    _connectionStateController.add(_connectionState);
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1000));
    _connectionState = BleConnectionState.disconnected;
    _connectionStateController.add(_connectionState);
    notifyListeners();
  }

  @override
  Future<void> stopScan() async {
    if (_connectionState == BleConnectionState.scanning) {
      _connectionState = BleConnectionState.disconnected;
      _connectionStateController.add(_connectionState);
      notifyListeners();
    }
  }

  @override
  Future<void> connectToDevice(dynamic device) async {
    _connectionState = BleConnectionState.connecting;
    _connectionStateController.add(_connectionState);
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 800));
    _startSimulator();
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _stopSimulator();
    _connectionState = BleConnectionState.disconnected;
    _connectedDeviceName = null;
    _connectionStateController.add(_connectionState);
    notifyListeners();
  }

  @override
  void resetSessionCounters() {
    _currentBlowPoints.clear();
    _sessionCoughCount = 0;
    notifyListeners();
  }

  @override
  void triggerSimulatorBlow({bool simulateObstruction = false}) {
    startSimulatedSpirometryBlow(simulateObstruction: simulateObstruction);
  }

  @override
  void startSimulatedSpirometryBlow({bool simulateObstruction = false}) {
    _blowSimTimer?.cancel();
    _currentBlowPoints.clear();
    _isBlowing = true;
    notifyListeners();

    double elapsed = 0.0;
    double cumulativeVol = 0.0;
    const intervalMs = 50;
    final maxVol = simulateObstruction ? 2.40 : 3.85;
    final peakFlow = simulateObstruction ? 3.8 : 7.5;
    final decayRate = simulateObstruction ? 0.6 : 1.1;

    _blowSimTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      elapsed += (intervalMs / 1000.0);

      double flowLps = 0.0;
      if (elapsed <= 0.2) {
        flowLps = (elapsed / 0.2) * peakFlow;
      } else {
        flowLps = peakFlow * exp(-decayRate * (elapsed - 0.2));
      }
      flowLps = max(0.0, flowLps);

      cumulativeVol += flowLps * (intervalMs / 1000.0);
      cumulativeVol = min(maxVol, cumulativeVol);

      final point = SpirometryPoint(
        timeSec: elapsed,
        flowLps: flowLps,
        volumeLiters: cumulativeVol,
        pressureKpa: (flowLps / peakFlow) * 1.84,
      );

      _currentBlowPoints.add(point);
      _spirometryController.add(point);
      notifyListeners();

      if (elapsed >= 4.5 || (elapsed > 1.0 && flowLps <= 0.05)) {
        _isBlowing = false;
        timer.cancel();
        notifyListeners();
      }
    });
  }

  @override
  void triggerSimulatedCough() {
    _sessionCoughCount++;
    _latestAcoustic = AcousticReading(
      rmsAmplitude: 0.85,
      coughDetected: true,
      dominantFreqHz: 350.0,
      timestamp: DateTime.now(),
    );
    _acousticController.add(_latestAcoustic);
    notifyListeners();
  }

  @override
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

  @override
  void toggleSimulatorMode(bool enable) {
    // Controlled via AppBleService
  }

  @override
  void dispose() {
    _stopSimulator();
    _connectionStateController.close();
    _sensorReadingController.close();
    _vitalsController.close();
    _spirometryController.close();
    _acousticController.close();
    super.dispose();
  }
}

/// Unified BLE Service Manager that dynamically switches between RealBleService and MockBleService.
class AppBleService extends ChangeNotifier implements BleService {
  late RealBleService _realBleService;
  late MockBleService _mockBleService;
  bool _isSimulatorMode = true;

  final _connectionStateController = StreamController<BleConnectionState>.broadcast();
  final _sensorReadingController = StreamController<SensorReading>.broadcast();
  final _vitalsController = StreamController<VitalsReading>.broadcast();
  final _spirometryController = StreamController<SpirometryPoint>.broadcast();
  final _acousticController = StreamController<AcousticReading>.broadcast();

  final List<StreamSubscription> _delegatedSubs = [];

  AppBleService({bool initialSimulatorMode = true}) {
    _isSimulatorMode = initialSimulatorMode;
    _realBleService = RealBleService();
    _mockBleService = MockBleService(startConnected: initialSimulatorMode);

    _realBleService.addListener(_onActiveServiceChanged);
    _mockBleService.addListener(_onActiveServiceChanged);

    _bindActiveStreams();
  }

  BleService get _activeService => _isSimulatorMode ? _mockBleService : _realBleService;

  void _bindActiveStreams() {
    for (final s in _delegatedSubs) {
      s.cancel();
    }
    _delegatedSubs.clear();

    _delegatedSubs.add(_activeService.connectionStateStream.listen(_connectionStateController.add));
    _delegatedSubs.add(_activeService.sensorReadingStream.listen(_sensorReadingController.add));
    _delegatedSubs.add(_activeService.vitalsStream.listen(_vitalsController.add));
    _delegatedSubs.add(_activeService.spirometryStream.listen(_spirometryController.add));
    _delegatedSubs.add(_activeService.acousticStream.listen(_acousticController.add));
  }

  void _onActiveServiceChanged() {
    notifyListeners();
  }

  @override
  bool get isSimulatorMode => _isSimulatorMode;

  @override
  BleConnectionState get connectionState => _activeService.connectionState;

  @override
  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;

  @override
  Stream<SensorReading> get sensorReadingStream => _sensorReadingController.stream;

  @override
  Stream<VitalsReading> get vitalsStream => _vitalsController.stream;

  @override
  Stream<SpirometryPoint> get spirometryStream => _spirometryController.stream;

  @override
  Stream<AcousticReading> get acousticStream => _acousticController.stream;

  @override
  VitalsReading get latestVitals => _activeService.latestVitals;

  @override
  AcousticReading get latestAcoustic => _activeService.latestAcoustic;

  @override
  List<SpirometryPoint> get currentBlowPoints => _activeService.currentBlowPoints;

  @override
  int get sessionCoughCount => _activeService.sessionCoughCount;

  @override
  bool get isBlowing => _activeService.isBlowing;

  @override
  String? get connectedDeviceName => _activeService.connectedDeviceName;

  @override
  String? get errorMessage => _activeService.errorMessage;

  @override
  List<BleDeviceModel> get discoveredDevices => _activeService.discoveredDevices;

  @override
  Future<void> startScan({Duration timeout = BleConfig.scanTimeout}) => _activeService.startScan(timeout: timeout);

  @override
  Future<void> stopScan() => _activeService.stopScan();

  @override
  Future<void> connectToDevice(dynamic device) => _activeService.connectToDevice(device);

  @override
  Future<void> disconnect() => _activeService.disconnect();

  @override
  void toggleSimulatorMode(bool enable) {
    if (_isSimulatorMode == enable) return;
    _isSimulatorMode = enable;
    if (_isSimulatorMode) {
      _realBleService.disconnect();
      _mockBleService.startSimulator();
    } else {
      _mockBleService.disconnect();
      _realBleService.disconnect();
    }
    _bindActiveStreams();
    notifyListeners();
  }

  @override
  void resetSessionCounters() => _activeService.resetSessionCounters();

  @override
  SpirometrySummary computeSpirometrySummary() => _activeService.computeSpirometrySummary();

  @override
  void triggerSimulatorBlow({bool simulateObstruction = false}) =>
      _activeService.triggerSimulatorBlow(simulateObstruction: simulateObstruction);

  @override
  void startSimulatedSpirometryBlow({bool simulateObstruction = false}) =>
      _activeService.startSimulatedSpirometryBlow(simulateObstruction: simulateObstruction);

  @override
  void triggerSimulatedCough() => _activeService.triggerSimulatedCough();

  @override
  void dispose() {
    for (final s in _delegatedSubs) {
      s.cancel();
    }
    _delegatedSubs.clear();
    _realBleService.removeListener(_onActiveServiceChanged);
    _mockBleService.removeListener(_onActiveServiceChanged);
    _realBleService.dispose();
    _mockBleService.dispose();
    _connectionStateController.close();
    _sensorReadingController.close();
    _vitalsController.close();
    _spirometryController.close();
    _acousticController.close();
    super.dispose();
  }
}
