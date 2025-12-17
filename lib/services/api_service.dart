import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/manga.dart';

class MangaApiService {
  static const String baseUrl = 'https://www.heiman.cc'; // Web端API的URL

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

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return MangaListResponse.fromJson(jsonData);
      } else {
        throw Exception('获取漫画列表失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取漫画列表失败: $e');
    }
  }

  static Future<Manga> getMangaById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/manga/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return Manga.fromJson(jsonData);
      } else {
        throw Exception('获取漫画详情失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取漫画详情失败: $e');
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
      final response = await http.get(
        Uri.parse(getChapterFilesUrl(mangaId, chapterId)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
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

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/tag/namespaces'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
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

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags/search?q=${Uri.encodeComponent(query)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
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

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
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

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

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
