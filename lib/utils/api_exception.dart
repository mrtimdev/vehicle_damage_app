import 'dart:async';
import 'package:dio/dio.dart';

/// Clean, human-readable exception for AI provider request failures.
class AIAnalysisException implements Exception {
  final String title;
  final String message;
  final int? statusCode;
  final bool isTransient; // e.g. 503, 429, timeout
  final bool isAuthError; // e.g. 401, 403

  const AIAnalysisException({
    required this.title,
    required this.message,
    this.statusCode,
    this.isTransient = false,
    this.isAuthError = false,
  });

  @override
  String toString() => message;

  factory AIAnalysisException.fromDioException(
    DioException e, {
    required String providerName,
    required String modelName,
  }) {
    final status = e.response?.statusCode;
    String? serverDetail;

    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      if (data['error'] is Map && data['error']['message'] != null) {
        serverDetail = data['error']['message'].toString();
      } else if (data['error'] is String) {
        serverDetail = data['error'].toString();
      } else if (data['message'] != null) {
        serverDetail = data['message'].toString();
      }
    } else if (e.response?.data is String &&
        (e.response!.data as String).isNotEmpty) {
      final text = e.response!.data as String;
      if (text.length < 300) {
        serverDetail = text;
      }
    }

    if (status == 503) {
      return AIAnalysisException(
        title: 'Server Temporarily Overloaded (503)',
        message: serverDetail ??
            '$providerName is experiencing high server demand right now. This is temporary. Please try again shortly or switch models in Settings.',
        statusCode: 503,
        isTransient: true,
      );
    }

    if (status == 429) {
      return AIAnalysisException(
        title: 'Rate Limit Reached (429)',
        message: serverDetail ??
            'Too many requests sent to $providerName or quota exceeded. Please wait a moment before trying again.',
        statusCode: 429,
        isTransient: true,
      );
    }

    if (status == 401 || status == 403) {
      return AIAnalysisException(
        title: 'Authentication Error ($status)',
        message: serverDetail ??
            'The API key configured for $providerName was rejected. Please verify or update your API key in Settings.',
        statusCode: status,
        isAuthError: true,
      );
    }

    if (status == 404) {
      return AIAnalysisException(
        title: 'Model Not Found (404)',
        message: serverDetail ??
            'The model "$modelName" was not found on $providerName. Please select an available model in Settings.',
        statusCode: 404,
      );
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return AIAnalysisException(
        title: 'Network Timeout',
        message:
            'The connection to $providerName timed out. Please check your internet connection and try again.',
        isTransient: true,
      );
    }

    if (e.type == DioExceptionType.connectionError) {
      return const AIAnalysisException(
        title: 'Connection Error',
        message:
            'Could not establish connection to the AI provider. Please verify your internet connection or base URL.',
        isTransient: true,
      );
    }

    return AIAnalysisException(
      title: 'Analysis Request Failed',
      message: serverDetail ??
          (e.message ?? 'An unexpected server error occurred (${status ?? "unknown"}).'),
      statusCode: status,
    );
  }
}

/// Executes a Dio request with automatic retry on transient errors (503, 429, 502, 504, timeout).
Future<Response<T>> executeWithRetry<T>(
  Future<Response<T>> Function() request, {
  int maxRetries = 2,
  Duration initialDelay = const Duration(milliseconds: 1500),
  void Function(int attempt, int maxRetries)? onRetry,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await request();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final isRetryable = status == 503 ||
          status == 429 ||
          status == 502 ||
          status == 504 ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;

      if (isRetryable && attempt < maxRetries) {
        attempt++;
        onRetry?.call(attempt, maxRetries);
        final delay = initialDelay * attempt;
        await Future.delayed(delay);
        continue;
      }
      rethrow;
    }
  }
}
