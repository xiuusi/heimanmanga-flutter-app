import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

/// Dio HTTP客户端服务，单例模式
/// 提供配置好的Dio实例，自动添加User-Agent头
class DioService {
  static final DioService _instance = DioService._internal();
  late Dio _dio;

  factory DioService() {
    return _instance;
  }

  DioService._internal() {
    _initDio();
  }

  /// 获取Dio实例
  Dio get dio => _dio;

  /// 初始化Dio配置
  void _initDio() {
    final options = BaseOptions(
      baseUrl: MangaApiService.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
      },
    );

    _dio = Dio(options);

    // 添加拦截器，自动设置User-Agent
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 从MangaApiService获取User-Agent
        final userAgent = MangaApiService.userAgent;
        if (userAgent.isNotEmpty) {
          options.headers['User-Agent'] = userAgent;
        }

        // 调试信息
        if (MangaApiService.debugMode) {
          debugPrint('[Dio] Request: ${options.method} ${options.uri}');
          debugPrint('[Dio] Headers: ${options.headers}');
        }

        handler.next(options);
      },
      onResponse: (response, handler) {
        // 调试信息
        if (MangaApiService.debugMode) {
          debugPrint('[Dio] Response: ${response.statusCode} ${response.statusMessage}');
          debugPrint('[Dio] Response headers: ${response.headers}');
          final data = response.data;
          if (data is Map || data is List) {
            debugPrint('[Dio] Response data: ${data.toString().length > 200 ? '${data.toString().substring(0, 200)}...' : data}');
          }
        }
        handler.next(response);
      },
      onError: (error, handler) {
        // 调试信息
        if (MangaApiService.debugMode) {
          debugPrint('[Dio] Error: ${error.type}');
          debugPrint('[Dio] Error message: ${error.message}');
          if (error.response != null) {
            debugPrint('[Dio] Error response status: ${error.response?.statusCode}');
            debugPrint('[Dio] Error response data: ${error.response?.data}');
          }
        }
        handler.next(error);
      },
    ));
  }
}