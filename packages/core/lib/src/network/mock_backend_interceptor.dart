import 'package:dio/dio.dart';

/// Simulated backend so the showcase runs without a server. Micro apps register
/// their own fake endpoints; production simply doesn't add this interceptor.
class MockBackendInterceptor extends Interceptor {
  MockBackendInterceptor({this.latency = const Duration(milliseconds: 500)});

  final Duration latency;
  final Map<String, Object? Function(RequestOptions request)> _routes = {};

  void on(String method, String path, Object? Function(RequestOptions request) handler) {
    _routes['${method.toUpperCase()} $path'] = handler;
  }

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final route = _routes['${options.method.toUpperCase()} ${options.path}'];
    if (route == null) return handler.next(options);
    await Future<void>.delayed(latency);
    try {
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: route(options)));
    } on MockHttpError catch (e) {
      // `true` runs the error interceptors, exactly as a real HTTP error response would.
      handler.reject(
        DioException.badResponse(
          statusCode: e.status,
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: e.status, data: {'message': e.message}),
        ),
        true,
      );
    }
  }
}

class MockHttpError implements Exception {
  const MockHttpError(this.status, this.message);
  final int status;
  final String message;
}
