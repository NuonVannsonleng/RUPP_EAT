import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Error raised for any failed API call, with a user-friendly message.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;

  /// First validation error for a field, if any.
  String? fieldError(String field) {
    final value = errors?[field];
    if (value is List && value.isNotEmpty) return value.first.toString();
    return null;
  }

  @override
  String toString() => message;
}

/// A page of results from a paginated endpoint.
class Paged<T> {
  Paged(this.items, this.currentPage, this.lastPage, {this.extra = const {}});

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final Map<String, dynamic> extra;

  bool get hasMore => currentPage < lastPage;
}

/// Thin Dio wrapper. Every RUPP Eat response is { success, message, data, meta?, errors? }.
class ApiClient {
  ApiClient(this._tokens) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Accept': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.read();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) onUnauthorized?.call();
        handler.next(error);
      },
    ));
  }

  final TokenStorage _tokens;
  late final Dio _dio;

  /// Called when the server rejects our token (expired / revoked / suspended).
  void Function()? onUnauthorized;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<Map<String, dynamic>> post(String path, {Object? data, Map<String, String>? headers}) =>
      _send(() => _dio.post(path, data: data, options: Options(headers: headers)));

  Future<Map<String, dynamic>> put(String path, {Object? data}) => _send(() => _dio.put(path, data: data));

  Future<Map<String, dynamic>> patch(String path, {Object? data}) => _send(() => _dio.patch(path, data: data));

  Future<Map<String, dynamic>> delete(String path) => _send(() => _dio.delete(path));

  /// GET a paginated list and map each item.
  Future<Paged<T>> getPaged<T>(String path, T Function(Map<String, dynamic>) map, {Map<String, dynamic>? query}) async {
    final body = await get(path, query: query);
    final list = (body['data'] as List? ?? []).cast<Map<String, dynamic>>().map(map).toList();
    final meta = (body['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    return Paged(list, (meta['current_page'] ?? 1) as int, (meta['last_page'] ?? 1) as int, extra: meta);
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    q?.removeWhere((_, v) => v == null || v == '');
    return q;
  }

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final res = await request();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return {'success': true, 'data': data};
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final res = e.response;
    if (res == null) {
      final offline = e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout;
      return ApiException(offline
          ? 'Cannot reach the RUPP Eat server. Check your internet connection and that the backend is running.'
          : 'The request timed out. Please try again.');
    }
    final body = res.data;
    if (body is Map) {
      final errors = (body['errors'] as Map?)?.cast<String, dynamic>();
      return ApiException(
        (body['message'] as String?) ?? 'Something went wrong (${res.statusCode}).',
        statusCode: res.statusCode,
        errors: errors,
      );
    }
    return ApiException('Server error (${res.statusCode}). Please try again.', statusCode: res.statusCode);
  }
}
