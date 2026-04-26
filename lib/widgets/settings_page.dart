import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'about_page.dart';
import '../services/api_service.dart';
import '../services/dio_service.dart';
import '../services/reading_progress_service.dart';
import '../utils/theme_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ThemeManager _themeManager = ThemeManager();

  bool _isChecking = false;
  String _updateStatus = '';
  String? _latestVersion;
  String? _releaseUrl;

  static const _presetColors = [
    Color(0xFFFF6B6B),
    Color(0xFFE53935),
    Color(0xFFFF9800),
    Color(0xFFFFC107),
    Color(0xFF4CAF50),
    Color(0xFF00BCD4),
    Color(0xFF2196F3),
    Color(0xFF3F51B5),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  @override
  void initState() {
    super.initState();
    _themeManager.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeManager.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _updateStatus = '';
    });

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final dio = DioService().dio;
      final response = await dio.get(
        'https://api.github.com/repos/xiuusi/heimanmanga-flutter-app/releases',
      );

      if (response.statusCode == 200) {
        final List<dynamic> releases = response.data is List ? response.data as List<dynamic> : json.decode(response.data as String);

        if (releases.isNotEmpty) {
          final latestRelease = releases.first;
          final latestVersion = latestRelease['tag_name'] as String;

          setState(() {
            _latestVersion = latestVersion;
            _releaseUrl = latestRelease['html_url'] as String;
          });

          final currentVersionClean = currentVersion.replaceAll('v', '');
          final latestVersionClean = latestVersion.replaceAll('v', '');

          final bool hasUpdate = _isNewerVersion(latestVersionClean, currentVersionClean);

          if (hasUpdate) {
            if (mounted) {
              _showUpdateDialog(context);
            }
          } else {
            setState(() {
              _updateStatus = '当前为最新版';
            });
          }
        } else {
          setState(() {
            _updateStatus = '未找到发布版本';
          });
        }
      } else {
        setState(() {
          _updateStatus = '检查更新失败';
        });
      }
    } catch (e) {
      setState(() {
        _updateStatus = '网络连接失败';
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map((part) {
      final match = RegExp(r'\d+').firstMatch(part);
      return match != null ? int.parse(match.group(0)!) : 0;
    }).toList();

    final currentParts = current.split('.').map((part) {
      final match = RegExp(r'\d+').firstMatch(part);
      return match != null ? int.parse(match.group(0)!) : 0;
    }).toList();

    for (int i = 0; i < latestParts.length; i++) {
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      final currentPart = i < currentParts.length ? currentParts[i] : 0;

      if (latestPart > currentPart) {
        return true;
      } else if (latestPart < currentPart) {
        return false;
      }
    }

    return false;
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('最新版本: $_latestVersion'),
              const SizedBox(height: 8),
              const Text('请前往GitHub下载最新版本'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_releaseUrl != null) {
                  launchUrl(Uri.parse(_releaseUrl!));
                }
                Navigator.of(context).pop();
              },
              child: const Text('前往GitHub'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomColorDialog() {
    Color pickedColor = _themeManager.accentColor;
    double hue = HSVColor.fromColor(pickedColor).hue;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final currentColor = HSLColor.fromAHSL(1, hue, 1, 0.5).toColor();
            return AlertDialog(
              title: const Text('自定义主题色'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('色相', style: Theme.of(ctx).textTheme.bodySmall),
                  Slider(
                    value: hue,
                    min: 0,
                    max: 360,
                    divisions: 360,
                    activeColor: currentColor,
                    onChanged: (v) {
                      setDialogState(() {
                        hue = v;
                        pickedColor = HSLColor.fromAHSL(1, hue, 1, 0.5).toColor();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '#${pickedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _themeManager.setAccentColor(pickedColor);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('显示'),
            Card(
              child: Column(
                children: [
                  RadioListTile<ThemeModeType>(
                    title: const Text('跟随系统'),
                    value: ThemeModeType.auto,
                    groupValue: _themeManager.currentThemeMode,
                    activeColor: _themeManager.accentColor,
                    onChanged: (v) { if (v != null) _themeManager.setThemeMode(v); },
                  ),
                  const Divider(height: 1),
                  RadioListTile<ThemeModeType>(
                    title: const Text('浅色模式'),
                    value: ThemeModeType.light,
                    groupValue: _themeManager.currentThemeMode,
                    activeColor: _themeManager.accentColor,
                    onChanged: (v) { if (v != null) _themeManager.setThemeMode(v); },
                  ),
                  const Divider(height: 1),
                  RadioListTile<ThemeModeType>(
                    title: const Text('深色模式'),
                    value: ThemeModeType.dark,
                    groupValue: _themeManager.currentThemeMode,
                    activeColor: _themeManager.accentColor,
                    onChanged: (v) { if (v != null) _themeManager.setThemeMode(v); },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('纯黑暗色模式'),
                    subtitle: const Text('OLED 屏幕更省电，黑色更深邃'),
                    value: _themeManager.usePureBlack,
                    activeColor: _themeManager.accentColor,
                    onChanged: _themeManager.setUsePureBlack,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            _buildSectionTitle('主题'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('跟随系统主题色'),
                    subtitle: const Text('在 Android 12+ 上提取壁纸颜色'),
                    value: _themeManager.useDynamicColor,
                    activeColor: _themeManager.accentColor,
                    onChanged: _themeManager.setUseDynamicColor,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('自定义主题色', style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 12),
                        _buildColorGrid(),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showCustomColorDialog,
                            icon: const Icon(Icons.colorize, size: 18),
                            label: const Text('更多颜色...'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            _buildSectionTitle('通用'),

            Card(
              child: ListTile(
                leading: const Icon(Icons.info),
                title: const Text('关于应用'),
                subtitle: const Text('查看应用信息和版本'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AboutPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: ListTile(
                leading: const Icon(Icons.update),
                title: const Text('检查更新'),
                subtitle: _updateStatus.isNotEmpty
                    ? Text(
                        _updateStatus,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      )
                    : null,
                trailing: _isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _checkForUpdates,
                      ),
                onTap: _isChecking ? null : _checkForUpdates,
              ),
            ),
            const SizedBox(height: 16),
            if (_updateStatus.isNotEmpty && _updateStatus != '当前为最新版')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _updateStatus,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),

            const SizedBox(height: 16),
            _buildSectionTitle('数据'),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_sweep),
                    title: const Text('清除阅读历史'),
                    subtitle: const Text('删除所有阅读进度记录'),
                    onTap: _clearHistory,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cached),
                    title: const Text('清除图片缓存'),
                    subtitle: const Text('释放存储空间'),
                    trailing: Text(
                      _cacheSizeText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: _clearImageCache,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _cacheSizeText {
    final size = imageCache.currentSizeBytes;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除阅读历史'),
        content: const Text('确定要删除所有阅读进度记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ReadingProgressService().clearAllHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('阅读历史已清除')),
      );
    }
  }

  void _clearImageCache() {
    imageCache.clear();
    imageCache.clearLiveImages();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片缓存已清除')),
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildColorGrid() {
    final currentColor = _themeManager.accentColor;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presetColors.map((color) {
        final isSelected = color.value == currentColor.value;
        return GestureDetector(
          onTap: () => _themeManager.setAccentColor(color),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.5)
                  : Border.all(color: Colors.transparent, width: 2.5),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withAlpha(128), blurRadius: 6)]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check, color: _contrastText(color), size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Color _contrastText(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}
