import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../store/ws.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final WsStore ws = WsStore();
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ws.subscribe(_onStateChange);
    _loadSavedIp();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('config_ip') ?? '';
    if (ip.isNotEmpty && mounted) {
      setState(() {
        _ipController.text = ip;
      });
    }
  }

  String _resolveWsAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains('://')) return trimmed;
    if (trimmed.startsWith('/')) {
      // In Flutter, we can't get the current host, so we'll use a placeholder
      // or assume the user enters a full URL
      return 'ws://$trimmed';
    }
    return 'ws://$trimmed';
  }

  void _saveConfiguration() async {
    if (_ipController.text.isEmpty) {
      _showAlert('请输入有效的地址');
      return;
    }
    final resolvedIp = _resolveWsAddress(_ipController.text);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('config_ip', resolvedIp);
    setState(() {
      _ipController.text = resolvedIp;
    });
    _showAlert('设置已保存');
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text('提示', style: const TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.grey[300])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定', style: TextStyle(color: Color(0xFF3CC51F))),
          )
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (ws.connectionClass) {
      case 'status-success': return Colors.green[700]!;
      case 'status-progress': return Colors.blue[700]!;
      default: return Colors.red[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection status
              _ConnectionBanner(
                message: ws.connectionMessage,
                color: _getStatusColor(),
              ),
              const SizedBox(height: 12),

              // Reconnect button
              ElevatedButton(
                onPressed: () => ws.reconnect(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3CC51F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '重新连接',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Device info
              _DeviceInfoPanel(
                vid: ws.vid,
                pid: ws.pid,
                baud: ws.baud,
                lcd1: ws.lcd1,
                lcd2: ws.lcd2,
              ),
              const SizedBox(height: 12),

              // Server address
              _SectionTitle('服务器地址'),
              TextField(
                controller: _ipController,
                style: const TextStyle(
                  color: Colors.grey,
                  fontFamily: 'Courier New',
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: '请输入 ws 开头的 URL 地址',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3A3A3C)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3A3A3C)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3CC51F)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2E),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _saveConfiguration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3CC51F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '保存地址',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final String message;
  final Color color;
  const _ConnectionBanner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFBBBBBB),
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DeviceInfoPanel extends StatelessWidget {
  final String vid;
  final String pid;
  final int baud;
  final String lcd1;
  final String lcd2;

  const _DeviceInfoPanel({
    required this.vid,
    required this.pid,
    required this.baud,
    required this.lcd1,
    required this.lcd2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompactInfo(vid: vid, pid: pid, baud: baud),
          const SizedBox(height: 12),
          _CompactLcd(lcd1: lcd1, lcd2: lcd2),
        ],
      ),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  final String vid;
  final String pid;
  final int baud;
  const _CompactInfo({required this.vid, required this.pid, required this.baud});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        border: Border.all(color: const Color(0xFF3A3A3C)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoItem(label: 'VID', value: vid.isNotEmpty ? vid : '—'),
          _InfoItem(label: 'PID', value: pid.isNotEmpty ? pid : '—'),
          _InfoItem(label: 'Baud', value: baud > 0 ? '$baud' : '—'),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Courier New',
          ),
        ),
      ],
    );
  }
}

class _CompactLcd extends StatelessWidget {
  final String lcd1;
  final String lcd2;
  const _CompactLcd({required this.lcd1, required this.lcd2});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: _LcdCell(label: 'LCD1', text: lcd1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '|',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(child: _LcdCell(label: 'LCD2', text: lcd2)),
        ],
      ),
    );
  }
}

class _LcdCell extends StatelessWidget {
  final String label;
  final String text;
  const _LcdCell({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: const Color(0xFF1A3A1A)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7CFC00),
              fontSize: 12,
              fontFamily: 'Courier New',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
