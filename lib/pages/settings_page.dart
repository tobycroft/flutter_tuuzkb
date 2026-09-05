import 'dart:async';
import 'package:flutter/material.dart';
import '../store/ws.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final WsStore ws = WsStore();
  final TextEditingController _vidController = TextEditingController(text: '05ac');
  final TextEditingController _pidController = TextEditingController(text: '0256');
  final TextEditingController _mfgrController = TextEditingController();
  final TextEditingController _prodController = TextEditingController();
  final TextEditingController _serialController = TextEditingController();
  Timer? _cfggetTimer;

  @override
  void initState() {
    super.initState();
    ws.subscribe(_onStateChange);
    // Sync initial values from store
    _vidController.text = ws.vid;
    _pidController.text = ws.pid;
    _mfgrController.text = ws.manufacturer;
    _prodController.text = ws.product;
    _serialController.text = ws.serial;
  }

  @override
  void dispose() {
    _cfggetTimer?.cancel();
    _vidController.dispose();
    _pidController.dispose();
    _mfgrController.dispose();
    _prodController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    setState(() {
      _vidController.text = ws.vid;
      _pidController.text = ws.pid;
      _mfgrController.text = ws.manufacturer;
      _prodController.text = ws.product;
      _serialController.text = ws.serial;
    });
  }

  void _cmd(String type) {
    ws.cmdFunc(type);
  }

  void _setPidVid() {
    final pidStr = _pidController.text.trim().toLowerCase();
    final vidStr = _vidController.text.trim().toLowerCase();
    if (pidStr.isEmpty || vidStr.isEmpty) {
      _showAlert('请输入 PID 和 VID');
      return;
    }
    final pid = int.tryParse(pidStr, radix: 16);
    final vid = int.tryParse(vidStr, radix: 16);
    if (pid == null || vid == null) {
      _showAlert('PID 和 VID 必须是十六进制数字');
      return;
    }
    ws.sendMessage({
      'route': 'kbd',
      'type': 'pidvid',
      'data': {'pid': pid, 'vid': vid}
    });
  }

  void _setUsbString() {
    final mfgr = _mfgrController.text.trim();
    final prod = _prodController.text.trim();
    final serial = _serialController.text.trim();
    if (mfgr.isEmpty && prod.isEmpty && serial.isEmpty) {
      _showAlert('请至少输入一个字段');
      return;
    }
    ws.sendMessage({
      'route': 'kbd',
      'type': 'setusbstr',
      'data': {'mfgr': mfgr, 'prod': prod, 'serial': serial}
    });
  }

  void _setPollingRate(int rate) {
    ws.pollingRate = rate;
    ws.sendMessage({
      'route': 'kbd',
      'type': 'polling_rate',
      'data': {'rate': rate}
    });
  }

  void _switchOutput(String name) {
    ws.currentOutput = name;
    ws.sendMessage({
      'route': 'semi-config',
      'type': 'switch_output',
      'data': {'name': name}
    });
    _cfggetTimer?.cancel();
    _cfggetTimer = Timer(Duration(seconds: 1), () {
      ws.requestInfoCfgGet();
      _cfggetTimer = null;
    });
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1C1C1E),
        title: Text('提示', style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.grey[300])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('确定', style: TextStyle(color: Color(0xFF3CC51F))),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D0D0D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection status
              _ConnectionBanner(
                message: ws.connectionMessage,
                color: _getStatusColor(),
              ),
              SizedBox(height: 12),

              // Output switcher
              _SectionTitle('输出切换'),
              if (ws.outputs.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ws.outputs.map((dev) {
                    final selected = ws.currentOutput == dev.name;
                    return ActionChip(
                      label: Text('输出 ${dev.name}'),
                      backgroundColor: selected ? Color(0xFF3CC51F) : Color(0xFF2C2C2E),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.grey[300],
                        fontSize: 12,
                      ),
                      onPressed: () => _switchOutput(dev.name),
                    );
                  }).toList(),
                ),
                SizedBox(height: 12),
              ],

              // Mask control
              _SectionTitle('屏蔽控制'),
              _BtnRow([
                _ActionButton(label: '屏蔽键', onTap: () => _cmd('bankey')),
                _ActionButton(label: '解除屏蔽', onTap: () => _cmd('unbanall')),
                _MacButton(
                  isActive: ws.macmode,
                  onTap: () => _cmd('toggle_macmode'),
                ),
              ]),
              SizedBox(height: 12),

              // Masked keys
              if (ws.maskButton.isNotEmpty) ...[
                _MaskPanel(keys: ws.maskButton),
                SizedBox(height: 12),
              ],

              // Device info
              _SectionTitle('设备信息'),
              _CompactInfo(vid: ws.vid, pid: ws.pid, baud: ws.baud),
              SizedBox(height: 6),
              _CompactLcd(lcd1: ws.lcd1, lcd2: ws.lcd2),
              SizedBox(height: 12),

              // Polling rate
              _SectionTitle('回报率'),
              _BtnRow([
                _PollingButton(rate: 1, current: ws.pollingRate, onTap: _setPollingRate),
                _PollingButton(rate: 2, current: ws.pollingRate, onTap: _setPollingRate),
                _PollingButton(rate: 8, current: ws.pollingRate, onTap: _setPollingRate),
              ]),
              SizedBox(height: 12),

              // System controls
              _SectionTitle('系统'),
              _BtnRow([
                _ActionButton(label: '重启', onTap: () => _cmd('reset')),
                _ActionButton(label: '获取 cfg', onTap: () => ws.requestInfoCfgGet()),
                _ActionButton(label: '重置', onTap: () => _cmd('setting_reset')),
              ]),
              SizedBox(height: 6),
              _BtnRow([
                _ActionButton(label: 'USBStr', onTap: () => _cmd('setusb')),
              ]),
              SizedBox(height: 12),

              // VID/PID input
              _SectionTitle('VID / PID'),
              Row(
                children: [
                  Expanded(
                    child: _StyledTextField(
                      controller: _vidController,
                      placeholder: 'VID (如 05ac)',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _StyledTextField(
                      controller: _pidController,
                      placeholder: 'PID (如 0256)',
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _setPidVid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3CC51F),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('设置', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ],
              ),
              SizedBox(height: 12),

              // USB strings
              _SectionTitle('USB 字符串'),
              _StyledTextField(
                controller: _mfgrController,
                placeholder: '制造商',
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _StyledTextField(
                      controller: _prodController,
                      placeholder: '产品',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _StyledTextField(
                      controller: _serialController,
                      placeholder: '序列号',
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _setUsbString,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3CC51F),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('设置', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
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
}

class _ConnectionBanner extends StatelessWidget {
  final String message;
  final Color color;
  const _ConnectionBanner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
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
      padding: EdgeInsets.only(left: 4, top: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }
}

class _BtnRow extends StatelessWidget {
  final List<Widget> children;
  const _BtnRow(this.children);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children.map((c) => Expanded(child: c)).toList(),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF2C2C2E),
          foregroundColor: Colors.grey[300],
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _MacButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _MacButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? Color(0xFF3CC51F) : Color(0xFF2C2C2E),
          foregroundColor: isActive ? Colors.white : Colors.grey[500],
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text('Mac', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _PollingButton extends StatelessWidget {
  final int rate;
  final int current;
  final Function(int) onTap;
  const _PollingButton({required this.rate, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = current == rate;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3),
      child: ElevatedButton(
        onPressed: () => onTap(rate),
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? Color(0xFF3CC51F) : Color(0xFF2C2C2E),
          foregroundColor: selected ? Colors.white : Colors.grey[400],
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text('$rate ms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF2C2C2E),
        border: Border.all(color: Color(0xFF3A3A3C)),
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
        SizedBox(height: 2),
        Text(value, style: TextStyle(
          color: Colors.grey[200],
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: 'Courier New',
        )),
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
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border.all(color: Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LcdCell(label: 'LCD1', text: lcd1),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('|', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: _LcdCell(label: 'LCD2', text: lcd2),
          ),
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
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Color(0xFF1A3A1A)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: TextStyle(color: Color(0xFF7CFC00), fontSize: 12, fontFamily: 'Courier New'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MaskPanel extends StatelessWidget {
  final List<HidKeyInfo> keys;
  const _MaskPanel({required this.keys});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border.all(color: Color(0xFF3A3A3C)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('屏蔽状态', style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keys.map((k) => Chip(
              label: Text(k.display, style: TextStyle(fontSize: 11, color: Colors.white)),
              backgroundColor: Color(0xFF8B0000),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  const _StyledTextField({required this.controller, required this.placeholder});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Colors.grey[200], fontFamily: 'Courier New', fontSize: 13),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF3A3A3C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF3A3A3C)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF3CC51F)),
        ),
        filled: true,
        fillColor: Color(0xFF2C2C2E),
      ),
    );
  }
}
