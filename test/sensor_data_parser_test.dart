import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthai/services/sensor_data_parser.dart';

void main() {
  group('SensorDataParser Tests', () {
    test('1. Parses valid composite SensorReading JSON string', () {
      const jsonStr = '{"spo2": 97, "heart_rate": 82, "pressure": 1.84, "cough_activity": 0.72}';
      final reading = SensorDataParser.parseSensorReading(jsonStr, screeningId: 'sc-101');

      expect(reading, isNotNull);
      expect(reading!.spo2, equals(97));
      expect(reading.heartRate, equals(82));
      expect(reading.pressure, equals(1.84));
      expect(reading.coughActivity, equals(0.72));
      expect(reading.screeningId, equals('sc-101'));
    });

    test('2. Parses UTF-8 bytes payload for VitalsReading (firmware format)', () {
      final bytes = utf8.encode('{"hr": 78, "spo2": 99, "ppg": 0.65}');
      final vitals = SensorDataParser.parseVitals(bytes);

      expect(vitals, isNotNull);
      expect(vitals!.heartRate, equals(78));
      expect(vitals.spo2, equals(99));
      expect(vitals.ppgValue, equals(0.65));
    });

    test('3. Parses SpirometryPoint payload with pressure and flow volume', () {
      final bytes = utf8.encode('{"t": 1.20, "f": 4.50, "v": 2.10, "p": 1.10}');
      final point = SensorDataParser.parseSpirometryPoint(bytes);

      expect(point, isNotNull);
      expect(point!.timeSec, equals(1.20));
      expect(point.flowLps, equals(4.50));
      expect(point.volumeLiters, equals(2.10));
      expect(point.pressureKpa, equals(1.10));
    });

    test('4. Parses AcousticReading payload with cough detection flag', () {
      final bytes = utf8.encode('{"rms": 0.85, "cough": 1, "freq": 340.0}');
      final acoustic = SensorDataParser.parseAcousticReading(bytes);

      expect(acoustic, isNotNull);
      expect(acoustic!.rmsAmplitude, equals(0.85));
      expect(acoustic.coughDetected, isTrue);
      expect(acoustic.dominantFreqHz, equals(340.0));
    });

    test('5. Rejects out-of-bounds physiological values safely', () {
      // SpO2 > 100 or HR < 30 should result in null for invalid fields rather than crashing
      const jsonStr = '{"spo2": 150, "heart_rate": 10, "pressure": 1.84}';
      final reading = SensorDataParser.parseSensorReading(jsonStr, screeningId: 'sc-102');

      expect(reading, isNotNull);
      expect(reading!.spo2, isNull);
      expect(reading.heartRate, isNull);
      expect(reading.pressure, equals(1.84));
    });

    test('6. Handles malformed JSON strings without throwing exceptions', () {
      const invalidJson = '{"spo2": 97, "heart_rate": ';
      final reading = SensorDataParser.parseSensorReading(invalidJson, screeningId: 'sc-103');
      expect(reading, isNull);

      final vitals = SensorDataParser.parseVitals('not a json string');
      expect(vitals, isNull);

      final spiro = SensorDataParser.parseSpirometryPoint('');
      expect(spiro, isNull);

      final acoustic = SensorDataParser.parseAcousticReading(null);
      expect(acoustic, isNull);
    });

    test('7. Preserves null for missing fields without artificial zero substitutions', () {
      const partialJson = '{"spo2": 96}';
      final reading = SensorDataParser.parseSensorReading(partialJson, screeningId: 'sc-104');

      expect(reading, isNotNull);
      expect(reading!.spo2, equals(96));
      expect(reading.heartRate, isNull);
      expect(reading.pressure, isNull);
      expect(reading.coughActivity, isNull);
    });

    test('8. Handles string numbers and map payloads safely', () {
      final map = {'spo2': '98', 'heart_rate': '85', 'pressure': '1.92'};
      final reading = SensorDataParser.parseSensorReading(map, screeningId: 'sc-105');

      expect(reading, isNotNull);
      expect(reading!.spo2, equals(98));
      expect(reading.heartRate, equals(85));
      expect(reading.pressure, equals(1.92));
    });
  });
}
