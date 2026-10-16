import 'dart:io';

import 'package:dio/dio.dart';

import '../error/failure.dart';
import '../events/app_events.dart';
import '../events/event_bus.dart';

/// Single HTTP client shared by all micro apps: auth header, timeouts, logging and
/// error mapping are configured once in the shell.
class ApiClient {
  ApiClient(
      {required String baseUrl, required EventBus bus, String? Function()? token, List<Interceptor> extra = const []})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            contentType: Headers.jsonContentType,
          ),
        ) {
    dio.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final value = token?.call();
          if (value != null) options.headers['Authorization'] = 'Bearer $value';
          handler.next(options);
        },
        onError: (error, handler) {
          // Any micro app hitting 401 signals the shell, which redirects to login.
          if (error.response?.statusCode == 401) bus.publish(const SessionExpiredEvent());
          handler.next(error);
        },
      ),
      ...extra,
    ]);
  }

  final Dio dio;

  /// Converts transport errors into domain failures.
  static Failure mapError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.error is SocketException) {
        return const NetworkFailure();
      }
      final status = error.response?.statusCode ?? 0;
      if (status == 401) return const UnauthorizedFailure();
      if (status == 422 || status == 400) {
        final data = error.response?.data;
        final message = data is Map ? data['message'] as String? : null;
        return ValidationFailure(message ?? 'Dados inválidos.');
      }
      return const ServerFailure();
    }
    return const ServerFailure();
  }
}
