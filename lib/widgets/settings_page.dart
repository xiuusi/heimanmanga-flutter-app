import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isChecking = false;
  String _updateStatus = '';
  String? _latestVersion;
  String? _releaseUrl;

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _updateStatus = '';
    });

    try {
      // 动态获取应用版本信息
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 添加更明显的调试标识
      print('🎯🎯🎯 检查更新功能开始执行 🎯🎯🎯');
      print('📱 当前应用版本: $currentVersion');
      print('🌐 正在请求GitHub API...');

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/xiuusi/heimanmanga-flutter-app/releases'),
      );

      print('📡 GitHub API响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> releases = json.decode(response.body);
        print('📦 获取到 ${releases.length} 个发布版本');

        if (releases.isNotEmpty) {
          final latestRelease = releases.first;
          final latestVersion = latestRelease['tag_name'] as String;

          setState(() {
            _latestVersion = latestVersion;
            _releaseUrl = latestRelease['html_url'] as String;
          });

          // 输出详细的调试信息
          print('🔍 版本比较信息:');
          print('   📱 当前版本: $currentVersion');
          print('   🚀 GitHub最新版本: $latestVersion');

          // 简单版本比较（移除可能的'v'前缀）
          final currentVersionClean = currentVersion.replaceAll('v', '');
          final latestVersionClean = latestVersion.replaceAll('v', '');

          final bool hasUpdate = _isNewerVersion(latestVersionClean, currentVersionClean);
          print('   📊 版本比较结果:');
          print('      - 当前版本(清理后): $currentVersionClean');
          print('      - 最新版本(清理后): $latestVersionClean');
          print('      - 是否需要更新: ${hasUpdate ? "✅ 是" : "❌ 否"}');

          if (hasUpdate) {
            print('🎉 发现新版本！准备显示更新对话框');
            if (mounted) {
              _showUpdateDialog(context);
            }
          } else {
            print('👍 当前已是最新版本');
            setState(() {
              _updateStatus = '当前为最新版';
            });
          }
        } else {
          print('⚠️ GitHub releases为空，未找到发布版本');
          setState(() {
            _updateStatus = '未找到发布版本';
          });
        }
      } else {
        print('❌ GitHub API请求失败，状态码: ${response.statusCode}');
        setState(() {
          _updateStatus = '检查更新失败';
        });
      }
    } catch (e) {
      print('💥 检查更新异常: $e');
      setState(() {
        _updateStatus = '网络连接失败';
      });
    } finally {
      print('🏁 检查更新功能执行完成');
      print('🎯🎯🎯 检查更新功能结束 🎯🎯🎯');
      setState(() {
        _isChecking = false;
      });
    }
  }

  bool _isNewerVersion(String latest, String current) {
    // 简单的版本号比较，将版本号拆分为数字部分
    final latestParts = latest.split('.').map((part) {
      final match = RegExp(r'\d+').firstMatch(part);
      return match != null ? int.parse(match.group(0)!) : 0;
    }).toList();

    final currentParts = current.split('.').map((part) {
      final match = RegExp(r'\d+').firstMatch(part);
      return match != null ? int.parse(match.group(0)!) : 0;
    }).toList();

    // 比较每个部分
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          ],
        ),
      ),
    );
  }
}