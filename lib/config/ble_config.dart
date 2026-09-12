class BleConfig {
  BleConfig._();

  /// Target ESP32 Device Name advertising from firmware
  static const String targetDeviceName = 'SwaasAI_ESP32';

  /// Acceptable device name prefixes for scanning and discovery
  static const List<String> devicePrefixes = [
    'COPD_Screening',
    'COPD',
    'SwaasAI_ESP32',
    'SWASTHAI-ESP32',
    'SwaasAI',
    'Swaas',
    'SwasthAI',
    'SWASTHAI',
    'SWASTH',
    'ESP32',
    'ESP',
    'Screening',
  ];

  /// Primary SwaasAI GATT Service UUIDs
  static const String serviceUuid = '12345678-1234-1234-1234-1234567890AB';
  static const String firmwareServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String alternateServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  /// Screening Result Characteristic UUID (READ + NOTIFY)
  static const String screeningResultCharacteristicUuid = '12345678-1234-1234-1234-1234567890AC';

  /// Compatibility UUIDs for Phase 3 components if still referenced
  static const String vitalsCharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String airflowCharacteristicUuid = '1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e';
  static const String acousticCharacteristicUuid = 'd271607c-9204-4769-a038-0796d5147a4b';
  static const String commandCharacteristicUuid = '00000000-0000-0000-0000-000000000000';

  /// Scan timeout in seconds
  static const Duration scanTimeout = Duration(seconds: 8);

  /// Connection timeout in seconds
  static const Duration connectTimeout = Duration(seconds: 12);

  /// Maximum consecutive reconnect attempts before requiring manual action
  static const int maxAutoReconnectAttempts = 3;
}
