class BleConfig {
  BleConfig._();

  /// Target ESP32 Device Name advertising from firmware
  static const String targetDeviceName = 'SWASTHAI_ESP32';

  /// Acceptable device name prefixes for scanning and discovery
  static const List<String> devicePrefixes = [
    'SWASTHAI',
    'SwasthAI',
    'SWASTH',
  ];

  /// Primary SWASTHAI GATT Service UUID
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  /// Vitals Characteristic UUID (SpO2, Heart Rate, PPG stream)
  static const String vitalsCharacteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  /// Airflow / Spirometry Characteristic UUID (Pressure, Flow, Volume)
  static const String airflowCharacteristicUuid = '1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e';

  /// Acoustic Characteristic UUID (Cough detection, Mic RMS, Dominant Frequency)
  static const String acousticCharacteristicUuid = 'd271607c-9204-4769-a038-0796d5147a4b';

  /// Command / Control Characteristic UUID (Placeholder for firmware calibration/triggers if provided by hardware team)
  static const String commandCharacteristicUuid = '00000000-0000-0000-0000-000000000000';

  /// Scan timeout in seconds
  static const Duration scanTimeout = Duration(seconds: 8);

  /// Connection timeout in seconds
  static const Duration connectTimeout = Duration(seconds: 12);

  /// Maximum consecutive reconnect attempts before requiring manual action
  static const int maxAutoReconnectAttempts = 3;
}
