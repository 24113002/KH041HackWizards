import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Default base URL for the FastAPI backend
  /// For Android emulator: http://10.0.2.2:8000/api
  /// For Windows/Desktop/iOS/Web: http://127.0.0.1:8000/api
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api';
      }
    } catch (_) {
      // Fallback for non-standard platforms
    }
    return 'http://127.0.0.1:8000/api';
  }

  static String baseUrl = defaultBaseUrl;

  /// Root URL (without /api) for root /health endpoint
  static String get rootUrl {
    if (baseUrl.endsWith('/api')) {
      return baseUrl.substring(0, baseUrl.length - 4);
    }
    return baseUrl;
  }

  /// Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Endpoint paths
  static const String healthPath = '/health';
  static const String patientsPath = '/patients';
  static const String screeningsPath = '/screenings';
}
