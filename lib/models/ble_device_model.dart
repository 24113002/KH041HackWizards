class BleDeviceModel {
  final String id;
  final String name;
  final int rssi;
  final bool isConnected;
  final dynamic platformDevice;

  const BleDeviceModel({
    required this.id,
    required this.name,
    this.rssi = 0,
    this.isConnected = false,
    this.platformDevice,
  });

  BleDeviceModel copyWith({
    String? id,
    String? name,
    int? rssi,
    bool? isConnected,
    dynamic platformDevice,
  }) {
    return BleDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isConnected: isConnected ?? this.isConnected,
      platformDevice: platformDevice ?? this.platformDevice,
    );
  }

  String get signalStrengthDescription {
    if (rssi >= -60) return 'Strong';
    if (rssi >= -75) return 'Good';
    if (rssi >= -85) return 'Fair';
    return 'Weak';
  }
}
