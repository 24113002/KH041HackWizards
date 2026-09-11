import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/swaas_ai_ble_result.dart';

/// Exception thrown when an ESP32 BLE screening packet cannot be parsed.
class SwaasAiParseException implements Exception {
  final String message;
  final String? rawPacket;

  const SwaasAiParseException(this.message, {this.rawPacket});

  @override
  String toString() => 'SwaasAiParseException: $message ${rawPacket != null ? '(packet: "$rawPacket")' : ''}';
}

/// Dedicated parser for SwaasAI ESP32 hardware BLE screening packets.
///
/// Production Packet Specification:
///   ID,AIRFLOW,SPO2,COUGH,RISK,STATUS
///
/// Examples:
///   Valid:      "R01,42350,97,1860,42,MODERATE\n"
///   Incomplete: "R02,39120,NA,1735,NA,INCOMPLETE\r\n"
class SwaasAiPacketParser {
  SwaasAiPacketParser._();

  static const int expectedFieldCount = 6;
  static const String naToken = 'NA';

  /// Decodes raw BLE byte array or String and parses into [SwaasAiBleResult].
  ///
  /// Returns null if the packet is empty or malformed.
  static SwaasAiBleResult? tryParse(dynamic payload) {
    try {
      return parse(payload);
    } catch (e) {
      debugPrint('[SwaasAiPacketParser] Parse failed: $e');
      return null;
    }
  }

  /// Parses a raw payload (bytes or String) into [SwaasAiBleResult].
  ///
  /// Throws [SwaasAiParseException] if the packet fails validation.
  static SwaasAiBleResult parse(dynamic payload) {
    final rawText = _extractString(payload);
    if (rawText == null || rawText.trim().isEmpty) {
      throw const SwaasAiParseException('Empty screening packet received.');
    }

    final cleaned = rawText.trim();
    final parts = cleaned.split(',').map((s) => s.trim()).toList();

    if (parts.length != expectedFieldCount) {
      throw SwaasAiParseException(
        'Invalid screening result received: expected $expectedFieldCount fields, found ${parts.length}.',
        rawPacket: cleaned,
      );
    }

    final rawId = parts[0];
    final rawAirflow = parts[1];
    final rawSpo2 = parts[2];
    final rawCough = parts[3];
    final rawRisk = parts[4];
    final rawStatus = parts[5];

    // 1. Validate ID
    if (rawId.isEmpty) {
      throw SwaasAiParseException('Record ID cannot be empty.', rawPacket: cleaned);
    }

    // 2. Validate & Parse AIRFLOW
    final int? airflow;
    if (_isNa(rawAirflow)) {
      airflow = null;
    } else {
      final parsed = int.tryParse(rawAirflow);
      if (parsed == null || parsed < 0) {
        throw SwaasAiParseException('Invalid AIRFLOW feature: "$rawAirflow".', rawPacket: cleaned);
      }
      airflow = parsed;
    }

    // 3. Validate & Parse SPO2
    final int? spo2;
    if (_isNa(rawSpo2)) {
      spo2 = null;
    } else {
      final parsed = int.tryParse(rawSpo2);
      if (parsed == null || parsed < 0 || parsed > 100) {
        throw SwaasAiParseException('Invalid SPO2 value: "$rawSpo2" (must be 0-100 or NA).', rawPacket: cleaned);
      }
      spo2 = parsed;
    }

    // 4. Validate & Parse COUGH
    final int? cough;
    if (_isNa(rawCough)) {
      cough = null;
    } else {
      final parsed = int.tryParse(rawCough);
      if (parsed == null || parsed < 0) {
        throw SwaasAiParseException('Invalid COUGH feature: "$rawCough".', rawPacket: cleaned);
      }
      cough = parsed;
    }

    // 5. Validate & Parse RISK (0-100)
    final int? risk;
    if (_isNa(rawRisk)) {
      risk = null;
    } else {
      final parsed = int.tryParse(rawRisk);
      if (parsed == null || parsed < 0 || parsed > 100) {
        throw SwaasAiParseException('Invalid RISK score: "$rawRisk" (must be 0-100 or NA).', rawPacket: cleaned);
      }
      risk = parsed;
    }

    // 6. Validate & Parse STATUS
    if (rawStatus.isEmpty) {
      throw SwaasAiParseException('STATUS cannot be empty.', rawPacket: cleaned);
    }

    final SwaasAiStatus status;
    switch (rawStatus.toUpperCase()) {
      case 'LOW':
        status = SwaasAiStatus.low;
        break;
      case 'MODERATE':
        status = SwaasAiStatus.moderate;
        break;
      case 'HIGH':
        status = SwaasAiStatus.high;
        break;
      case 'INCOMPLETE':
        status = SwaasAiStatus.incomplete;
        break;
      default:
        status = SwaasAiStatus.unknown;
    }

    return SwaasAiBleResult(
      id: rawId,
      airflow: airflow,
      spo2: spo2,
      cough: cough,
      risk: risk,
      status: status,
      receivedAt: DateTime.now(),
      rawPacket: cleaned,
    );
  }

  static bool _isNa(String s) {
    final upper = s.trim().toUpperCase();
    return upper == naToken || upper == '--' || upper.isEmpty;
  }

  static String? _extractString(dynamic payload) {
    if (payload == null) return null;
    if (payload is String) return payload;
    if (payload is List<int>) {
      try {
        return utf8.decode(payload);
      } catch (e) {
        debugPrint('[SwaasAiPacketParser] UTF-8 decoding error: $e');
        return null;
      }
    }
    return payload.toString();
  }
}
