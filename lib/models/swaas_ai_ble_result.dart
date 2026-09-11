enum SwaasAiStatus {
  low,
  moderate,
  high,
  incomplete,
  unknown,
}

extension SwaasAiStatusExtension on SwaasAiStatus {
  String get code {
    switch (this) {
      case SwaasAiStatus.low:
        return 'LOW';
      case SwaasAiStatus.moderate:
        return 'MODERATE';
      case SwaasAiStatus.high:
        return 'HIGH';
      case SwaasAiStatus.incomplete:
        return 'INCOMPLETE';
      case SwaasAiStatus.unknown:
        return 'UNKNOWN';
    }
  }

  String get label {
    switch (this) {
      case SwaasAiStatus.low:
        return 'Low Risk';
      case SwaasAiStatus.moderate:
        return 'Moderate Risk';
      case SwaasAiStatus.high:
        return 'High Risk';
      case SwaasAiStatus.incomplete:
        return 'Incomplete';
      case SwaasAiStatus.unknown:
        return 'Unknown Status';
    }
  }

  String get displayDescription {
    switch (this) {
      case SwaasAiStatus.low:
        return 'Screening parameters indicate low respiratory risk.';
      case SwaasAiStatus.moderate:
        return 'Moderate risk indicators observed. Clinical follow-up recommended.';
      case SwaasAiStatus.high:
        return 'Elevated risk detected. Priority clinical assessment recommended.';
      case SwaasAiStatus.incomplete:
        return 'Screening incomplete. One or more sensor measurements unavailable.';
      case SwaasAiStatus.unknown:
        return 'Unrecognized screening status received.';
    }
  }
}

/// SwaasAI ESP32 hardware BLE screening result data model.
///
/// Hardware Packet Format: ID,AIRFLOW,SPO2,COUGH,RISK,STATUS
/// Example: R01,42350,97,1860,42,MODERATE
/// Incomplete Example: R02,39120,NA,1735,NA,INCOMPLETE
class SwaasAiBleResult {
  /// Device / Screening record ID (e.g. "R01")
  final String id;

  /// Raw airflow/pressure-derived sensor feature (e.g. 42350).
  /// Note: Not calibrated clinical airflow (L/s or FEV1).
  final int? airflow;

  /// Blood oxygen saturation percentage (e.g. 97). Null if NA.
  final int? spo2;

  /// Digital audio cough amplitude/feature value (e.g. 1860).
  /// Note: Digital audio feature, not a clinically validated cough score.
  final int? cough;

  /// Calculated screening risk score (0-100). Null if NA.
  final int? risk;

  /// Screening category status.
  final SwaasAiStatus status;

  /// Timestamp when packet was received and parsed.
  final DateTime receivedAt;

  /// Original raw string packet payload.
  final String rawPacket;

  const SwaasAiBleResult({
    required this.id,
    this.airflow,
    this.spo2,
    this.cough,
    this.risk,
    required this.status,
    required this.receivedAt,
    this.rawPacket = '',
  });

  /// True if the result represents an incomplete screening (status == incomplete or missing essential fields)
  bool get isIncomplete => status == SwaasAiStatus.incomplete;

  /// Formatted display string for SpO2 (e.g. "97 %" or "--")
  String get formattedSpo2 => spo2 != null ? '$spo2 %' : '--';

  /// Formatted display string for Raw Airflow Feature (e.g. "42350" or "--")
  String get formattedAirflow => airflow != null ? '$airflow' : '--';

  /// Formatted display string for Cough Signal (e.g. "1860" or "--")
  String get formattedCough => cough != null ? '$cough' : '--';

  /// Formatted display string for Risk Score (e.g. "42 / 100" or "--")
  String get formattedRisk => risk != null ? '$risk / 100' : '--';

  /// Formatted display string for Status (e.g. "MODERATE" or "INCOMPLETE")
  String get formattedStatus => status.code;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'airflow': airflow,
      'spo2': spo2,
      'cough': cough,
      'risk': risk,
      'status': status.code,
      'received_at': receivedAt.toIso8601String(),
      'raw_packet': rawPacket,
    };
  }

  factory SwaasAiBleResult.fromMap(Map<String, dynamic> map) {
    final statusStr = (map['status'] as String?)?.trim().toUpperCase() ?? 'UNKNOWN';
    final SwaasAiStatus resolvedStatus;
    switch (statusStr) {
      case 'LOW':
        resolvedStatus = SwaasAiStatus.low;
        break;
      case 'MODERATE':
        resolvedStatus = SwaasAiStatus.moderate;
        break;
      case 'HIGH':
        resolvedStatus = SwaasAiStatus.high;
        break;
      case 'INCOMPLETE':
        resolvedStatus = SwaasAiStatus.incomplete;
        break;
      default:
        resolvedStatus = SwaasAiStatus.unknown;
    }

    return SwaasAiBleResult(
      id: (map['id'] as String?) ?? '',
      airflow: (map['airflow'] as num?)?.toInt(),
      spo2: (map['spo2'] as num?)?.toInt(),
      cough: (map['cough'] as num?)?.toInt(),
      risk: (map['risk'] as num?)?.toInt(),
      status: resolvedStatus,
      receivedAt: DateTime.tryParse(map['received_at'] as String? ?? '') ?? DateTime.now(),
      rawPacket: (map['raw_packet'] as String?) ?? '',
    );
  }

  SwaasAiBleResult copyWith({
    String? id,
    int? airflow,
    int? spo2,
    int? cough,
    int? risk,
    SwaasAiStatus? status,
    DateTime? receivedAt,
    String? rawPacket,
  }) {
    return SwaasAiBleResult(
      id: id ?? this.id,
      airflow: airflow ?? this.airflow,
      spo2: spo2 ?? this.spo2,
      cough: cough ?? this.cough,
      risk: risk ?? this.risk,
      status: status ?? this.status,
      receivedAt: receivedAt ?? this.receivedAt,
      rawPacket: rawPacket ?? this.rawPacket,
    );
  }

  @override
  String toString() {
    return 'SwaasAiBleResult(id: $id, airflow: $airflow, spo2: $spo2, cough: $cough, risk: $risk, status: ${status.code}, receivedAt: $receivedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SwaasAiBleResult &&
        other.id == id &&
        other.airflow == airflow &&
        other.spo2 == spo2 &&
        other.cough == cough &&
        other.risk == risk &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(id, airflow, spo2, cough, risk, status);
  }
}
