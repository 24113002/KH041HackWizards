import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../theme/app_theme.dart';

class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ipController = TextEditingController(text: '192.168.4.1');
  final TextEditingController _portController = TextEditingController(text: '80');
  bool _isPinging = false;
  bool _isConnectingWifi = false;
  String? _pingResult;
  bool _showDebugInfo = false;

  @override
  void initState() {
    super.initState();
    final ble = context.read<BleService>();
    int initialTab = 0; // 0: Wi-Fi, 1: BLE, 2: Simulator
    if (ble is AppBleService) {
      if (ble.transportMode == HardwareTransportMode.ble) initialTab = 1;
      if (ble.transportMode == HardwareTransportMode.simulator) initialTab = 2;
    }
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

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

  Future<void> _pingEsp32(AppBleService ble) async {
    setState(() {
      _isPinging = true;
      _pingResult = null;
    });

    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 80;
    final ok = await ble.wifiService.ping(ip: ip, port: port);

    if (mounted) {
      setState(() {
        _isPinging = false;
        _pingResult = ok
            ? '🟢 ESP32 Reachable (${ble.wifiService.lastPingMs ?? 15}ms latency)'
            : '🔴 ESP32 Unreachable at http://$ip:$port';
      });
    }
  }

  Future<void> _connectWifi(AppBleService ble) async {
    setState(() => _isConnectingWifi = true);
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 80;

    final success = await ble.connectWifi(ip: ip, port: port);
    if (mounted) {
      setState(() => _isConnectingWifi = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ESP32 over Wi-Fi ($ip)!'),
            backgroundColor: AppTheme.riskLow,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ble.wifiService.errorMessage ?? 'Failed to connect via Wi-Fi'),
            backgroundColor: AppTheme.riskCritical,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    final appBle = ble is AppBleService ? ble : null;
    final state = ble.connectionState;
    final isReadyOrConnected = state == BleConnectionState.ready || state == BleConnectionState.connected;
    final statusColor = _getStatusColor(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hardware Connection',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryTeal,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: AppTheme.textMuted,
          onTap: (index) {
            if (appBle != null) {
              if (index == 0) appBle.switchToWifiMode();
              if (index == 1) appBle.switchToBleMode();
              if (index == 2) appBle.toggleSimulatorMode(true);
            }
          },
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: 'Wi-Fi Hotspot'),
            Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth BLE'),
            Tab(icon: Icon(Icons.laptop_chromebook), text: 'Simulator'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showDebugInfo ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebugInfo ? AppTheme.primaryTeal : AppTheme.textMuted,
            ),
            tooltip: 'Toggle Debug Panel',
            onPressed: () => setState(() => _showDebugInfo = !_showDebugInfo),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Card
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
                      appBle?.isWifiMode == true
                          ? Icons.wifi
                          : (ble.isSimulatorMode ? Icons.sensors : Icons.bluetooth),
                      size: 36,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isReadyOrConnected
                        ? '🟢 Hardware Connected & Streaming'
                        : (state == BleConnectionState.connecting ? '🟡 Connecting...' : '🔴 Device Disconnected'),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ble.connectedDeviceName ?? 'Not connected',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab-specific View
            if (_tabController.index == 0) ...[
              _buildWifiSection(appBle),
            ] else if (_tabController.index == 1) ...[
              _buildBleSection(ble),
            ] else ...[
              _buildSimulatorSection(ble),
            ],

            // Debug Information
            if (_showDebugInfo) ...[
              const SizedBox(height: 20),
              _buildDebugSection(ble, appBle),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWifiSection(AppBleService? appBle) {
    final wifi = appBle?.wifiService;
    final isConnected = wifi?.isConnected ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Instructions Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryTeal.withAlpha(60)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primaryTeal, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'How to connect ESP32 over Wi-Fi:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                '1. In your phone\'s Wi-Fi settings, connect to the ESP32 network (e.g. SwasthAI_Screener or COPD_Screening).\n'
                '2. Default IP is 192.168.4.1 (ESP32 SoftAP).\n'
                '3. Tap "Connect via Wi-Fi" below to start streaming vitals and spirometry.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // IP and Port Configuration
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ESP32 Network Endpoint',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textLight),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _ipController,
                      style: const TextStyle(color: AppTheme.textLight, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        labelText: 'IP Address',
                        labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.surfaceDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textLight, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        labelText: 'Port',
                        labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.surfaceDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Quick IP presets
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('192.168.4.1 (SoftAP)', style: TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => _ipController.text = '192.168.4.1'),
                  ),
                  ActionChip(
                    label: const Text('192.168.1.184 (Local)', style: TextStyle(fontSize: 11)),
                    onPressed: () => setState(() => _ipController.text = '192.168.1.184'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_pingResult != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_pingResult!, style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                ),
                const SizedBox(height: 14),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isConnected
                          ? () => wifi?.disconnect()
                          : (_isConnectingWifi || appBle == null ? null : () => _connectWifi(appBle)),
                      icon: _isConnectingWifi
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(isConnected ? Icons.link_off : Icons.wifi),
                      label: Text(isConnected ? 'Disconnect Wi-Fi' : (_isConnectingWifi ? 'Connecting...' : 'Connect via Wi-Fi')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected ? AppTheme.riskCritical : AppTheme.primaryTeal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _isPinging || appBle == null ? null : () => _pingEsp32(appBle),
                    icon: _isPinging
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal))
                        : const Icon(Icons.network_ping, size: 18),
                    label: const Text('Ping'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryTeal,
                      side: const BorderSide(color: AppTheme.primaryTeal),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBleSection(BleService ble) {
    final isScanning = ble.connectionState == BleConnectionState.scanning;
    final isConnected = ble.connectionState == BleConnectionState.ready || ble.connectionState == BleConnectionState.connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nearby Bluetooth Devices',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight),
            ),
            ElevatedButton.icon(
              onPressed: isScanning ? null : () => ble.startScan(),
              icon: isScanning
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search, size: 16),
              label: Text(isScanning ? 'Scanning...' : 'Scan BLE'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (ble.discoveredDevices.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Icon(Icons.bluetooth_searching, size: 36, color: AppTheme.textMuted),
                SizedBox(height: 8),
                Text('No Bluetooth devices found yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                SizedBox(height: 4),
                Text('Tap "Scan BLE" to search for COPD_Screening / ESP32.', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ] else ...[
          ...ble.discoveredDevices.map((dev) {
            final isScreener = dev.name.toUpperCase().contains('COPD') ||
                dev.name.toUpperCase().contains('SWAAS') ||
                dev.name.toUpperCase().contains('SWASTH') ||
                dev.name.toUpperCase().contains('ESP32') ||
                dev.id.toUpperCase() == '1C:C3:AB:B3:03:A2';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isScreener ? AppTheme.primaryTeal.withAlpha(20) : AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isScreener ? AppTheme.primaryTeal : Colors.white10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isScreener ? AppTheme.primaryTeal : Colors.grey.withAlpha(40),
                    child: Icon(isScreener ? Icons.medical_services_outlined : Icons.bluetooth, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dev.name,
                          style: TextStyle(
                            fontWeight: isScreener ? FontWeight.bold : FontWeight.normal,
                            color: AppTheme.textLight,
                            fontSize: 14,
                          ),
                        ),
                        Text('${dev.id} • ${dev.signalStrengthDescription}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => ble.connectToDevice(dev),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                    child: const Text('Connect', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            );
          }),
        ],

        if (isConnected) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ble.disconnect(),
            icon: const Icon(Icons.link_off, color: AppTheme.riskCritical, size: 18),
            label: const Text('Disconnect BLE', style: TextStyle(color: AppTheme.riskCritical)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.riskCritical)),
          ),
        ],
      ],
    );
  }

  Widget _buildSimulatorSection(BleService ble) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hardware Simulation Suite',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textLight),
          ),
          const SizedBox(height: 6),
          const Text(
            'Simulate patient spirometry blows, pulse oximeter vitals, and cough acoustics without physical hardware.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => ble.triggerSimulatorBlow(simulateObstruction: false),
                icon: const Icon(Icons.air, size: 16),
                label: const Text('Simulate Normal Blow (FVC 3.6L)'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
              ),
              ElevatedButton.icon(
                onPressed: () => ble.triggerSimulatorBlow(simulateObstruction: true),
                icon: const Icon(Icons.warning_amber_rounded, size: 16),
                label: const Text('Simulate Obstructive Blow (COPD)'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.riskModerate),
              ),
              ElevatedButton.icon(
                onPressed: () => ble.triggerSimulatedCough(),
                icon: const Icon(Icons.graphic_eq, size: 16),
                label: const Text('Trigger Cough Event'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentIndigo),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugSection(BleService ble, AppBleService? appBle) {
    return Container(
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
                'Debug Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textLight),
              ),
            ],
          ),
          const Divider(color: AppTheme.surfaceElevated, height: 20),
          _buildDebugRow('Transport Mode:', appBle?.transportMode.name ?? 'BLE'),
          _buildDebugRow('Connection State:', ble.connectionState.name),
          _buildDebugRow('Connected Device:', ble.connectedDeviceName ?? 'None'),
          _buildDebugRow('Last Raw Packet:', ble.lastRawPacket ?? 'None'),
          _buildDebugRow(
            'Last Packet Time:',
            ble.lastPacketTime != null ? DateFormat('HH:mm:ss').format(ble.lastPacketTime!) : 'N/A',
          ),
        ],
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
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, color: AppTheme.textLight, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
