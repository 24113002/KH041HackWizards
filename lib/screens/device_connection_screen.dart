import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/ble_config.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  bool _showDebugInfo = false;

  Color _getStatusColor(BleConnectionState state) {
    switch (state) {
      case BleConnectionState.ready:
      case BleConnectionState.connected:
        return AppTheme.riskLow;
      case BleConnectionState.connecting:
      case BleConnectionState.scanning:
      case BleConnectionState.discoveringServices:
        return AppTheme.riskModerate;
      case BleConnectionState.receivingResult:
        return AppTheme.accentIndigo;
      case BleConnectionState.connectionLost:
      case BleConnectionState.error:
      case BleConnectionState.disconnected:
        return AppTheme.riskCritical;
    }
  }

  String _getStatusLabel(BleConnectionState state, bool isSim) {
    if (isSim) return '🟢 Simulator Active (Ready)';
    switch (state) {
      case BleConnectionState.ready:
        return '🟢 Device Ready';
      case BleConnectionState.connected:
        return '🟢 Device Connected';
      case BleConnectionState.discoveringServices:
        return '🟡 Discovering Services...';
      case BleConnectionState.connecting:
        return '🟡 Connecting...';
      case BleConnectionState.scanning:
        return '🟡 Scanning for devices...';
      case BleConnectionState.receivingResult:
        return '🔵 Receiving Result...';
      case BleConnectionState.connectionLost:
        return '🔴 Connection Lost';
      case BleConnectionState.error:
        return '🔴 Connection Error';
      case BleConnectionState.disconnected:
        return '🔴 Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final state = ble.connectionState;
    final isReadyOrConnected = state == BleConnectionState.ready || state == BleConnectionState.connected;
    final isScanning = state == BleConnectionState.scanning;
    final isBusy = isScanning || state == BleConnectionState.connecting || state == BleConnectionState.receivingResult;
    final statusColor = _getStatusColor(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SwaasAI Device Connection',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebugInfo ? AppTheme.primaryTeal : AppTheme.textMuted,
            ),
            tooltip: 'Toggle Developer & Debug Panel',
            onPressed: () {
              setState(() {
                _showDebugInfo = !_showDebugInfo;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Device Header Card
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
                    ble.connectedDeviceName ?? BleConfig.targetDeviceName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textLight),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Service & Characteristic Status Rows
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Service (GATT):', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Row(
                              children: [
                                Icon(
                                  isReadyOrConnected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 14,
                                  color: isReadyOrConnected ? AppTheme.riskLow : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isReadyOrConnected ? 'Ready' : 'Not Connected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isReadyOrConnected ? AppTheme.riskLow : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Characteristic (READ/NOTIFY):', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Row(
                              children: [
                                Icon(
                                  isReadyOrConnected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 14,
                                  color: isReadyOrConnected ? AppTheme.riskLow : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isReadyOrConnected ? 'Ready' : 'Not Connected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isReadyOrConnected ? AppTheme.riskLow : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
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

                  // Action Buttons
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      if (isReadyOrConnected) ...[
                        ElevatedButton.icon(
                          onPressed: isBusy
                              ? null
                              : () async {
                                  final result = await ble.readLatestResult();
                                  if (context.mounted) {
                                    if (result != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Screening result read: Record ${result.id} (${result.formattedStatus})'),
                                          backgroundColor: AppTheme.riskLow,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('No completed result available on device.'),
                                          backgroundColor: AppTheme.riskModerate,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: state == BleConnectionState.receivingResult
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download_rounded),
                          label: const Text('Read Latest Result'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => ble.disconnect(),
                          icon: const Icon(Icons.link_off, size: 18),
                          label: const Text('Disconnect'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.riskCritical,
                            side: const BorderSide(color: AppTheme.riskCritical),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                          label: Text(isScanning ? 'Scanning...' : 'Scan for SwaasAI ESP32'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryTeal,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Mode Selector Pill (Physical Hardware vs Simulator)
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
                          ble.isSimulatorMode ? 'Hardware Simulator Active' : 'Physical BLE Hardware Mode',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight),
                        ),
                        Text(
                          ble.isSimulatorMode
                              ? 'Simulating SwaasAI ESP32 packets'
                              : 'Listening to SwaasAI_ESP32 GATT service',
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
            const SizedBox(height: 20),

            // 3. Developer & Debug Information Panel (Collapsible)
            if (_showDebugInfo) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentIndigo.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.terminal, size: 18, color: AppTheme.accentIndigo),
                        SizedBox(width: 8),
                        Text(
                          'Developer & BLE Debug Information',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textLight),
                        ),
                      ],
                    ),
                    const Divider(color: AppTheme.surfaceElevated, height: 20),
                    _buildDebugRow('Data Source:', ble.isSimulatorMode ? 'Sensor Simulator' : 'ESP32 BLE Hardware'),
                    _buildDebugRow('Target Device Name:', BleConfig.targetDeviceName),
                    _buildDebugRow('Service UUID:', BleConfig.serviceUuid),
                    _buildDebugRow('Characteristic UUID:', BleConfig.screeningResultCharacteristicUuid),
                    _buildDebugRow('GATT Properties:', 'READ + NOTIFY (No Write)'),
                    _buildDebugRow('Connection State:', ble.connectionState.name),
                    _buildDebugRow('Last Raw Packet:', ble.lastRawPacket ?? 'None received yet'),
                    _buildDebugRow(
                      'Last Packet Time:',
                      ble.lastPacketTime != null
                          ? DateFormat('HH:mm:ss').format(ble.lastPacketTime!)
                          : 'N/A',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Simulator Test Triggers:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            ble.emitMockScreeningResult(rawPacket: 'R01,42350,97,1860,42,MODERATE');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Emitted Test Packet: R01 (MODERATE)')),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.primaryTeal),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          child: const Text('Emit Valid Packet (R01)', style: TextStyle(fontSize: 11, color: AppTheme.primaryTeal)),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            ble.emitMockScreeningResult(rawPacket: 'R02,39120,NA,1735,NA,INCOMPLETE');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Emitted Incomplete Packet: R02 (NA fields)')),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.riskModerate),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          child: const Text('Emit Incomplete Packet (R02)', style: TextStyle(fontSize: 11, color: AppTheme.riskModerate)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 4. Discovered Devices List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Nearby Devices',
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
                      'No SwaasAI ESP32 devices found',
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
                final isMatchingName = dev.name.toUpperCase().contains('SWAAS') ||
                    dev.name.toUpperCase().contains('SWASTH') ||
                    dev.name.toUpperCase().contains('ESP32');

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isMatchingName ? AppTheme.primaryTeal.withAlpha(30) : Colors.grey.withAlpha(30),
                      child: Icon(
                        Icons.bluetooth,
                        color: isMatchingName ? AppTheme.primaryTeal : Colors.grey,
                      ),
                    ),
                    title: Text(
                      dev.name,
                      style: TextStyle(
                        fontWeight: isMatchingName ? FontWeight.bold : FontWeight.normal,
                        color: AppTheme.textLight,
                      ),
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
                      onPressed: isBusy ? null : () => ble.connectToDevice(dev),
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

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: AppTheme.textLight, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
