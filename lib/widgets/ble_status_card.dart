import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/device_connection_screen.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class BleStatusCard extends StatelessWidget {
  final VoidCallback onOpenScanner;

  const BleStatusCard({super.key, required this.onOpenScanner});

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final isSim = ble.isSimulatorMode;
    final isReadyOrConnected = ble.connectionState == BleConnectionState.ready ||
        ble.connectionState == BleConnectionState.connected;

    return Card(
      color: AppTheme.surfaceElevated,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeviceConnectionScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isReadyOrConnected
                      ? (isSim ? AppTheme.accentIndigo.withAlpha(40) : AppTheme.riskLow.withAlpha(40))
                      : AppTheme.textMuted.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSim ? Icons.sensors : Icons.bluetooth,
                  color: isReadyOrConnected
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
                              : (isReadyOrConnected ? 'SwaasAI ESP32 Ready' : 'Device Disconnected'),
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
                            color: isReadyOrConnected ? AppTheme.riskLow : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSim
                          ? 'Simulating SwaasAI ESP32 hardware packets'
                          : (ble.connectedDeviceName ?? 'Tap to manage & pair your SwaasAI ESP32'),
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
                  } else if (val == 'manage') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DeviceConnectionScreen()),
                    );
                  } else if (val == 'scan') {
                    onOpenScanner();
                  } else if (val == 'disconnect') {
                    ble.disconnect();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'manage',
                    child: Row(
                      children: [
                        Icon(Icons.settings_bluetooth, color: AppTheme.primaryTeal, size: 18),
                        SizedBox(width: 10),
                        Text('Manage Device', style: TextStyle(color: AppTheme.textLight, fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_sim',
                    child: Row(
                      children: [
                        Icon(
                          isSim ? Icons.bluetooth_searching : Icons.laptop_chromebook,
                          color: AppTheme.accentIndigo,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          isSim ? 'Switch to Real BLE Hardware' : 'Switch to Sensor Simulator',
                          style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (isReadyOrConnected)
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
      ),
    );
  }
}
