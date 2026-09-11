import 'package:flutter_test/flutter_test.dart';
import 'package:swasthai/config/ble_config.dart';
import 'package:swasthai/models/ble_device_model.dart';
import 'package:swasthai/services/ble_service.dart';

void main() {
  group('BLE Architecture & Services Tests', () {
    test('1. BleDeviceModel calculates signal strength descriptions accurately', () {
      const strongDev = BleDeviceModel(id: '1', name: 'SWASTHAI_ESP32', rssi: -55);
      expect(strongDev.signalStrengthDescription, equals('Strong'));

      const goodDev = BleDeviceModel(id: '2', name: 'SWASTHAI_ESP32', rssi: -70);
      expect(goodDev.signalStrengthDescription, equals('Good'));

      const fairDev = BleDeviceModel(id: '3', name: 'SWASTHAI_ESP32', rssi: -80);
      expect(fairDev.signalStrengthDescription, equals('Fair'));

      const weakDev = BleDeviceModel(id: '4', name: 'SWASTHAI_ESP32', rssi: -95);
      expect(weakDev.signalStrengthDescription, equals('Weak'));
    });

    test('2. BleConfig constants are defined safely without missing UUIDs', () {
      expect(BleConfig.targetDeviceName, equals('SWASTHAI_ESP32'));
      expect(BleConfig.serviceUuid, isNotEmpty);
      expect(BleConfig.vitalsCharacteristicUuid, isNotEmpty);
      expect(BleConfig.airflowCharacteristicUuid, isNotEmpty);
      expect(BleConfig.acousticCharacteristicUuid, isNotEmpty);
      expect(BleConfig.commandCharacteristicUuid, isNotEmpty);
      expect(BleConfig.maxAutoReconnectAttempts, equals(3));
    });

    test('3. MockBleService generates continuous vitals stream and sensor readings', () async {
      final mockBle = MockBleService(startConnected: true);
      expect(mockBle.isSimulatorMode, isTrue);
      expect(mockBle.connectionState, equals(BleConnectionState.connected));

      final firstVitals = await mockBle.vitalsStream.first;
      expect(firstVitals.heartRate, inInclusiveRange(70, 95));
      expect(firstVitals.spo2, equals(97));
      expect(firstVitals.ppgValue, greaterThan(0.0));

      final sensorReading = await mockBle.sensorReadingStream.first;
      expect(sensorReading.spo2, equals(97));
      expect(sensorReading.heartRate, inInclusiveRange(70, 95));

      mockBle.dispose();
    });

    test('4. MockBleService simulates forced expiratory spirometry blow', () async {
      final mockBle = MockBleService(startConnected: true);
      mockBle.resetSessionCounters();

      expect(mockBle.currentBlowPoints.isEmpty, isTrue);

      mockBle.startSimulatedSpirometryBlow(simulateObstruction: false);
      expect(mockBle.isBlowing, isTrue);

      await Future.delayed(const Duration(milliseconds: 300));
      expect(mockBle.currentBlowPoints.isNotEmpty, isTrue);

      final summary = mockBle.computeSpirometrySummary();
      expect(summary.fvc, greaterThan(0.0));
      expect(summary.fev1, greaterThan(0.0));
      expect(summary.pefLpm, greaterThan(0.0));
      expect(summary.fev1FvcRatio, greaterThan(0.0));

      mockBle.dispose();
    });

    test('5. MockBleService increments session cough count on simulated cough event', () {
      final mockBle = MockBleService(startConnected: true);
      mockBle.resetSessionCounters();
      expect(mockBle.sessionCoughCount, equals(0));

      mockBle.triggerSimulatedCough();
      expect(mockBle.sessionCoughCount, equals(1));
      expect(mockBle.latestAcoustic.coughDetected, isTrue);

      mockBle.triggerSimulatedCough();
      expect(mockBle.sessionCoughCount, equals(2));

      mockBle.dispose();
    });

    test('6. MockBleService handles disconnect and connect lifecycle properly', () async {
      final mockBle = MockBleService(startConnected: true);
      expect(mockBle.connectionState, equals(BleConnectionState.connected));

      await mockBle.disconnect();
      expect(mockBle.connectionState, equals(BleConnectionState.disconnected));
      expect(mockBle.connectedDeviceName, isNull);

      await mockBle.connectToDevice(null);
      expect(mockBle.connectionState, equals(BleConnectionState.connected));
      expect(mockBle.connectedDeviceName, contains('SWASTHAI_ESP32'));

      mockBle.dispose();
    });

    test('7. AppBleService smoothly delegates between Simulator and Real BLE', () {
      final appBle = AppBleService(initialSimulatorMode: true);
      expect(appBle.isSimulatorMode, isTrue);
      expect(appBle.connectionState, equals(BleConnectionState.connected));

      appBle.toggleSimulatorMode(false);
      expect(appBle.isSimulatorMode, isFalse);
      expect(appBle.connectionState, equals(BleConnectionState.disconnected));

      appBle.toggleSimulatorMode(true);
      expect(appBle.isSimulatorMode, isTrue);
      expect(appBle.connectionState, equals(BleConnectionState.connected));

      appBle.dispose();
    });
  });
}
