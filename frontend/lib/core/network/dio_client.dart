import 'dart:async';

import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class DioClient {
  late final Dio _dio;

  // In-memory access token for fast access
  String? _accessToken;

  /// Guards concurrent token refreshes.
  Completer<bool>? _refreshCompleter;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Don't attempt token refresh for auth endpoints themselves
          final path = error.requestOptions.path;
          final isAuthEndpoint = path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/refresh');

          if (error.response?.statusCode == 401 && !isAuthEndpoint) {
            // Try to refresh token
            final refreshed = await _tryRefresh();
            if (refreshed) {
              // Retry the original request
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $_accessToken';
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.reject(error);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  void setAccessToken(String token) {
    _accessToken = token;
  }

  void clearAccessToken() {
    _accessToken = null;
  }

  String? get accessToken => _accessToken;

  Future<bool> _tryRefresh() async {
    // If a refresh is already in-flight, wait for it instead of firing another.
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<bool>();
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(false);
        return false;
      }

      // Use a separate Dio instance to avoid interceptor loops
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final response = await refreshDio.post(
        ApiConstants.refresh,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccess = response.data['access_token'] as String;
        final newRefresh = response.data['refresh_token'] as String;
        _accessToken = newAccess;
        await SecureStorage.setAccessToken(newAccess);
        await SecureStorage.setRefreshToken(newRefresh);
        _refreshCompleter!.complete(true);
        return true;
      }
      _refreshCompleter!.complete(false);
    } catch (_) {
      // Refresh failed, user needs to re-login
      _refreshCompleter!.complete(false);
    } finally {
      _refreshCompleter = null;
    }
    return false;
  }

  // Convenience methods

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }
}
