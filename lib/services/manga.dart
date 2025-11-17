import '../utils/parsers.dart';
import '../services/api_service.dart';

class Manga {
  final String id;
  final String title;
  final String author;
  final String description;
  final String coverPath;
  final String filePath;
  final String fileName;
  final int fileSize;
  final String uploadTime;
  final List<Chapter> chapters;
  final List<TagModel> tags;

  Manga({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverPath,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.uploadTime,
    required this.chapters,
    required this.tags,
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    return Manga(
      id: DataParsers.parseString(json['id']),
      title: DataParsers.parseString(json['title']),
      author: DataParsers.parseString(json['author']),
      description: DataParsers.parseString(json['description']),
      coverPath: DataParsers.parseString(json['cover_path'] ?? json['coverPath']),
      filePath: DataParsers.parseString(json['file_path'] ?? json['filePath']),
      fileName: DataParsers.parseString(json['file_name'] ?? json['fileName']),
      fileSize: DataParsers.parseIntWithDefault(json['file_size'] ?? json['fileSize']),
      uploadTime: DataParsers.parseString(json['upload_time'] ?? json['uploadTime']),
      chapters: DataParsers.parseList(json['chapters'])
              ?.map((item) => Chapter.fromJson(item as Map<String, dynamic>))
              .toList()
          ?? [],
      tags: DataParsers.parseList(json['tags'])
              ?.map((item) => TagModel.fromJson(item as Map<String, dynamic>))
              .toList()
          ?? [],
    );
  }
}

class Chapter {
  final String id;
  final String mangaId;
  final String title;
  final int number;
  final String filePath;
  final String fileName;
  final int fileSize;
  final String uploadTime;
  final List<String>? imageList;
  final Map<String, String>? imageIdMap;

  Chapter({
    required this.id,
    required this.mangaId,
    required this.title,
    required this.number,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.uploadTime,
    this.imageList,
    this.imageIdMap,
  });

  List<String> getImageUrls(String mangaId) {
    List<String> imageUrls = [];
    
    if (imageList != null && imageList!.isNotEmpty) {
      // 如果有imageList，尝试构建完整的图片URL
      for (String imageFileName in imageList!) {
        // 使用API服务构建完整的图片URL
        imageUrls.add(MangaApiService.getChapterImageUrl(mangaId, id, imageFileName));
      }
    } else if (imageIdMap != null && imageIdMap!.isNotEmpty) {
      // 如果有imageIdMap，按照键的顺序排序以确保正确的图片顺序
      var sortedKeys = imageIdMap!.keys.toList()..sort();
      for (String key in sortedKeys) {
        String fileName = imageIdMap![key]!;
        imageUrls.add(MangaApiService.getChapterImageUrl(mangaId, id, fileName));
      }
    }
    return imageUrls;
  }
  
  /// 获取章节文件URL，可以用来获取图片列表
  String getChapterFileUrl(String mangaId) {
    return MangaApiService.getChapterFileUrl(mangaId, id);
  }
  
  /// 获取章节图片文件列表的URL
  String getChapterFilesUrl(String mangaId) {
    return MangaApiService.getChapterFilesUrl(mangaId, id);
  }

  /// 获取章节的总页数
  int get totalPages {
    if (imageList != null && imageList!.isNotEmpty) {
      return imageList!.length;
    } else if (imageIdMap != null && imageIdMap!.isNotEmpty) {
      return imageIdMap!.length;
    }
    return 0;
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: DataParsers.parseString(json['id']),
      mangaId: DataParsers.parseString(json['manga_id'] ?? json['mangaId']),
      title: DataParsers.parseString(json['title']),
      number: DataParsers.parseIntWithDefault(json['number']),
      filePath: DataParsers.parseString(json['file_path'] ?? json['filePath']),
      fileName: DataParsers.parseString(json['file_name'] ?? json['fileName']),
      fileSize: DataParsers.parseIntWithDefault(json['file_size'] ?? json['fileSize']),
      uploadTime: DataParsers.parseString(json['upload_time'] ?? json['uploadTime']),
      imageList: DataParsers.parseList(json['image_list'] ?? json['imageList'])
              ?.map((e) => e.toString())
              .toList(),
      imageIdMap: DataParsers.parseStringMap(json['image_id_map'] ?? json['imageIdMap']),
    );
  }
}


class MangaListResponse {
  final List<Manga> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  MangaListResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory MangaListResponse.fromJson(Map<String, dynamic> json) {
    return MangaListResponse(
      data: DataParsers.parseList(json['data'])
              ?.map((item) => Manga.fromJson(item as Map<String, dynamic>))
              .toList()
          ?? [],
      total: DataParsers.parseIntWithDefault(json['total']),
      page: DataParsers.parseIntWithDefault(json['page']),
      limit: DataParsers.parseIntWithDefault(json['limit']),
      totalPages: DataParsers.parseIntWithDefault(json['totalPages']),
    );
  }
}

// ========== 轮播图模型 ==========

class CarouselImage {
  final int id;
  final String title;
  final String linkUrl;
  final String imagePath;
  final int sortOrder;
  final bool isActive;
  final String createdAt;

  CarouselImage({
    required this.id,
    required this.title,
    required this.linkUrl,
    required this.imagePath,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
  });

  factory CarouselImage.fromJson(Map<String, dynamic> json) {
    return CarouselImage(
      id: DataParsers.parseIntWithDefault(json['id']),
      title: DataParsers.parseString(json['title']),
      linkUrl: DataParsers.parseString(json['link_url']),
      imagePath: DataParsers.parseString(json['image_path']),
      sortOrder: DataParsers.parseIntWithDefault(json['sort_order']),
      isActive: DataParsers.parseBool(json['is_active'] ?? true),
      createdAt: DataParsers.parseString(json['created_at']),
    );
  }
}

class CarouselResponse {
  final List<CarouselImage> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  CarouselResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory CarouselResponse.fromJson(Map<String, dynamic> json) {
    return CarouselResponse(
      data: DataParsers.parseList(json['data'])
              ?.map((item) => CarouselImage.fromJson(item as Map<String, dynamic>))
              .toList()
          ?? [],
      total: DataParsers.parseIntWithDefault(json['total']),
      page: DataParsers.parseIntWithDefault(json['page']),
      limit: DataParsers.parseIntWithDefault(json['limit']),
      totalPages: DataParsers.parseIntWithDefault(json['totalPages']),
    );
  }
}

// ========== 标签分类模型 ==========

class TagNamespace {
  final int id;
  final String name;
  final String displayName;
  final String? description;

  TagNamespace({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
  });

  factory TagNamespace.fromJson(Map<String, dynamic> json) {
    return TagNamespace(
      id: DataParsers.parseIntWithDefault(json['id']),
      name: DataParsers.parseString(json['name']),
      displayName: DataParsers.parseString(json['display_name']),
      description: DataParsers.parseString(json['description']),
    );
  }
}

// 更新现有的Tag类以匹配后端返回格式
class TagModel {
  final int id;
  final int namespaceId;
  final String namespaceName;
  final String namespaceDisplayName;
  final String name;
  final String slug;
  final String? description;
  final int count;

  TagModel({
    required this.id,
    required this.namespaceId,
    required this.namespaceName,
    required this.namespaceDisplayName,
    required this.name,
    required this.slug,
    this.description,
    required this.count,
  });

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      id: DataParsers.parseIntWithDefault(json['id']),
      namespaceId: DataParsers.parseIntWithDefault(json['namespace_id']),
      namespaceName: DataParsers.parseString(json['namespace_name']),
      namespaceDisplayName: DataParsers.parseString(json['namespace_display_name']),
      name: DataParsers.parseString(json['name']),
      slug: DataParsers.parseString(json['slug']),
      description: DataParsers.parseString(json['description']),
      count: DataParsers.parseIntWithDefault(json['count']),
    );
  }

  /// 获取命名空间名称（用于兼容现有代码）
  String get namespace => namespaceName;

  /// 获取显示名称（用于兼容现有代码）
  String get displayName => name;
}
