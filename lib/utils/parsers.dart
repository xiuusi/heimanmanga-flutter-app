/// 数据解析工具类，用于处理可能的数据类型不匹配问题
class DataParsers {
  /// 安全解析字符串值
  static String parseString(dynamic value, [String defaultValue = '']) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  /// 安全解析整数值
  static int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    // 如果值是数字类型但不是int（如double），尝试转换
    if (value is num) return value.toInt();
    return null;
  }

  /// 安全解析整数值，带默认值
  static int parseIntWithDefault(dynamic value, [int defaultValue = 0]) {
    return parseInt(value) ?? defaultValue;
  }

  /// 安全解析列表
  static List<dynamic>? parseList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      // 确保列表不为空
      if (value.isEmpty) return null;
      return value;
    }
    return null;
  }

  /// 安全解析映射
  static Map<String, dynamic>? parseMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  /// 安全解析字符串映射
  static Map<String, String>? parseStringMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      Map<String, String> result = {};
      value.forEach((key, val) {
        result[key.toString()] = val.toString();
      });
      return result;
    }
    return null;
  }

  /// 安全解析布尔值
  static bool parseBool(dynamic value, [bool defaultValue = false]) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return defaultValue;
  }
}