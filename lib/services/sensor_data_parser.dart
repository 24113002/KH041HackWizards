import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/sensor_data_model.dart';
import '../models/sensor_reading_model.dart';

class SensorDataParser {
  SensorDataParser._();

  /// Converts incoming bytes or string into a JSON Map safely
  static Map<String, dynamic>? _decodeToJsonMap(dynamic payload) {
    if (payload == null) return null;

    String jsonString;
    if (payload is List<int>) {
      try {
        jsonString = utf8.decode(payload).trim();
      } catch (e) {
        debugPrint('[SensorDataParser] UTF-8 decode error: $e');
        return null;
      }
    } else if (payload is String) {
      jsonString = payload.trim();
    } else if (payload is Map<String, dynamic>) {
      return payload;
    } else {
      return null;
    }

    if (jsonString.isEmpty) return null;

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (e) {
      debugPrint('[SensorDataParser] Malformed JSON packet ignored: "$jsonString"');
      return null;
    }
  }

  /// Parses composite multi-modal payload into a [SensorReading]
  static SensorReading? parseSensorReading(
    dynamic payload, {
    required String screeningId,
    String? id,
  }) {
    final map = _decodeToJsonMap(payload);
    if (map == null) return null;

    final spo2 = _validateInt(
      map['spo2'] ?? map['SpO2'] ?? map['SPO2'],
      min: 50,
      max: 100,
    );

    final heartRate = _validateInt(
      map['heart_rate'] ?? map['heartRate'] ?? map['hr'] ?? map['HR'],
      min: 30,
      max: 220,
    );

    final pressure = _validateDouble(
      map['pressure'] ?? map['pressure_kpa'] ?? map['pressureKpa'] ?? map['p'],
      min: 0.0,
      max: 20.0,
    );

    final coughActivity = _validateDouble(
      map['cough_activity'] ?? map['coughActivity'] ?? map['cough'] ?? map['rms'],
      min: 0.0,
      max: 10.0,
    );

    return SensorReading(
      id: id ?? (map['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
      screeningId: screeningId,
      timestamp: DateTime.now(),
      spo2: spo2,
      heartRate: heartRate,
      pressure: pressure,
      coughActivity: coughActivity?.clamp(0.0, 1.0),
    );
  }

  /// Parses Vitals packet (SpO2, Heart Rate, PPG waveform)
  static VitalsReading? parseVitals(dynamic payload) {
    final map = _decodeToJsonMap(payload);
    if (map == null) return null;

    final hr = _validateInt(
      map['hr'] ?? map['heart_rate'] ?? map['heartRate'] ?? map['HR'],
      min: 30,
      max: 220,
    );

    final spo2 = _validateInt(
      map['spo2'] ?? map['SpO2'] ?? map['SPO2'],
      min: 50,
      max: 100,
    );

    final ppg = _validateDouble(
      map['ppg'] ?? map['ppg_value'] ?? map['ppgValue'],
      min: 0.0,
      max: 1.0,
    );

    if (hr == null && spo2 == null && ppg == null) {
      return null;
    }

    return VitalsReading(
      heartRate: hr ?? 0,
      spo2: spo2 ?? 0,
      ppgValue: ppg ?? 0.0,
      timestamp: DateTime.now(),
    );
  }

  /// Parses Spirometry / Airflow packet (time, flow, volume, pressure)
  static SpirometryPoint? parseSpirometryPoint(dynamic payload) {
    final map = _decodeToJsonMap(payload);
    if (map == null) return null;

    final time = _validateDouble(
      map['t'] ?? map['time_sec'] ?? map['timeSeconds'] ?? map['time'],
      min: 0.0,
      max: 60.0,
    );

    final flow = _validateDouble(
      map['f'] ?? map['flow_lps'] ?? map['flowLps'] ?? map['flow'],
      min: 0.0,
      max: 25.0,
    );

    final volume = _validateDouble(
      map['v'] ?? map['volume_liters'] ?? map['volumeL'] ?? map['volume'],
      min: 0.0,
      max: 12.0,
    );

    final pressure = _validateDouble(
      map['p'] ?? map['pressure_kpa'] ?? map['pressureKpa'] ?? map['pressure'],
      min: 0.0,
      max: 20.0,
    );

    if (flow == null && volume == null) {
      return null;
    }

    return SpirometryPoint(
      timeSec: time ?? 0.0,
      flowLps: flow ?? 0.0,
      volumeLiters: volume ?? 0.0,
      pressureKpa: pressure ?? 0.0,
    );
  }

  /// Parses Acoustic packet (RMS energy, cough event flag, dominant frequency)
  static AcousticReading? parseAcousticReading(dynamic payload) {
    final map = _decodeToJsonMap(payload);
    if (map == null) return null;

    final rms = _validateDouble(
      map['rms'] ?? map['rms_amplitude'] ?? map['rmsAmplitude'],
      min: 0.0,
      max: 1.0,
    );

    final coughRaw = map['cough'] ?? map['cough_detected'] ?? map['is_cough'] ?? map['isCoughTriggered'];
    bool coughDetected = false;
    if (coughRaw is bool) {
      coughDetected = coughRaw;
    } else if (coughRaw is num) {
      coughDetected = coughRaw.toInt() > 0;
    }

    final freq = _validateDouble(
      map['freq'] ?? map['dominant_freq_hz'] ?? map['dominantFreqHz'],
      min: 0.0,
      max: 5000.0,
    );

    return AcousticReading(
      rmsAmplitude: rms ?? 0.0,
      coughDetected: coughDetected,
      dominantFreqHz: freq ?? 0.0,
      timestamp: DateTime.now(),
    );
  }

  // --- Validation Helpers ---

  static int? _validateInt(dynamic val, {required int min, required int max}) {
    if (val == null) return null;
    if (val is num) {
      if (val.isNaN || val.isInfinite) return null;
      final intVal = val.toInt();
      if (intVal >= min && intVal <= max) return intVal;
      return null;
    }
    if (val is String) {
      final parsed = int.tryParse(val.trim());
      if (parsed != null && parsed >= min && parsed <= max) return parsed;
    }
    return null;
  }

  static double? _validateDouble(dynamic val, {required double min, required double max}) {
    if (val == null) return null;
    if (val is num) {
      final d = val.toDouble();
      if (d.isNaN || d.isInfinite) return null;
      if (d >= min && d <= max) return d;
      return null;
    }
    if (val is String) {
      final parsed = double.tryParse(val.trim());
      if (parsed != null && !parsed.isNaN && !parsed.isInfinite && parsed >= min && parsed <= max) {
        return parsed;
      }
    }
    return null;
  }
}
