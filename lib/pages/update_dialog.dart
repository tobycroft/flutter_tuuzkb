import 'package:flutter/material.dart';

import '../store/update.dart';

/// 应用内更新弹窗：展示版本信息、下载进度与安装状态
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdateStore update = UpdateStore();

  @override
  void initState() {
    super.initState();
    update.subscribe(_onStateChange);
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

  @override
  Widget build(BuildContext context) {
    final downloading = update.status == UpdateStore.statusDownloading;
    return AlertDialog(
      backgroundColor: Color(0xFF1C1C1E),
      title: Text(
        '发现新版本',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VersionRow(
            label: '当前版本',
            value: update.currentVersion.isEmpty ? '未知' : update.currentVersion,
          ),
          SizedBox(height: 4),
          _VersionRow(label: '最新版本', value: 'v${update.latestVersion}'),
          if (downloading) ...[
            SizedBox(height: 14),
            LinearProgressIndicator(
              value: update.progress > 0 ? update.progress : null,
              backgroundColor: Color(0xFF2C2C2E),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3CC51F)),
            ),
            SizedBox(height: 8),
            Text(
              update.progress > 0
                  ? '正在下载 ${(update.progress * 100).toStringAsFixed(0)}%'
                  : '正在下载……',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
          if (update.status == UpdateStore.statusError) ...[
            SizedBox(height: 14),
            Text(
              update.errorMessage,
              style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          // 下载中只允许取消下载，不关闭弹窗
          onPressed: downloading ? update.cancelDownload : () => _dismiss(),
          child: Text(
            downloading ? '取消' : '暂不更新',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        TextButton(
          // 下载中不允许重复触发
          onPressed: downloading ? null : () => _onAction(),
          child: Text(
            update.status == UpdateStore.statusError ? '重试' : '立即更新',
            style: TextStyle(color: Color(0xFF3CC51F)),
          ),
        ),
      ],
    );
  }

  void _onAction() {
    if (update.status == UpdateStore.statusError) {
      // 出错后重试：回到检查更新重新走一遍流程
      update.checkForUpdate().then((hasUpdate) {
        if (hasUpdate) update.startDownload();
      });
      return;
    }
    update.startDownload();
  }

  void _dismiss() {
    Navigator.of(context).pop();
  }
}

class _VersionRow extends StatelessWidget {
  final String label;
  final String value;
  const _VersionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            color: Colors.grey[200],
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Courier New',
          ),
        ),
      ],
    );
  }
}
