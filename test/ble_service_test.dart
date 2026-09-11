import 'package:flutter_test/flutter_test.dart';
import 'package:swasthai/config/ble_config.dart';
import 'package:swasthai/models/ble_device_model.dart';
import 'package:swasthai/models/swaas_ai_ble_result.dart';
import 'package:swasthai/services/ble_service.dart';

void main() {
  group('BLE Architecture & Services Tests', () {
    test('1. BleDeviceModel calculates signal strength descriptions accurately', () {
      const strongDev = BleDeviceModel(id: '1', name: 'SwaasAI_ESP32', rssi: -55);
      expect(strongDev.signalStrengthDescription, equals('Strong'));

      const goodDev = BleDeviceModel(id: '2', name: 'SwaasAI_ESP32', rssi: -70);
      expect(goodDev.signalStrengthDescription, equals('Good'));

      const fairDev = BleDeviceModel(id: '3', name: 'SwaasAI_ESP32', rssi: -80);
      expect(fairDev.signalStrengthDescription, equals('Fair'));

      const weakDev = BleDeviceModel(id: '4', name: 'SwaasAI_ESP32', rssi: -95);
      expect(weakDev.signalStrengthDescription, equals('Weak'));
    });

    test('2. BleConfig constants are defined safely without missing UUIDs', () {
      expect(BleConfig.targetDeviceName, equals('SwaasAI_ESP32'));
      expect(BleConfig.serviceUuid, equals('12345678-1234-1234-1234-1234567890AB'));
      expect(BleConfig.screeningResultCharacteristicUuid, equals('12345678-1234-1234-1234-1234567890AC'));
      expect(BleConfig.devicePrefixes, contains('SwaasAI'));
      expect(BleConfig.devicePrefixes, contains('SwasthAI'));
      expect(BleConfig.maxAutoReconnectAttempts, equals(3));
    });

    test('3. MockBleService generates continuous vitals stream and sensor readings', () async {
      final mockBle = MockBleService(startConnected: true);
      expect(mockBle.isSimulatorMode, isTrue);
      expect(mockBle.connectionState, equals(BleConnectionState.ready));

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
      expect(mockBle.connectionState, equals(BleConnectionState.ready));

      await mockBle.disconnect();
      expect(mockBle.connectionState, equals(BleConnectionState.disconnected));
      expect(mockBle.connectedDeviceName, isNull);

      await mockBle.connectToDevice(null);
      expect(mockBle.connectionState, equals(BleConnectionState.ready));
      expect(mockBle.connectedDeviceName, contains('SwaasAI_ESP32'));

      mockBle.dispose();
    });

    test('7. AppBleService smoothly delegates between Simulator and Real BLE', () {
      final appBle = AppBleService(initialSimulatorMode: true);
      expect(appBle.isSimulatorMode, isTrue);
      expect(appBle.connectionState, equals(BleConnectionState.ready));

      appBle.toggleSimulatorMode(false);
      expect(appBle.isSimulatorMode, isFalse);
      expect(appBle.connectionState, equals(BleConnectionState.disconnected));

      appBle.toggleSimulatorMode(true);
      expect(appBle.isSimulatorMode, isTrue);
      expect(appBle.connectionState, equals(BleConnectionState.ready));

      appBle.dispose();
    });

    test('8. MockBleService emits screening result on readLatestResult and emitMockScreeningResult', () async {
      final mockBle = MockBleService(startConnected: true);

      final result = await mockBle.readLatestResult();
      expect(result, isNotNull);
      expect(result!.id, startsWith('R'));
      expect(result.status, isA<SwaasAiStatus>());
      expect(mockBle.latestScreeningResult, equals(result));

      // Test manual packet emission
      mockBle.emitMockScreeningResult(rawPacket: 'R99,44000,99,1100,10,LOW');
      expect(mockBle.latestScreeningResult!.id, equals('R99'));
      expect(mockBle.latestScreeningResult!.status, equals(SwaasAiStatus.low));
      expect(mockBle.latestScreeningResult!.risk, equals(10));

      mockBle.dispose();
    });
  });
}
