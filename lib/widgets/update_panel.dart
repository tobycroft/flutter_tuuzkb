import 'package:flutter/material.dart';

import '../pages/update_dialog.dart';
import '../store/update.dart';

/// 软件更新面板：展示当前版本与更新状态，支持手动检查更新
class UpdatePanel extends StatefulWidget {
  const UpdatePanel({super.key});

  @override
  State<UpdatePanel> createState() => _UpdatePanelState();
}

class _UpdatePanelState extends State<UpdatePanel> {
  final UpdateStore update = UpdateStore();

  @override
  void initState() {
    super.initState();
    update.subscribe(_onStateChange);
    update.init();
  }

  @override
  void dispose() {
    update.unsubscribe(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _checkUpdate() async {
    final hasUpdate = await update.checkForUpdate();
    if (!mounted || !hasUpdate) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UpdateDialog(),
    );
  }

  String get _statusText {
    switch (update.status) {
      case UpdateStore.statusChecking:
        return '正在检查更新……';
      case UpdateStore.statusUpToDate:
        return '已是最新版本';
      case UpdateStore.statusAvailable:
        return '发现新版本 v${update.latestVersion}';
      case UpdateStore.statusDownloading:
        return '正在下载 ${(update.progress * 100).toStringAsFixed(0)}%';
      case UpdateStore.statusError:
        return update.errorMessage;
      default:
        return '点击"检查更新"获取最新版本';
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = update.status == UpdateStore.statusChecking ||
        update.status == UpdateStore.statusDownloading;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        border: Border.all(color: const Color(0xFF3A3A3C)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '当前版本',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(width: 12),
              Text(
                update.currentVersion.isEmpty
                    ? '未知'
                    : 'v${update.currentVersion}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Courier New',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _statusText,
            style: TextStyle(
              color: update.status == UpdateStore.statusError
                  ? const Color(0xFFFF6B6B)
                  : update.hasUpdate
                      ? const Color(0xFF3CC51F)
                      : Colors.grey[400],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: busy ? null : _checkUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CC51F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                busy ? '请稍候' : '检查更新',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
