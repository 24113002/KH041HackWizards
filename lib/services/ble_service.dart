import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';
import '../config/ble_config.dart';
import '../models/ble_device_model.dart';
import '../models/sensor_data_model.dart';
import '../models/sensor_reading_model.dart';
import '../models/swaas_ai_ble_result.dart';
import 'sensor_data_parser.dart';
import 'swaas_ai_packet_parser.dart';
import 'wifi_device_service.dart';

enum HardwareTransportMode {
  ble,
  wifi,
  simulator,
}

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  discoveringServices,
  ready,
  receivingResult,
  connectionLost,
  error,
}

extension BleConnectionStateExtension on BleConnectionState {
  String get label {
    switch (this) {
      case BleConnectionState.disconnected:
        return 'Disconnected';
      case BleConnectionState.scanning:
        return 'Scanning';
      case BleConnectionState.connecting:
        return 'Connecting...';
      case BleConnectionState.connected:
        return 'Connected';
      case BleConnectionState.discoveringServices:
        return 'Discovering Services...';
      case BleConnectionState.ready:
        return 'Ready';
      case BleConnectionState.receivingResult:
        return 'Receiving Result...';
      case BleConnectionState.connectionLost:
        return 'Connection Lost';
      case BleConnectionState.error:
        return 'Connection Error';
    }
  }

  String get iconEmoji {
    switch (this) {
      case BleConnectionState.disconnected:
        return '🔴';
      case BleConnectionState.scanning:
      case BleConnectionState.connecting:
      case BleConnectionState.discoveringServices:
        return '🟡';
      case BleConnectionState.connected:
      case BleConnectionState.ready:
        return '🟢';
      case BleConnectionState.receivingResult:
        return '🔵';
      case BleConnectionState.connectionLost:
      case BleConnectionState.error:
        return '🔴';
    }
  }
}

/// Abstract BLE Service contract required for hardware-to-mobile sensor acquisition.
abstract class BleService extends ChangeNotifier {
  BleConnectionState get connectionState;
  Stream<BleConnectionState> get connectionStateStream;
  Stream<SensorReading> get sensorReadingStream;
  Stream<VitalsReading> get vitalsStream;
  Stream<SpirometryPoint> get spirometryStream;
  Stream<AcousticReading> get acousticStream;
  Stream<SwaasAiBleResult> get screeningResultStream;

  SwaasAiBleResult? get latestScreeningResult;
  String? get lastRawPacket;
  DateTime? get lastPacketTime;

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
  Future<SwaasAiBleResult?> readLatestResult();
  void emitMockScreeningResult({String? rawPacket});
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
  BluetoothCharacteristic? _screeningResultCharacteristic;

  final List<BleDeviceModel> _discoveredDevices = [];
  @override
  List<BleDeviceModel> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  SwaasAiBleResult? _latestScreeningResult;
  @override
  SwaasAiBleResult? get latestScreeningResult => _latestScreeningResult;

  String? _lastRawPacket;
  @override
  String? get lastRawPacket => _lastRawPacket;

  DateTime? _lastPacketTime;
  @override
  DateTime? get lastPacketTime => _lastPacketTime;

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

  final _screeningResultController = StreamController<SwaasAiBleResult>.broadcast();
  @override
  Stream<SwaasAiBleResult> get screeningResultStream => _screeningResultController.stream;

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

      // 1. Request Runtime Permissions on Android (Android 11 requires Location permission for BLE scan)
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final statuses = await [
            Permission.location,
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
          ].request();
          debugPrint('[RealBleService] Permission request results: $statuses');
        } catch (pe) {
          debugPrint('[RealBleService] Permission request notice: $pe');
        }
      }

      // 2. Verify Bluetooth Hardware Support
      if (await FlutterBluePlus.isSupported == false) {
        _setConnectionState(
          BleConnectionState.error,
          error: 'Bluetooth Low Energy is not supported on this device.',
        );
        return;
      }

      // 3. Verify Bluetooth Power State
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _setConnectionState(
          BleConnectionState.disconnected,
          error: 'Bluetooth is turned off. Please enable Bluetooth to connect the screening device.',
        );
        return;
      }

      _setConnectionState(BleConnectionState.scanning);

      // Only retrieve bonded/system devices if they belong to SwasthAI / ESP32
      try {
        final systemDevs = await FlutterBluePlus.systemDevices([]);
        final bondedDevs = await FlutterBluePlus.bondedDevices;
        final allKnown = {...systemDevs, ...bondedDevs};
        for (final dev in allKnown) {
          final devName = dev.platformName.isNotEmpty ? dev.platformName : dev.advName;
          final isEsp = dev.remoteId.str.toUpperCase() == '1C:C3:AB:B3:03:A2' ||
              BleConfig.devicePrefixes.any((p) => devName.toLowerCase().contains(p.toLowerCase()));
          if (isEsp) {
            final model = BleDeviceModel(
              id: dev.remoteId.str,
              name: devName.isNotEmpty ? devName : 'SWASTHAI-ESP32',
              rssi: -50,
              platformDevice: dev,
            );
            if (!_discoveredDevices.any((d) => d.id == model.id)) {
              _discoveredDevices.add(model);
            }
          }
        }
        if (_discoveredDevices.isNotEmpty) notifyListeners();
      } catch (e) {
        debugPrint('[RealBleService] systemDevices check note: $e');
      }

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final rawName = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : (r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : r.device.advName);

          final isKnownMac = r.device.remoteId.str.toUpperCase() == '1C:C3:AB:B3:03:A2';
          final matchesPrefix = BleConfig.devicePrefixes.any(
            (prefix) => rawName.toLowerCase().contains(prefix.toLowerCase()),
          );
          final matchesService = r.advertisementData.serviceUuids.any(
            (uuid) {
              final u = uuid.toString().toLowerCase().replaceAll('-', '');
              return u == BleConfig.serviceUuid.toLowerCase().replaceAll('-', '') ||
                     u == BleConfig.alternateServiceUuid.toLowerCase().replaceAll('-', '');
            },
          );

          final isSwasthAiDevice = isKnownMac || matchesPrefix || matchesService;

          // Only show devices that have a readable broadcast name or match SwasthAI / ESP32
          if (isSwasthAiDevice || (rawName.trim().isNotEmpty && rawName.length > 2)) {
            final displayName = isKnownMac
                ? (rawName.isNotEmpty ? rawName : 'SWASTHAI-ESP32')
                : rawName;

            final model = BleDeviceModel(
              id: r.device.remoteId.str,
              name: displayName,
              rssi: r.rssi,
              platformDevice: r.device,
            );

            final existingIndex = _discoveredDevices.indexWhere((d) => d.id == model.id);
            if (existingIndex >= 0) {
              if (rawName.isNotEmpty) {
                _discoveredDevices[existingIndex] = model;
              }
            } else {
              if (isSwasthAiDevice) {
                _discoveredDevices.insert(0, model);
              } else {
                _discoveredDevices.add(model);
              }
            }
            notifyListeners();
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      if (_connectionState == BleConnectionState.scanning) {
        _setConnectionState(BleConnectionState.disconnected);
      }
    } catch (e) {
      debugPrint('[RealBleService] Scan error: $e');
      _setConnectionState(
        BleConnectionState.error,
        error: 'Bluetooth access error: $e',
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
        BleConnectionState.error,
        error: 'Invalid device selected.',
      );
      return;
    }

    try {
      await stopScan();
      await Future.delayed(const Duration(milliseconds: 300));
      _setConnectionState(BleConnectionState.connecting);
      _connectedDevice = targetBleDevice;
      _connectedDeviceName = targetBleDevice.platformName.isNotEmpty
          ? targetBleDevice.platformName
          : BleConfig.targetDeviceName;

      // Clean disconnect stale handles & clear Android GATT cache if any
      try {
        await targetBleDevice.disconnect();
        await targetBleDevice.clearGattCache();
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {}

      // Connect with configured timeout & retry for Android Error 133
      bool connected = false;
      int attempts = 0;
      while (!connected && attempts < 2) {
        attempts++;
        try {
          await targetBleDevice.connect(
            timeout: BleConfig.connectTimeout,
            autoConnect: false,
            mtu: null,
          );
          connected = true;
        } catch (connErr) {
          debugPrint('[RealBleService] Connect attempt $attempts error: $connErr');
          if (attempts < 2) {
            try {
              await targetBleDevice.clearGattCache();
            } catch (_) {}
            await Future.delayed(const Duration(milliseconds: 800));
          } else {
            rethrow;
          }
        }
      }

      _setConnectionState(BleConnectionState.connected);

      // Listen for unexpected connection drops
      _deviceStateSubscription?.cancel();
      _deviceStateSubscription = targetBleDevice.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('[RealBleService] Device disconnected.');
          _handleDisconnection();
        }
      });

      // Request MTU negotiation
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await targetBleDevice.requestMtu(512);
        } catch (_) {}
      }

      // Discover GATT Services
      _setConnectionState(BleConnectionState.discoveringServices);
      final services = await targetBleDevice.discoverServices();
      final hasSetupCharacteristic = await _setupHardwareContract(services);

      if (hasSetupCharacteristic) {
        _setConnectionState(BleConnectionState.ready);
      } else {
        _setConnectionState(
          BleConnectionState.error,
          error: 'Required SwasAI BLE characteristic was not found.',
        );
      }
    } catch (e) {
      debugPrint('[RealBleService] Connection error: $e');
      _setConnectionState(
        BleConnectionState.error,
        error: 'Failed to connect to SwasthAI device. If error persists, toggle Bluetooth OFF/ON or unpair the device in phone settings.',
      );
    }
  }

  Future<bool> _setupHardwareContract(List<BluetoothService> services) async {
    for (final sub in _characteristicSubscriptions) {
      await sub.cancel();
    }
    _characteristicSubscriptions.clear();
    _screeningResultCharacteristic = null;

    final targetServiceUuidNorm = BleConfig.serviceUuid.toLowerCase().replaceAll('-', '');
    final targetCharUuidNorm = BleConfig.screeningResultCharacteristicUuid.toLowerCase().replaceAll('-', '');

    for (final s in services) {
      final serviceUuidNorm = s.uuid.toString().toLowerCase().replaceAll('-', '');
      final isMatchingService = serviceUuidNorm == targetServiceUuidNorm;

      for (final c in s.characteristics) {
        final charUuidNorm = c.uuid.toString().toLowerCase().replaceAll('-', '');

        // 1. Official Hardware Contract Characteristic (READ + NOTIFY)
        if (charUuidNorm == targetCharUuidNorm ||
            (isMatchingService && (c.properties.notify || c.properties.read))) {
          _screeningResultCharacteristic = c;

          if (c.properties.notify) {
            try {
              await c.setNotifyValue(true);
              final sub = c.onValueReceived.listen((bytes) {
                _onSwaasAiPacketReceived(bytes);
              });
              _characteristicSubscriptions.add(sub);
              debugPrint('[RealBleService] Subscribed to NOTIFY on ${c.uuid}');
            } catch (e) {
              debugPrint('[RealBleService] Failed to setNotifyValue: $e');
            }
          }
        }

        // 2. Compatibility Vitals characteristic (Phase 3 fallback)
        if (charUuidNorm == BleConfig.vitalsCharacteristicUuid.toLowerCase().replaceAll('-', '')) {
          if (c.properties.notify) {
            try {
              await c.setNotifyValue(true);
              final sub = c.onValueReceived.listen((bytes) {
                _onVitalsPacketReceived(bytes);
              });
              _characteristicSubscriptions.add(sub);
            } catch (_) {}
          }
        }

        // 3. Compatibility Airflow characteristic
        if (charUuidNorm == BleConfig.airflowCharacteristicUuid.toLowerCase().replaceAll('-', '')) {
          if (c.properties.notify) {
            try {
              await c.setNotifyValue(true);
              final sub = c.onValueReceived.listen((bytes) {
                _onAirflowPacketReceived(bytes);
              });
              _characteristicSubscriptions.add(sub);
            } catch (_) {}
          }
        }

        // 4. Compatibility Acoustic characteristic
        if (charUuidNorm == BleConfig.acousticCharacteristicUuid.toLowerCase().replaceAll('-', '')) {
          if (c.properties.notify) {
            try {
              await c.setNotifyValue(true);
              final sub = c.onValueReceived.listen((bytes) {
                _onAcousticPacketReceived(bytes);
              });
              _characteristicSubscriptions.add(sub);
            } catch (_) {}
          }
        }
      }
    }

    return _screeningResultCharacteristic != null || _characteristicSubscriptions.isNotEmpty;
  }

  @override
  Future<SwaasAiBleResult?> readLatestResult() async {
    if (_screeningResultCharacteristic == null) {
      debugPrint('[RealBleService] Cannot READ: screening characteristic is null.');
      _errorMessage = 'Required SwasAI BLE characteristic was not found.';
      notifyListeners();
      return null;
    }

    try {
      _setConnectionState(BleConnectionState.receivingResult);
      final bytes = await _screeningResultCharacteristic!.read();
      final result = _onSwaasAiPacketReceived(bytes);
      _setConnectionState(BleConnectionState.ready);
      return result;
    } catch (e) {
      debugPrint('[RealBleService] READ error: $e');
      _setConnectionState(
        BleConnectionState.ready,
        error: 'Failed to read result from device: $e',
      );
      return null;
    }
  }

  SwaasAiBleResult? _onSwaasAiPacketReceived(List<int> bytes) {
    if (bytes.isEmpty) return null;

    final rawString = utf8.decode(bytes, allowMalformed: true).trim();
    _lastRawPacket = rawString;
    _lastPacketTime = DateTime.now();

    final result = SwaasAiPacketParser.tryParse(rawString);
    if (result != null) {
      _latestScreeningResult = result;
      _screeningResultController.add(result);

      // Backwards compatibility updates for vitals and sensor reading stream
      if (result.spo2 != null) {
        _latestVitals = VitalsReading(
          heartRate: 0,
          spo2: result.spo2!,
          ppgValue: 0.5,
          timestamp: DateTime.now(),
        );
        _vitalsController.add(_latestVitals);
      }

      _sensorReadingController.add(
        SensorReading(
          id: result.id,
          screeningId: 'ble_${result.id}',
          timestamp: DateTime.now(),
          spo2: result.spo2,
          heartRate: null,
          pressure: result.airflow != null ? (result.airflow! / 10000.0) : null,
          coughActivity: result.cough != null ? (result.cough! / 2000.0).clamp(0.0, 1.0) : null,
        ),
      );

      notifyListeners();
      return result;
    } else {
      debugPrint('[RealBleService] Malformed packet received: "$rawString"');
      _errorMessage = 'Invalid screening result received.';
      notifyListeners();
      return null;
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
        error: 'Device disconnected. Previously collected data is preserved.',
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
    _screeningResultCharacteristic = null;
  }

  @override
  void emitMockScreeningResult({String? rawPacket}) {
    final packet = rawPacket ?? 'R01,42350,97,1860,42,MODERATE';
    _onSwaasAiPacketReceived(utf8.encode(packet));
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
  void toggleSimulatorMode(bool enable) {}

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
    _screeningResultController.close();
    super.dispose();
  }
}

/// Mock BLE Service implementation simulating SwaasAI ESP32 hardware for testing and development.
class MockBleService extends ChangeNotifier implements BleService {
  BleConnectionState _connectionState = BleConnectionState.ready;
  @override
  BleConnectionState get connectionState => _connectionState;

  @override
  bool get isSimulatorMode => true;

  String? _connectedDeviceName = 'SwaasAI_ESP32 (Simulated)';
  @override
  String? get connectedDeviceName => _connectedDeviceName;

  @override
  String? get errorMessage => null;

  final List<BleDeviceModel> _discoveredDevices = [
    const BleDeviceModel(
      id: 'MOCK_SWAASAI_01',
      name: BleConfig.targetDeviceName,
      rssi: -58,
      isConnected: true,
    ),
  ];
  @override
  List<BleDeviceModel> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  SwaasAiBleResult? _latestScreeningResult;
  @override
  SwaasAiBleResult? get latestScreeningResult => _latestScreeningResult;

  String? _lastRawPacket;
  @override
  String? get lastRawPacket => _lastRawPacket;

  DateTime? _lastPacketTime;
  @override
  DateTime? get lastPacketTime => _lastPacketTime;

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

  final _screeningResultController = StreamController<SwaasAiBleResult>.broadcast();
  @override
  Stream<SwaasAiBleResult> get screeningResultStream => _screeningResultController.stream;

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
    _connectionState = BleConnectionState.ready;
    _connectedDeviceName = 'SwaasAI_ESP32 (Simulated)';
    _connectionStateController.add(_connectionState);

    // Provide default initial mock packet
    _lastRawPacket = 'R01,42350,97,1860,42,MODERATE';
    _lastPacketTime = DateTime.now();
    _latestScreeningResult = SwaasAiPacketParser.tryParse(_lastRawPacket!);

    _vitalsSimTimer?.cancel();
    _vitalsSimTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_connectionState != BleConnectionState.ready && _connectionState != BleConnectionState.connected) return;

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
      if (_connectionState != BleConnectionState.ready && _connectionState != BleConnectionState.connected) return;
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

    await Future.delayed(const Duration(milliseconds: 600));
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

    await Future.delayed(const Duration(milliseconds: 400));
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
  Future<SwaasAiBleResult?> readLatestResult() async {
    _connectionState = BleConnectionState.receivingResult;
    _connectionStateController.add(_connectionState);
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));
    final packet = _lastRawPacket ?? 'R01,42350,97,1860,42,MODERATE';
    final result = SwaasAiPacketParser.parse(packet);
    _latestScreeningResult = result;
    _lastPacketTime = DateTime.now();
    _screeningResultController.add(result);

    _connectionState = BleConnectionState.ready;
    _connectionStateController.add(_connectionState);
    notifyListeners();
    return result;
  }

  @override
  void emitMockScreeningResult({String? rawPacket}) {
    final packet = rawPacket ?? 'R01,42350,97,1860,42,MODERATE';
    _lastRawPacket = packet;
    _lastPacketTime = DateTime.now();
    final result = SwaasAiPacketParser.tryParse(packet);
    if (result != null) {
      _latestScreeningResult = result;
      _screeningResultController.add(result);
      notifyListeners();
    }
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
  void toggleSimulatorMode(bool enable) {}

  @override
  void dispose() {
    _stopSimulator();
    _connectionStateController.close();
    _sensorReadingController.close();
    _vitalsController.close();
    _spirometryController.close();
    _acousticController.close();
    _screeningResultController.close();
    super.dispose();
  }
}

/// Adapter allowing WifiDeviceService to satisfy the BleService contract seamlessly.
class WifiBleAdapter extends ChangeNotifier implements BleService {
  final WifiDeviceService wifiService;

  WifiBleAdapter(this.wifiService) {
    wifiService.addListener(notifyListeners);
  }

  @override
  BleConnectionState get connectionState {
    switch (wifiService.state) {
      case WifiConnectionState.connected:
        return BleConnectionState.ready;
      case WifiConnectionState.connecting:
        return BleConnectionState.connecting;
      case WifiConnectionState.error:
        return BleConnectionState.error;
      case WifiConnectionState.disconnected:
        return BleConnectionState.disconnected;
    }
  }

  @override
  Stream<BleConnectionState> get connectionStateStream => wifiService.connectionStateStream;
  @override
  Stream<SensorReading> get sensorReadingStream => wifiService.sensorReadingStream;
  @override
  Stream<VitalsReading> get vitalsStream => wifiService.vitalsStream;
  @override
  Stream<SpirometryPoint> get spirometryStream => wifiService.spirometryStream;
  @override
  Stream<AcousticReading> get acousticStream => wifiService.acousticStream;
  @override
  Stream<SwaasAiBleResult> get screeningResultStream => wifiService.screeningResultStream;

  @override
  SwaasAiBleResult? get latestScreeningResult => wifiService.latestScreeningResult;
  @override
  String? get lastRawPacket => wifiService.lastRawPacket;
  @override
  DateTime? get lastPacketTime => wifiService.lastPacketTime;

  @override
  VitalsReading get latestVitals => wifiService.latestVitals;
  @override
  AcousticReading get latestAcoustic => wifiService.latestAcoustic;
  @override
  List<SpirometryPoint> get currentBlowPoints => wifiService.currentBlowPoints;
  @override
  int get sessionCoughCount => wifiService.sessionCoughCount;
  @override
  bool get isSimulatorMode => false;
  @override
  bool get isBlowing => wifiService.isBlowing;
  @override
  String? get connectedDeviceName => 'ESP32 Wi-Fi (${wifiService.targetIp})';
  @override
  String? get errorMessage => wifiService.errorMessage;
  @override
  List<BleDeviceModel> get discoveredDevices => const [];

  @override
  Future<void> startScan({Duration timeout = BleConfig.scanTimeout}) async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<void> connectToDevice(dynamic device) async {}
  @override
  Future<void> disconnect() async => wifiService.disconnect();
  @override
  Future<SwaasAiBleResult?> readLatestResult() async => wifiService.latestScreeningResult;
  @override
  void emitMockScreeningResult({String? rawPacket}) {}
  @override
  void toggleSimulatorMode(bool enable) {}
  @override
  void resetSessionCounters() => wifiService.resetSessionCounters();
  @override
  SpirometrySummary computeSpirometrySummary() => wifiService.computeSpirometrySummary();
  @override
  void triggerSimulatorBlow({bool simulateObstruction = false}) {}
  @override
  void startSimulatedSpirometryBlow({bool simulateObstruction = false}) {}
  @override
  void triggerSimulatedCough() {}
}

/// Unified Device Connection Manager supporting BLE, Wi-Fi, and Simulator.
class AppBleService extends ChangeNotifier implements BleService {
  late RealBleService _realBleService;
  late MockBleService _mockBleService;
  late WifiDeviceService _wifiService;
  late WifiBleAdapter _wifiAdapter;
  HardwareTransportMode _transportMode = HardwareTransportMode.ble;

  final _connectionStateController = StreamController<BleConnectionState>.broadcast();
  final _sensorReadingController = StreamController<SensorReading>.broadcast();
  final _vitalsController = StreamController<VitalsReading>.broadcast();
  final _spirometryController = StreamController<SpirometryPoint>.broadcast();
  final _acousticController = StreamController<AcousticReading>.broadcast();
  final _screeningResultController = StreamController<SwaasAiBleResult>.broadcast();

  final List<StreamSubscription> _delegatedSubs = [];

  AppBleService({bool initialSimulatorMode = true}) {
    _transportMode = initialSimulatorMode ? HardwareTransportMode.simulator : HardwareTransportMode.ble;
    _realBleService = RealBleService();
    _mockBleService = MockBleService(startConnected: initialSimulatorMode);
    _wifiService = WifiDeviceService();
    _wifiAdapter = WifiBleAdapter(_wifiService);

    _realBleService.addListener(_onActiveServiceChanged);
    _mockBleService.addListener(_onActiveServiceChanged);
    _wifiAdapter.addListener(_onActiveServiceChanged);

    _bindActiveStreams();
  }

  HardwareTransportMode get transportMode => _transportMode;
  WifiDeviceService get wifiService => _wifiService;
  bool get isWifiMode => _transportMode == HardwareTransportMode.wifi;

  BleService get _activeService {
    switch (_transportMode) {
      case HardwareTransportMode.wifi:
        return _wifiAdapter;
      case HardwareTransportMode.simulator:
        return _mockBleService;
      case HardwareTransportMode.ble:
        return _realBleService;
    }
  }

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
    _delegatedSubs.add(_activeService.screeningResultStream.listen(_screeningResultController.add));
  }

  void _onActiveServiceChanged() {
    notifyListeners();
  }

  /// Switch transport to Wi-Fi mode
  void switchToWifiMode() {
    if (_transportMode == HardwareTransportMode.wifi) return;
    _realBleService.disconnect();
    _mockBleService.disconnect();
    _transportMode = HardwareTransportMode.wifi;
    _bindActiveStreams();
    notifyListeners();
  }

  /// Switch transport to Wi-Fi mode and connect to target IP
  Future<bool> connectWifi({String ip = '192.168.4.1', int port = 80}) async {
    _realBleService.disconnect();
    _mockBleService.disconnect();
    _transportMode = HardwareTransportMode.wifi;
    _bindActiveStreams();
    notifyListeners();
    return await _wifiService.connect(ip: ip, port: port);
  }

  /// Switch transport to BLE mode
  void switchToBleMode() {
    if (_transportMode == HardwareTransportMode.ble) return;
    _wifiService.disconnect();
    _mockBleService.disconnect();
    _transportMode = HardwareTransportMode.ble;
    _bindActiveStreams();
    notifyListeners();
  }

  @override
  bool get isSimulatorMode => _transportMode == HardwareTransportMode.simulator;

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
  Stream<SwaasAiBleResult> get screeningResultStream => _screeningResultController.stream;

  @override
  SwaasAiBleResult? get latestScreeningResult => _activeService.latestScreeningResult;

  @override
  String? get lastRawPacket => _activeService.lastRawPacket;

  @override
  DateTime? get lastPacketTime => _activeService.lastPacketTime;

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
  Future<SwaasAiBleResult?> readLatestResult() => _activeService.readLatestResult();

  @override
  void emitMockScreeningResult({String? rawPacket}) => _activeService.emitMockScreeningResult(rawPacket: rawPacket);

  @override
  void toggleSimulatorMode(bool enable) {
    if (enable) {
      if (_transportMode == HardwareTransportMode.simulator) return;
      _realBleService.disconnect();
      _wifiService.disconnect();
      _transportMode = HardwareTransportMode.simulator;
      _mockBleService.startSimulator();
    } else {
      _mockBleService.disconnect();
      _transportMode = HardwareTransportMode.ble;
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
    _wifiAdapter.removeListener(_onActiveServiceChanged);
    _realBleService.dispose();
    _mockBleService.dispose();
    _wifiService.dispose();
    _connectionStateController.close();
    _sensorReadingController.close();
    _vitalsController.close();
    _spirometryController.close();
    _acousticController.close();
    _screeningResultController.close();
    super.dispose();
  }
}
