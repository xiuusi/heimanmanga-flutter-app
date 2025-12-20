import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'about_page.dart';
import '../services/api_service.dart';
import '../services/dio_service.dart';

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

          // 简单版本比较（移除可能的'v'前缀）
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
            // 关于应用卡片
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

            // 检查更新卡片
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