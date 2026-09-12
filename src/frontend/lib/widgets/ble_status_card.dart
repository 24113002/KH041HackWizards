import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class BleStatusCard extends StatelessWidget {
  final VoidCallback onOpenScanner;

  const BleStatusCard({super.key, required this.onOpenScanner});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final isSim = ble.isSimulatorMode;
    final isConnected = ble.connectionState == BleConnectionState.connected;

    return Card(
      color: AppTheme.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isConnected
                    ? (isSim ? AppTheme.accentIndigo.withAlpha(40) : AppTheme.riskLow.withAlpha(40))
                    : AppTheme.textMuted.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSim ? Icons.sensors : Icons.bluetooth,
                color: isConnected
                    ? (isSim ? AppTheme.accentIndigo : AppTheme.riskLow)
                    : AppTheme.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isSim
                            ? 'Hardware Simulator Active'
                            : (isConnected ? 'ESP32 Connected' : 'Device Disconnected'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected ? AppTheme.riskLow : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSim
                        ? 'Streaming realistic MAX30102 & Airflow data'
                        : (ble.connectedDeviceName ?? 'Tap to scan and pair your ESP32'),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
              color: AppTheme.surfaceElevated,
              onSelected: (val) {
                if (val == 'toggle_sim') {
                  ble.toggleSimulatorMode(!isSim);
                } else if (val == 'scan') {
                  onOpenScanner();
                } else if (val == 'disconnect') {
                  ble.disconnect();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'toggle_sim',
                  child: Row(
                    children: [
                      Icon(
                        isSim ? Icons.bluetooth_searching : Icons.laptop_chromebook,
                        color: AppTheme.primaryTeal,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isSim ? 'Switch to Real BLE Hardware' : 'Switch to Sensor Simulator',
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (!isSim)
                  const PopupMenuItem(
                    value: 'scan',
                    child: Row(
                      children: [
                        Icon(Icons.search, color: AppTheme.primaryBlue, size: 18),
                        SizedBox(width: 10),
                        Text('Scan for ESP32', style: TextStyle(color: AppTheme.textLight, fontSize: 13)),
                      ],
                    ),
                  ),
                if (isConnected)
                  const PopupMenuItem(
                    value: 'disconnect',
                    child: Row(
                      children: [
                        Icon(Icons.close, color: AppTheme.riskCritical, size: 18),
                        SizedBox(width: 10),
                        Text('Disconnect', style: TextStyle(color: AppTheme.riskCritical, fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
