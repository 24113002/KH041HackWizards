import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  final http.Client _httpClient;

  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '${ApiConfig.baseUrl}$cleanPath';
    final uri = Uri.parse(fullUrl);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(
        queryParameters: queryParameters.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );
    }
    return uri;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final uri = _buildUri(path, queryParameters);
    try {
      final response = await _httpClient
          .get(uri, headers: _defaultHeaders)
          .timeout(ApiConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException catch (e) {
      debugPrint('[ApiClient] Network connection failed: $e');
      throw ApiException('Unable to connect to SwasthAI server. Please check connection.', details: e);
    } on TimeoutException catch (e) {
      debugPrint('[ApiClient] Request timed out: $e');
      throw ApiException('Server request timed out. Please try again.', details: e);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('[ApiClient] Unexpected error: $e');
      throw ApiException('An unexpected network error occurred: $e');
    }
  }

  Future<dynamic> post(String path, {dynamic body, Map<String, dynamic>? queryParameters}) async {
    final uri = _buildUri(path, queryParameters);
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: _defaultHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException catch (e) {
      debugPrint('[ApiClient] Network connection failed: $e');
      throw ApiException('Unable to connect to SwasthAI server. Please check connection.', details: e);
    } on TimeoutException catch (e) {
      debugPrint('[ApiClient] Request timed out: $e');
      throw ApiException('Server request timed out. Please try again.', details: e);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('[ApiClient] Unexpected error: $e');
      throw ApiException('An unexpected network error occurred: $e');
    }
  }

  Future<dynamic> put(String path, {dynamic body, Map<String, dynamic>? queryParameters}) async {
    final uri = _buildUri(path, queryParameters);
    try {
      final response = await _httpClient
          .put(
            uri,
            headers: _defaultHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException catch (e) {
      debugPrint('[ApiClient] Network connection failed: $e');
      throw ApiException('Unable to connect to SwasthAI server. Please check connection.', details: e);
    } on TimeoutException catch (e) {
      debugPrint('[ApiClient] Request timed out: $e');
      throw ApiException('Server request timed out. Please try again.', details: e);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('[ApiClient] Unexpected error: $e');
      throw ApiException('An unexpected network error occurred: $e');
    }
  }

  Future<void> delete(String path, {Map<String, dynamic>? queryParameters}) async {
    final uri = _buildUri(path, queryParameters);
    try {
      final response = await _httpClient
          .delete(uri, headers: _defaultHeaders)
          .timeout(ApiConfig.requestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException('Unable to connect to SwasthAI server.', details: e);
    } on TimeoutException catch (e) {
      throw ApiException('Server request timed out.', details: e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected network error occurred: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String errorMessage = 'Server error (${response.statusCode})';
    if (decoded is Map) {
      if (decoded['detail'] is String) {
        errorMessage = decoded['detail'] as String;
      } else if (decoded['message'] is String) {
        errorMessage = decoded['message'] as String;
      } else if (decoded['detail'] is List) {
        // FastAPI validation errors
        final list = decoded['detail'] as List;
        final msgs = list.map((item) => item is Map ? (item['msg'] ?? item.toString()) : item.toString());
        errorMessage = msgs.join(', ');
      }
    }

    throw ApiException(
      errorMessage,
      statusCode: response.statusCode,
      details: decoded,
    );
  }
}
