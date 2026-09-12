import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class BleScanSheet extends StatefulWidget {
  const BleScanSheet({super.key});

  @override
  State<BleScanSheet> createState() => _BleScanSheetState();
}

class _BleScanSheetState extends State<BleScanSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ble = context.read<BleService>();
      if (!ble.isSimulatorMode) {
        ble.startScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bluetooth_searching, color: AppTheme.primaryTeal),
                  SizedBox(width: 10),
                  Text(
                    'Connect SwaasAI Device',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ensure your SwaasAI ESP32 device is powered on and advertising BLE service.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          if (ble.isSimulatorMode) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accentIndigo.withAlpha(50)),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.accentIndigo),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Hardware Simulator is currently active.',
                          style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'To scan for physical BLE hardware, switch off simulator mode.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      ble.toggleSimulatorMode(false);
                      ble.startScan();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentIndigo),
                    child: const Text('Disable Simulator & Scan Real BLE'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ble.connectionState == BleConnectionState.scanning
                      ? 'Scanning for devices...'
                      : 'Found ${ble.discoveredDevices.length} devices',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                if (ble.connectionState == BleConnectionState.scanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16, color: AppTheme.primaryTeal),
                    label: const Text('Rescan', style: TextStyle(color: AppTheme.primaryTeal)),
                    onPressed: () => ble.startScan(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ble.discoveredDevices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          ble.connectionState == BleConnectionState.scanning
                              ? 'Searching for nearby SwaasAI ESP32 devices...'
                              : (ble.errorMessage ??
                                  'No SwaasAI devices found. Make sure Bluetooth is enabled and the ESP32 is powered.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: ble.discoveredDevices.length,
                      itemBuilder: (ctx, idx) {
                        final dev = ble.discoveredDevices[idx];
                        final isSwaas = dev.name.toUpperCase().contains('COPD') ||
                            dev.name.toUpperCase().contains('SWAAS') ||
                            dev.name.toUpperCase().contains('SWASTH') ||
                            dev.name.toUpperCase().contains('ESP32') ||
                            dev.id.toUpperCase() == '1C:C3:AB:B3:03:A2';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSwaas ? AppTheme.primaryTeal.withAlpha(20) : AppTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSwaas ? AppTheme.primaryTeal : Colors.white10,
                              width: isSwaas ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isSwaas ? AppTheme.primaryTeal : Colors.grey.withAlpha(40),
                                child: Icon(
                                  isSwaas ? Icons.medical_services_outlined : Icons.bluetooth,
                                  color: isSwaas ? Colors.white : Colors.grey,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            dev.name,
                                            style: TextStyle(
                                              color: isSwaas ? AppTheme.textLight : AppTheme.textMuted,
                                              fontWeight: isSwaas ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSwaas) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryTeal,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Screener',
                                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${dev.id} • ${dev.signalStrengthDescription} (${dev.rssi} dBm)',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  await ble.connectToDevice(dev);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Connecting to ${dev.name}...'),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSwaas ? AppTheme.primaryTeal : AppTheme.surfaceElevated,
                                  foregroundColor: isSwaas ? Colors.white : AppTheme.textLight,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                child: const Text('Connect', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
