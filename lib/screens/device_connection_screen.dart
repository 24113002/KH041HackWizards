import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class DeviceConnectionScreen extends StatelessWidget {
  const DeviceConnectionScreen({super.key});

  Color _getStatusColor(BleConnectionState state) {
    switch (state) {
      case BleConnectionState.connected:
        return AppTheme.riskLow;
      case BleConnectionState.connecting:
      case BleConnectionState.scanning:
        return AppTheme.riskModerate;
      case BleConnectionState.connectionLost:
      case BleConnectionState.disconnected:
        return AppTheme.riskCritical;
    }
  }

  String _getStatusLabel(BleConnectionState state, bool isSim) {
    if (isSim) return '🟢 Simulator Active';
    switch (state) {
      case BleConnectionState.connected:
        return '🟢 Device Connected';
      case BleConnectionState.connecting:
        return '🟡 Connecting...';
      case BleConnectionState.scanning:
        return '🟡 Scanning for devices...';
      case BleConnectionState.connectionLost:
        return '🔴 Connection Lost';
      case BleConnectionState.disconnected:
        return '🔴 Not Connected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final state = ble.connectionState;
    final isConnected = state == BleConnectionState.connected;
    final isScanning = state == BleConnectionState.scanning;
    final isConnecting = state == BleConnectionState.connecting;
    final statusColor = _getStatusColor(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Device Connection',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withAlpha(80), width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      ble.isSimulatorMode ? Icons.sensors : Icons.bluetooth,
                      size: 36,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _getStatusLabel(state, ble.isSimulatorMode),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ble.connectedDeviceName ?? 'No physical device currently paired',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  if (ble.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.riskCritical.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.riskCritical),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ble.errorMessage!,
                              style: const TextStyle(fontSize: 12, color: AppTheme.riskCritical),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (isConnected) ...[
                    ElevatedButton.icon(
                      onPressed: () => ble.disconnect(),
                      icon: const Icon(Icons.link_off),
                      label: const Text('Disconnect Device'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.riskCritical.withAlpha(180),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: isScanning ? null : () => ble.startScan(),
                      icon: isScanning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search),
                      label: Text(isScanning ? 'Scanning...' : 'Scan for Devices'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mode Selector Pill
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    ble.isSimulatorMode ? Icons.laptop_chromebook : Icons.bluetooth_connected,
                    color: AppTheme.primaryTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ble.isSimulatorMode ? 'Hardware Simulator' : 'Physical BLE Hardware',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight),
                        ),
                        Text(
                          ble.isSimulatorMode ? 'Simulating MAX30102 vitals & airflow' : 'Listening to live ESP32 GATT packets',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: !ble.isSimulatorMode,
                    activeTrackColor: AppTheme.primaryTeal.withAlpha(150),
                    activeThumbColor: AppTheme.primaryTeal,
                    onChanged: (val) => ble.toggleSimulatorMode(!val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Discovered Devices List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Devices',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                ),
                if (isScanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (ble.discoveredDevices.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_searching,
                      size: 40,
                      color: AppTheme.textMuted.withAlpha(80),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No SwasthAI devices found',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ensure your ESP32 board is powered on and within range.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...ble.discoveredDevices.map((dev) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryTeal.withAlpha(30),
                      child: const Icon(Icons.bluetooth, color: AppTheme.primaryTeal),
                    ),
                    title: Text(
                      dev.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.signal_cellular_alt, size: 14, color: AppTheme.riskLow),
                          const SizedBox(width: 4),
                          Text(
                            'Signal: ${dev.signalStrengthDescription} (${dev.rssi} dBm)',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    trailing: ElevatedButton(
                      onPressed: isConnecting ? null : () => ble.connectToDevice(dev),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                      child: const Text('Connect'),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
