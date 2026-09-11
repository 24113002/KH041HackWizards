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
                    'Connect SWASTHAI Device',
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
            'Ensure your ESP32 device is powered on and advertising SWASTHAI service.',
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
                      : 'Found ${ble.scanResults.length} devices',
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
              child: ble.scanResults.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          ble.connectionState == BleConnectionState.scanning
                              ? 'Searching for nearby ESP32 devices...'
                              : 'No SWASTHAI devices found. Make sure Bluetooth is enabled and the ESP32 is powered.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: ble.scanResults.length,
                      itemBuilder: (ctx, idx) {
                        final res = ble.scanResults[idx];
                        final name = res.device.platformName.isNotEmpty
                            ? res.device.platformName
                            : res.advertisementData.advName;
                        final isSwasthai = name.toUpperCase().contains('SWASTHAI') ||
                            name.toUpperCase().contains('ESP32');

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: isSwasthai ? AppTheme.primaryTeal.withAlpha(30) : Colors.grey.withAlpha(30),
                            child: Icon(
                              Icons.devices,
                              color: isSwasthai ? AppTheme.primaryTeal : Colors.grey,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            name.isNotEmpty ? name : 'Unknown Device',
                            style: TextStyle(
                              color: isSwasthai ? AppTheme.textLight : AppTheme.textMuted,
                              fontWeight: isSwasthai ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${res.device.remoteId} • RSSI: ${res.rssi} dBm',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              final ok = await ble.connectToDevice(res.device);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? 'Connected to ${res.device.platformName}!' : 'Connection failed.'),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: const Text('Connect', style: TextStyle(fontSize: 12)),
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
