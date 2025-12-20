import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/manga.dart';
import 'dio_service.dart';

class MangaApiService {
  static const String baseUrl = 'https://www.heiman.cc'; // Web端API的URL
  static String _userAgent = '';

  /// 调试模式开关
  static bool debugMode = true;

  /// 初始化User-Agent，应在应用启动时调用
  static Future<void> initUserAgent() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      // 使用硬编码的app名称"heiman"，而不是从PackageInfo获取的appName
      const appName = 'heiman';
      final version = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      // 格式: {app名称}-{版本号}-{架构号}
      // 架构号使用buildNumber，如果buildNumber为空则省略
      final architecture = buildNumber.isNotEmpty ? buildNumber : 'unknown';
      // 清理所有部分，移除非ASCII字符，避免HTTP头格式错误
      final cleanedAppName = _cleanForHttpHeader(appName);
      final cleanedVersion = _cleanForHttpHeader(version);
      final cleanedArchitecture = _cleanForHttpHeader(architecture);
      _userAgent = '$cleanedAppName-$cleanedVersion-$cleanedArchitecture';

      // 设置全局HttpClient的User-Agent，用于所有网络请求（包括图片加载）
      _setGlobalHttpClientUserAgent(_userAgent);
    } catch (e) {
      // 如果获取失败，使用默认值
      _userAgent = 'heiman-unknown-unknown';
      _setGlobalHttpClientUserAgent(_userAgent);
    }
  }

  /// 清理字符串，移除非ASCII字符，只保留ASCII可打印字符（0x20-0x7E）
  /// 替换非ASCII字符为下划线，并移除控制字符
  static String _cleanForHttpHeader(String input) {
    if (input.isEmpty) return input;
    final result = StringBuffer();
    for (final codeUnit in input.codeUnits) {
      // 只保留ASCII可打印字符（空格到波浪号）
      if (codeUnit >= 0x20 && codeUnit <= 0x7E) {
        result.writeCharCode(codeUnit);
      } else {
        // 非ASCII字符或控制字符替换为下划线
        result.write('_');
      }
    }
    return result.toString();
  }

  /// 设置全局HttpClient的User-Agent
  /// 这会影响所有使用HttpClient的网络请求，包括图片加载
  /// 注意：在较新的Flutter/Dart版本中，HttpClient.defaultHttpClient可能不可用
  /// 现在通过dio拦截器和图片加载的httpHeaders参数设置User-Agent
  static void _setGlobalHttpClientUserAgent(String userAgent) {
    try {
      // 旧方式：HttpClient.defaultHttpClient.userAgent = userAgent;
      // 现在已不再需要，因为：
      // 1. dio拦截器已设置User-Agent
      // 2. 图片加载通过httpHeaders参数设置User-Agent
      // 3. 这个API在较新版本中可能不可用
    } catch (e) {
      // 设置失败，但不影响主要功能
      if (debugMode) {
        print('[API] Failed to set global HttpClient user agent: $e');
      }
    }
  }

  /// 获取当前User-Agent字符串
  static String get userAgent => _userAgent;

  /// 获取请求头，包含User-Agent（如果已初始化）
  static Map<String, String> _getHeaders({bool acceptJson = true, bool contentTypeJson = false}) {
    final headers = <String, String>{};
    if (acceptJson) {
      headers['Accept'] = 'application/json';
    }
    if (contentTypeJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (_userAgent.isNotEmpty) {
      headers['User-Agent'] = _userAgent;
    }

    // 调试信息
    if (debugMode) {
      print('[API] 请求头: $headers');
      print('[API] User-Agent: $_userAgent');
    }

    return headers;
  }

  static Future<MangaListResponse> getMangaList({
    int page = 1,
    int limit = 20,
    String? tag,
  }) async {
    try {
      String url = '$baseUrl/api/manga?page=$page&limit=$limit';
      if (tag != null) {
        url += '&tag=$tag';
      }

      // Debug info: print request URL
      if (debugMode) {
        print('[API] Request manga list URL: $url');
      }

      final dio = DioService().dio;
      final response = await dio.get(
        url,
        options: Options(headers: _getHeaders(acceptJson: true, contentTypeJson: false)),
      );

      // Debug info: print response details
      if (debugMode) {
        print('[API] Response status: ${response.statusCode}');
        print('[API] Response headers: ${response.headers.map}');
        // Print first 200 chars of response body
        final responseData = response.data;
        final bodyStr = responseData is String ? responseData : responseData.toString();
        final bodyPreview = bodyStr.length > 200
            ? '${bodyStr.substring(0, 200)}...'
            : bodyStr;
        print('[API] Response body preview: $bodyPreview');
      }

      if (response.statusCode == 200) {
        final jsonData = response.data is Map ? response.data as Map<String, dynamic> : json.decode(response.data as String);
        return MangaListResponse.fromJson(jsonData);
      } else {
        throw Exception('Failed to load manga list: ${response.statusCode}');
      }
    } catch (e) {
      // Debug info: print exception
      if (debugMode) {
        print('[API] Exception in getMangaList: $e');
        if (e is Error) {
          print('[API] Stack trace: ${e.stackTrace}');
        }
      }
      throw Exception('Failed to load manga list: $e');
    }
  }

  static Future<Manga> getMangaById(String id) async {
    try {
      String url = '$baseUrl/api/manga/$id';

      // Debug info: print request URL
      if (debugMode) {
        print('[API] Request manga details URL: $url');
      }

      final dio = DioService().dio;
      final response = await dio.get(
        url,
        options: Options(headers: _getHeaders(acceptJson: false, contentTypeJson: true)),
      );

      // Debug info: print response details
      if (debugMode) {
        print('[API] Response status: ${response.statusCode}');
        print('[API] Response headers: ${response.headers.map}');
        // Print first 200 chars of response body
        final responseData = response.data;
        final bodyStr = responseData is String ? responseData : responseData.toString();
        final bodyPreview = bodyStr.length > 200
            ? '${bodyStr.substring(0, 200)}...'
            : bodyStr;
        print('[API] Response body preview: $bodyPreview');
      }

      if (response.statusCode == 200) {
        final jsonData = response.data is Map ? response.data as Map<String, dynamic> : json.decode(response.data as String);
        return Manga.fromJson(jsonData);
      } else {
        throw Exception('Failed to load manga details: ${response.statusCode}');
      }
    } catch (e) {
      // Debug info: print exception
      if (debugMode) {
        print('[API] Exception in getMangaById: $e');
        if (e is Error) {
          print('[API] Stack trace: ${e.stackTrace}');
        }
      }
      throw Exception('Failed to load manga details: $e');
    }
  }

  static String getCoverUrl(String mangaId) {
    return '$baseUrl/api/manga/$mangaId/cover';
  }
  
  static String getMangaFileUrl(String mangaId) {
    return '$baseUrl/api/manga/$mangaId/file';
  }
  
  static String getChapterImageUrl(String mangaId, String chapterId, String imageName) {
    // 对图片名称进行URL编码，以避免特殊字符导致的问题
    String encodedImageName = Uri.encodeComponent(imageName);
    return '$baseUrl/api/manga/$mangaId/chapters/$chapterId/image/$encodedImageName';
  }
  
  static String getChapterFileUrl(String mangaId, String chapterId) {
    return '$baseUrl/api/manga/$mangaId/chapters/$chapterId/file';
  }
  
  static String getChapterFilesUrl(String mangaId, String chapterId) {
    return '$baseUrl/api/manga/$mangaId/chapters/$chapterId/files';
  }
  
  /// 获取章节图片文件列表
  static Future<List<String>> getChapterImageFiles(String mangaId, String chapterId) async {
    try {
      final dio = DioService().dio;
      final response = await dio.get(
        getChapterFilesUrl(mangaId, chapterId),
        options: Options(headers: _getHeaders(acceptJson: false, contentTypeJson: true)),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data is Map ? response.data as Map<String, dynamic> : json.decode(response.data as String);
        if (jsonData.containsKey('files') && jsonData['files'] is List) {
          List<dynamic> files = jsonData['files'];
          return files.cast<String>();
        }
      } else {
        // 获取章节文件列表失败
      }
    } catch (e) {
      // 获取章节文件列表异常
    }
    return [];
  }

  /// 搜索漫画
  static Future<MangaListResponse> searchManga(
    String query, {
    int page = 1,
    int limit = 21,
    String searchType = 'title', // 'title', 'author', 'tag'
  }) async {
    try {
      String url = '$baseUrl/api/manga/search?q=${Uri.encodeComponent(query)}&page=$page&limit=$limit&searchType=$searchType';

      final dio = DioService().dio;
      final response = await dio.get(
        url,
        options: Options(headers: _getHeaders(acceptJson: true, contentTypeJson: false)),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data is Map ? response.data as Map<String, dynamic> : json.decode(response.data as String);
        return MangaListResponse.fromJson(jsonData);
      } else {
        throw Exception('搜索漫画失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('搜索漫画失败: $e');
    }
  }

  /// 获取标签分类列表
  static Future<List<TagNamespace>> getTagNamespaces() async {
    try {
      final dio = DioService().dio;
      final response = await dio.get(
        '$baseUrl/api/tag/namespaces',
        options: Options(headers: _getHeaders(acceptJson: false, contentTypeJson: true)),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data as List<dynamic> : json.decode(response.data as String);
        return data.map((item) => TagNamespace.fromJson(item)).toList();
      } else {
        throw Exception('获取标签分类失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取标签分类失败: $e');
    }
  }

  /// 获取所有标签
  static Future<List<TagModel>> getTags({String? namespace}) async {
    try {
      String url = '$baseUrl/api/tags';
      if (namespace != null) {
        url += '?namespace=$namespace';
      }

      final dio = DioService().dio;
      final response = await dio.get(
        url,
        options: Options(headers: _getHeaders(acceptJson: true, contentTypeJson: false)),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data as List<dynamic> : json.decode(response.data as String);
        return data.map((item) => TagModel.fromJson(item)).toList();
      } else {
        throw Exception('获取标签失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取标签失败: $e');
    }
  }

  /// 搜索标签
  static Future<List<TagModel>> searchTags(String query) async {
    try {
      final dio = DioService().dio;
      final response = await dio.get(
        '$baseUrl/api/tags/search?q=${Uri.encodeComponent(query)}',
        options: Options(headers: _getHeaders(acceptJson: false, contentTypeJson: true)),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data as List<dynamic> : json.decode(response.data as String);
        return data.map((item) => TagModel.fromJson(item)).toList();
      } else {
        throw Exception('搜索标签失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('搜索标签失败: $e');
    }
  }

  /// 根据标签获取漫画列表
  static Future<MangaListResponse> getMangaByTag(
    int tagId, {
    int page = 1,
    int limit = 21,
  }) async {
    try {
      String url = '$baseUrl/api/manga?tag=$tagId&page=$page&limit=$limit';

      final dio = DioService().dio;
      final response = await dio.get(
        url,
        options: Options(headers: _getHeaders(acceptJson: true, contentTypeJson: false)),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data is Map ? response.data as Map<String, dynamic> : json.decode(response.data as String);
        return MangaListResponse.fromJson(jsonData);
      } else {
        throw Exception('根据标签获取漫画失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('根据标签获取漫画失败: $e');
    }
  }

  // ========== 轮播图API ==========

  /// 获取轮播图列表（支持分页）
  static Future<CarouselResponse> getCarouselImages({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      String url = '$baseUrl/api/carousel?page=$page&limit=$limit';

      final dio = DioService().dio;
      final response = await dio.get(
        url,
        options: Options(headers: _getHeaders(acceptJson: true, contentTypeJson: false)),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data is String ? json.decode(response.data as String) : response.data;

        Map<String, dynamic> formattedData;

        // 处理不同的API响应格式
        if (jsonData is List) {
          // API返回数组格式，包装成对象格式
          final List<dynamic> carouselList = jsonData;
          formattedData = {
            'data': carouselList,
            'total': carouselList.length,
            'page': page,
            'limit': limit,
            'totalPages': (carouselList.length / limit).ceil(),
          };
        } else if (jsonData is Map<String, dynamic>) {
          // API已经是对象格式
          formattedData = jsonData;
        } else {
          throw Exception('API返回了意外的数据类型: ${jsonData.runtimeType}');
        }

        return CarouselResponse.fromJson(formattedData);
      } else {
        throw Exception('获取轮播图失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取轮播图失败: $e');
    }
  }

  /// 获取轮播图图片URL
  static String getCarouselImageUrl(int carouselId) {
    return '$baseUrl/api/carousel/$carouselId/image';
  }
}
