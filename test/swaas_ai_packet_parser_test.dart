import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:swasthai/models/swaas_ai_ble_result.dart';
import 'package:swasthai/services/swaas_ai_packet_parser.dart';

void main() {
  group('SwaasAiPacketParser Unit Tests', () {
    test('1. Parses valid complete screening packet successfully', () {
      const packet = 'R01,42350,97,1860,42,MODERATE';
      final result = SwaasAiPacketParser.parse(packet);

      expect(result.id, equals('R01'));
      expect(result.airflow, equals(42350));
      expect(result.spo2, equals(97));
      expect(result.cough, equals(1860));
      expect(result.risk, equals(42));
      expect(result.status, equals(SwaasAiStatus.moderate));
      expect(result.isIncomplete, isFalse);
      expect(result.formattedSpo2, equals('97 %'));
      expect(result.formattedAirflow, equals('42350'));
      expect(result.formattedCough, equals('1860'));
      expect(result.formattedRisk, equals('42 / 100'));
      expect(result.formattedStatus, equals('MODERATE'));
    });

    test('2. Parses packet with missing sensor data (NA) preserving null without converting to zero', () {
      const packet = 'R02,39120,NA,1735,NA,INCOMPLETE';
      final result = SwaasAiPacketParser.parse(packet);

      expect(result.id, equals('R02'));
      expect(result.airflow, equals(39120));
      expect(result.spo2, isNull);
      expect(result.cough, equals(1735));
      expect(result.risk, isNull);
      expect(result.status, equals(SwaasAiStatus.incomplete));
      expect(result.isIncomplete, isTrue);

      // Verify UI formatting preserves '--' and never shows '0'
      expect(result.formattedSpo2, equals('--'));
      expect(result.formattedRisk, equals('--'));
      expect(result.formattedAirflow, equals('39120'));
      expect(result.formattedCough, equals('1735'));
      expect(result.formattedStatus, equals('INCOMPLETE'));
    });

    test('3. Safely decodes UTF-8 byte array with trailing newline and carriage returns', () {
      final bytes = utf8.encode("R01,42350,97,1860,42,MODERATE\r\n");
      final result = SwaasAiPacketParser.parse(bytes);

      expect(result.id, equals('R01'));
      expect(result.airflow, equals(42350));
      expect(result.spo2, equals(97));
      expect(result.status, equals(SwaasAiStatus.moderate));
    });

    test('4. Handles extra whitespace around CSV tokens', () {
      const packet = '  R03 , 41000 , 99 , 1500 , 15 , LOW  \n';
      final result = SwaasAiPacketParser.parse(packet);

      expect(result.id, equals('R03'));
      expect(result.airflow, equals(41000));
      expect(result.spo2, equals(99));
      expect(result.cough, equals(1500));
      expect(result.risk, equals(15));
      expect(result.status, equals(SwaasAiStatus.low));
    });

    test('5. Handles HIGH status packet accurately', () {
      const packet = 'R04,28500,88,3200,82,HIGH';
      final result = SwaasAiPacketParser.parse(packet);

      expect(result.id, equals('R04'));
      expect(result.risk, equals(82));
      expect(result.status, equals(SwaasAiStatus.high));
    });

    test('6. Handles unrecognized/custom status without crashing', () {
      const packet = 'R05,40000,96,1200,30,CUSTOM_STATUS';
      final result = SwaasAiPacketParser.parse(packet);

      expect(result.id, equals('R05'));
      expect(result.status, equals(SwaasAiStatus.unknown));
      expect(result.formattedStatus, equals('UNKNOWN'));
    });

    test('7. Throws SwaasAiParseException on empty or blank payload', () {
      expect(() => SwaasAiPacketParser.parse(''), throwsA(isA<SwaasAiParseException>()));
      expect(() => SwaasAiPacketParser.parse('   \n\r'), throwsA(isA<SwaasAiParseException>()));
      expect(SwaasAiPacketParser.tryParse(''), isNull);
    });

    test('8. Throws SwaasAiParseException on too few fields', () {
      const packet = 'R01,42350,97';
      expect(() => SwaasAiPacketParser.parse(packet), throwsA(isA<SwaasAiParseException>()));
      expect(SwaasAiPacketParser.tryParse(packet), isNull);
    });

    test('9. Throws SwaasAiParseException on too many fields', () {
      const packet = 'R01,42350,97,1860,42,MODERATE,EXTRA_FIELD';
      expect(() => SwaasAiPacketParser.parse(packet), throwsA(isA<SwaasAiParseException>()));
      expect(SwaasAiPacketParser.tryParse(packet), isNull);
    });

    test('10. Throws on invalid numeric format for AIRFLOW', () {
      const packet = 'R01,INVALID_AIRFLOW,97,1860,42,MODERATE';
      expect(() => SwaasAiPacketParser.parse(packet), throwsA(isA<SwaasAiParseException>()));
    });

    test('11. Throws on out-of-range SpO2 (>100 or <0)', () {
      const overPacket = 'R01,42350,105,1860,42,MODERATE';
      expect(() => SwaasAiPacketParser.parse(overPacket), throwsA(isA<SwaasAiParseException>()));

      const underPacket = 'R01,42350,-5,1860,42,MODERATE';
      expect(() => SwaasAiPacketParser.parse(underPacket), throwsA(isA<SwaasAiParseException>()));
    });

    test('12. Throws on out-of-range RISK (>100 or <0)', () {
      const overPacket = 'R01,42350,97,1860,105,MODERATE';
      expect(() => SwaasAiPacketParser.parse(overPacket), throwsA(isA<SwaasAiParseException>()));

      const underPacket = 'R01,42350,97,1860,-1,MODERATE';
      expect(() => SwaasAiPacketParser.parse(underPacket), throwsA(isA<SwaasAiParseException>()));
    });

    test('13. SwaasAiBleResult serialization to and from Map', () {
      final original = SwaasAiPacketParser.parse('R01,42350,97,1860,42,MODERATE');
      final map = original.toMap();
      final reconstructed = SwaasAiBleResult.fromMap(map);

      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.airflow, equals(original.airflow));
      expect(reconstructed.spo2, equals(original.spo2));
      expect(reconstructed.cough, equals(original.cough));
      expect(reconstructed.risk, equals(original.risk));
      expect(reconstructed.status, equals(original.status));
    });
  });
}
