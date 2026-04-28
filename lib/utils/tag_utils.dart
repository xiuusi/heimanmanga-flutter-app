import 'package:flutter/material.dart';

class TagUtils {
  static const Map<int, _NamespaceInfo> _namespaceMap = {
    1: _NamespaceInfo('type', '类型'),
    2: _NamespaceInfo('artist', '作者'),
    3: _NamespaceInfo('character', '角色'),
    4: _NamespaceInfo('main', '主体'),
    5: _NamespaceInfo('sub', '子类'),
  };

  static String namespaceNameFromId(int namespaceId) {
    return _namespaceMap[namespaceId]?.name ?? 'unknown';
  }

  static String namespaceDisplayNameFromId(int namespaceId) {
    return _namespaceMap[namespaceId]?.displayName ?? '未知';
  }

  static Color detailTagColor(String namespace) {
    switch (namespace) {
      case 'type':
        return const Color(0xFF1565C0);
      case 'artist':
        return const Color(0xFF7B1FA2);
      case 'main':
        return const Color(0xFFEF6C00);
      case 'sub':
        return const Color(0xFF757575);
      default:
        return const Color(0xFF1565C0);
    }
  }

  static Color tagChipBackgroundColor(String namespace) {
    switch (namespace) {
      case 'type':
        return const Color(0xFFFFCDD2);
      case 'artist':
        return const Color(0xFFC8E6C9);
      case 'character':
        return const Color(0xFFBBDEFB);
      case 'main':
        return const Color(0xFFFFE0B2);
      case 'sub':
        return const Color(0xFFF3E5F5);
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  static Color tagChipTextColor(String namespace) {
    switch (namespace) {
      case 'type':
        return const Color(0xFFC62828);
      case 'artist':
        return const Color(0xFF2E7D32);
      case 'character':
        return const Color(0xFF1565C0);
      case 'main':
        return const Color(0xFFEF6C00);
      case 'sub':
        return const Color(0xFF7B1FA2);
      default:
        return Colors.black87;
    }
  }
}

class _NamespaceInfo {
  final String name;
  final String displayName;
  const _NamespaceInfo(this.name, this.displayName);
}
