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
    if (value is Map<String, dynamic>) return value;
    // 不用 Map.cast：键不是 String 时它会在访问时抛异常
    if (value is Map) {
      final Map<String, dynamic> result = {};
      value.forEach((key, val) {
        result[key.toString()] = val;
      });
      return result;
    }
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
      // 同时接受 'true' / '1' / 'yes'（忽略大小写与首尾空白）
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return defaultValue;
  }
}