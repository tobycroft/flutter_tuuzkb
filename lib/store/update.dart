import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 应用内自动更新
///
/// 启动时请求 GitHub 最新 Release，与当前安装版本比对；
/// 有新版本则下载 release 里的 app-release.apk，下载完成后调起系统安装器。
class UpdateStore {
  static final UpdateStore _instance = UpdateStore._internal();
  factory UpdateStore() => _instance;
  UpdateStore._internal();

  static const String _owner = 'tobycroft';
  static const String _repo = 'flutter_tuuzkb';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  static const String _apkUrl =
      'https://github.com/$_owner/$_repo/releases/latest/download/app-release.apk';
  static const String _releasesUrl = 'https://github.com/$_owner/$_repo/releases';
  static const String _apkName = 'app-release.apk';

  static const MethodChannel _channel = MethodChannel(
    'flutter_tuuzkb/installer',
  );

  // 更新状态
  static const String statusIdle = 'idle'; // 初始/未知
  static const String statusChecking = 'checking'; // 正在检查
  static const String statusUpToDate = 'upToDate'; // 已是最新
  static const String statusAvailable = 'available'; // 有新版本
  static const String statusDownloading = 'downloading'; // 正在下载
  static const String statusError = 'error'; // 出错

  String _status = statusIdle;
  String _currentVersion = '';
  String _latestVersion = '';
  String _apkDownloadUrl = '';
  String _errorMessage = '';
  double _progress = 0; // 0 ~ 1
  double _notifiedProgress = -1; // 进度通知节流用
  bool _cancelRequested = false;

  final List<void Function()> _listeners = [];

  // Getters
  String get status => _status;
  String get currentVersion => _currentVersion;
  String get latestVersion => _latestVersion;
  String get errorMessage => _errorMessage;
  double get progress => _progress;
  String get releasesUrl => _releasesUrl;
  bool get hasUpdate =>
      _status == statusAvailable || _status == statusDownloading;

  /// 读取当前安装的版本号（仅 Android，测试或桌面端直接跳过）
  Future<void> init() async {
    if (_currentVersion.isNotEmpty) return;
    if (!Platform.isAndroid) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;
    } catch (e) {
      _currentVersion = '';
    }
    _notifyListeners();
  }

  /// 检查更新，返回是否有新版本
  Future<bool> checkForUpdate() async {
    await init();
    if (!Platform.isAndroid) return false;
    _status = statusChecking;
    _errorMessage = '';
    _notifyListeners();
    try {
      final release = await _fetchLatestRelease();
      _latestVersion = release['version'] ?? '';
      _apkDownloadUrl = release['apkUrl'] ?? _apkUrl;
      if (_latestVersion.isEmpty) {
        _status = statusIdle;
        _notifyListeners();
        return false;
      }
      if (_isNewer(_latestVersion, _currentVersion)) {
        _status = statusAvailable;
        _notifyListeners();
        return true;
      }
      _status = statusUpToDate;
      _notifyListeners();
      return false;
    } catch (e) {
      _status = statusError;
      _errorMessage = '检查更新失败：$e';
      _notifyListeners();
      return false;
    }
  }

  /// 下载最新 APK，完成后自动调起系统安装器
  Future<void> startDownload() async {
    if (_status == statusDownloading) return;
    if (!Platform.isAndroid) return;
    _status = statusDownloading;
    _progress = 0;
    _notifiedProgress = -1;
    _cancelRequested = false;
    _errorMessage = '';
    _notifyListeners();
    try {
      final cacheDir = await _channel.invokeMethod<String>('getCacheDir');
      if (cacheDir == null || cacheDir.isEmpty) {
        throw '无法获取本地缓存目录';
      }
      final file = File('$cacheDir/apk/$_apkName');
      await file.parent.create(recursive: true);

      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(_apkDownloadUrl));
        request.headers.set(HttpHeaders.userAgentHeader, 'flutter_tuuzkb');
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw '下载失败 (HTTP ${response.statusCode})';
        }
        final total = response.contentLength;
        var received = 0;
        final sink = file.openWrite();
        await for (final chunk in response) {
          if (_cancelRequested) {
            await sink.close();
            if (await file.exists()) await file.delete();
            _status = statusAvailable;
            _notifyListeners();
            return;
          }
          received += chunk.length;
          sink.add(chunk);
          if (total > 0) {
            _progress = received / total;
            // 进度每变化 1% 才通知一次，避免频繁刷新
            if (_progress - _notifiedProgress >= 0.01) {
              _notifiedProgress = _progress;
              _notifyListeners();
            }
          }
        }
        await sink.flush();
        await sink.close();
      } finally {
        client.close(force: true);
      }
      await installApk(file.path);
    } catch (e) {
      _status = statusError;
      _errorMessage = '下载失败：$e';
      _notifyListeners();
    }
  }

  /// 取消正在进行的下载
  void cancelDownload() {
    if (_status != statusDownloading) return;
    _cancelRequested = true;
  }

  /// 调起系统安装器安装指定 APK
  Future<void> installApk(String path) async {
    try {
      await _channel.invokeMethod('installApk', {'path': path});
      _status = statusIdle;
    } on PlatformException catch (e) {
      _status = statusError;
      if (e.code == 'no_permission') {
        _errorMessage = '请先在系统设置中允许本应用"安装未知应用"，然后重试';
      } else {
        _errorMessage = '安装失败：${e.message ?? e.code}';
      }
    } on MissingPluginException {
      _status = statusError;
      _errorMessage = '当前平台不支持应用内安装';
    }
    _notifyListeners();
  }

  /// 请求 GitHub 最新 Release，返回 {'version': x.y.z, 'apkUrl': ...}
  Future<Map<String, String>> _fetchLatestRelease() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_apiUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'flutter_tuuzkb');
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw 'GitHub API 请求失败 (HTTP ${response.statusCode})';
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String?) ?? '';
      var apkUrl = '';
      final assets = (data['assets'] as List?) ?? const [];
      for (final asset in assets) {
        if (asset is Map && asset['name'] == _apkName) {
          apkUrl = (asset['browser_download_url'] as String?) ?? '';
          break;
        }
      }
      return {'version': _normalizeVersion(tagName), 'apkUrl': apkUrl};
    } finally {
      client.close(force: true);
    }
  }

  /// 去掉 tag 前缀的 'v'，统一成纯版本号
  static String _normalizeVersion(String tag) {
    final t = tag.trim();
    if (t.length > 1 && (t.startsWith('v') || t.startsWith('V'))) {
      return t.substring(1);
    }
    return t;
  }

  /// 比较语义化版本号，remote 是否比 current 新
  static bool _isNewer(String remote, String current) {
    final rv = _parseVersion(remote);
    final cv = _parseVersion(current);
    if (rv.isEmpty || cv.isEmpty) return false;
    for (var i = 0; i < 3; i++) {
      final a = i < rv.length ? rv[i] : 0;
      final b = i < cv.length ? cv[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  static List<int> _parseVersion(String version) {
    final v = _normalizeVersion(version).trim();
    if (v.isEmpty) return const [];
    final parts = v.split('.');
    final result = <int>[];
    for (final part in parts.take(3)) {
      result.add(int.tryParse(part) ?? 0);
    }
    return result;
  }

  void Function() subscribe(void Function() cb) {
    _listeners.add(cb);
    return () => _listeners.remove(cb);
  }

  void unsubscribe(void Function() cb) {
    _listeners.remove(cb);
  }

  void _notifyListeners() {
    for (final cb in List.of(_listeners)) {
      try {
        cb();
      } catch (e) {
        // 忽略单个监听器的异常，保证其他监听器正常收到通知
      }
    }
  }
}
