import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'controllers/current_screening_controller.dart';
import 'controllers/patient_provider.dart';
import 'controllers/screening_history_controller.dart';
import 'data/database_helper.dart';
import 'repositories/patient_repository.dart';
import 'repositories/screening_repository.dart';
import 'repositories/sync_repository.dart';
import 'screens/home_screen.dart';
import 'services/backend_api_service.dart';
import 'services/ble_service.dart';
import 'services/sensor_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for desktop support if running on desktop or test environment
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Pre-initialize database
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('Database init warning: $e');
  }

  // Instantiate hybrid sync repositories & services
  final syncRepo = SyncRepository();
  final sensorService = MockSensorService();

  runApp(
    SwasthaiApp(
      patientRepository: syncRepo,
      screeningRepository: syncRepo,
      sensorService: sensorService,
    ),
  );
}


class SwasthaiApp extends StatelessWidget {
  final PatientRepository patientRepository;
  final ScreeningRepository screeningRepository;
  final SensorService sensorService;

  const SwasthaiApp({
    super.key,
    required this.patientRepository,
    required this.screeningRepository,
    required this.sensorService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PatientRepository>.value(value: patientRepository),
        Provider<ScreeningRepository>.value(value: screeningRepository),
        Provider<SensorService>.value(value: sensorService),
        ChangeNotifierProvider<BleService>(create: (_) => AppBleService()),
        ChangeNotifierProvider(create: (_) => PatientProvider(repository: patientRepository)),
        ChangeNotifierProvider(create: (_) => CurrentScreeningController()),
        ChangeNotifierProvider(create: (_) => ScreeningHistoryController(repository: screeningRepository)),
      ],
      child: MaterialApp(
        title: 'SWASTHAI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
