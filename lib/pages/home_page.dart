import 'dart:async';

import 'package:flutter/material.dart';

import '../store/ws.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final WsStore ws = WsStore();
  Timer? _cfggetTimer;

  @override
  void initState() {
    super.initState();
    ws.subscribe(_onStateChange);
  }

  @override
  void dispose() {
    _cfggetTimer?.cancel();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  void _switchOutput(String name) {
    ws.currentOutput = name;
    ws.sendMessage({
      'route': 'semi-config',
      'type': 'switch_output',
      'data': {'name': name},
    });
    _cfggetTimer?.cancel();
    _cfggetTimer = Timer(Duration(seconds: 1), () {
      ws.requestInfoCfgGet();
      _cfggetTimer = null;
    });
  }

  Map<String, dynamic> _getSnapshot() {
    return {
      'Endpoint_BeforeDelay_Random': ws.endpointBeforeDelayRandom,
      'Endpoint_BeforeDelay': ws.endpointBeforeDelay,
      'Endpoint_delay': ws.endpointDelay,
      'Endpoint_dynamic_mode': ws.endpointDynamicMode,
      'Mode': ws.mode,
    };
  }

  void _onSliderChange(String field, int value) {
    switch (field) {
      case 'random':
        ws.setEndpointBeforeDelayRandom(value);
        break;
      case 'beforeDelay':
        ws.setEndpointBeforeDelay(value);
        break;
      case 'delay':
        ws.setEndpointDelay(value);
        break;
    }
    final snap = _getSnapshot();
    snap[field] = value;
    ws.requestSemiConfig(field, snap);
  }

  void _setMode(int mode) {
    ws.setMode(mode);
    ws.requestSemiConfig('Mode', _getSnapshot());
  }

  void _setEndpointMode(int mode) {
    ws.setEndpointDynamicMode(mode);
    ws.requestSemiConfig('Endpoint_dynamic_mode', _getSnapshot());
  }

  Color _getStatusColor() {
    switch (ws.connectionClass) {
      case 'status-success':
        return Colors.green[700]!;
      case 'status-progress':
        return Colors.blue[700]!;
      default:
        return Colors.red[700]!;
    }
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

              // Output switcher + compact info
              _OutputAndInfoPanel(
                outputs: ws.outputs,
                currentOutput: ws.currentOutput,
                vid: ws.vid,
                pid: ws.pid,
                baud: ws.baud,
                macmode: ws.macmode,
                onSwitchOutput: _switchOutput,
                onTapMac: () => ws.cmdFunc('toggle_macmode'),
              ),
              SizedBox(height: 12),

              // Mask panel
              if (ws.maskButton.isNotEmpty) ...[
                _MaskPanel(keys: ws.maskButton),
                SizedBox(height: 12),
              ],

              // Sliders
              _SlidersPanel(
                randomValue: ws.endpointBeforeDelayRandom,
                beforeValue: ws.endpointBeforeDelay,
                delayValue: ws.endpointDelay,
                onRandomChange: (v) => _onSliderChange('random', v),
                onBeforeChange: (v) => _onSliderChange('beforeDelay', v),
                onDelayChange: (v) => _onSliderChange('delay', v),
              ),
              SizedBox(height: 12),

              // Bottom bar: mode buttons
              _BottomBar(
                mode: ws.mode,
                endpointMode: ws.endpointDynamicMode,
                onModeChange: _setMode,
                onEndpointChange: _setEndpointMode,
              ),
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
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OutputAndInfoPanel extends StatelessWidget {
  final List<OutputDevice> outputs;
  final String currentOutput;
  final String vid;
  final String pid;
  final int baud;
  final bool macmode;
  final Function(String) onSwitchOutput;
  final VoidCallback onTapMac;

  const _OutputAndInfoPanel({
    required this.outputs,
    required this.currentOutput,
    required this.vid,
    required this.pid,
    required this.baud,
    required this.macmode,
    required this.onSwitchOutput,
    required this.onTapMac,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border.all(color: Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Output switcher
            if (outputs.isNotEmpty)
              Expanded(
                child: Row(
                  children: outputs.map((dev) {
                    final selected = currentOutput == dev.name;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: outputs.last == dev ? 0 : 6,
                        ),
                        child: ElevatedButton(
                          onPressed: () => onSwitchOutput(dev.name),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selected
                                ? Color(0xFF3CC51F)
                                : Color(0xFF2C2C2E),
                            foregroundColor: selected
                                ? Colors.white
                                : Color(0xFFDDDDDD),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: selected
                                    ? Color(0xFF3CC51F)
                                    : Color(0xFF3A3A3C),
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            '输出 ${dev.name}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            SizedBox(width: 10),
            // Compact info
            Expanded(
              child: GestureDetector(
                onTap: onTapMac,
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: macmode ? Color(0xFF2A3A2A) : Color(0xFF2C2C2E),
                    border: Border.all(
                      color: macmode ? Color(0xFF3CC51F) : Color(0xFF3A3A3C),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _InfoItem(
                        label: 'VID',
                        value: vid.isNotEmpty ? vid : '—',
                      ),
                      _InfoItem(
                        label: 'PID',
                        value: pid.isNotEmpty ? pid : '—',
                      ),
                      _InfoItem(label: 'Baud', value: baud > 0 ? '$baud' : '—'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF888888),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: Color(0xFFE0E0E0),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Courier New',
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
          Text(
            '屏蔽状态',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keys
                .map(
                  (k) => Chip(
                    label: Text(
                      k.display,
                      style: TextStyle(fontSize: 11, color: Colors.white),
                    ),
                    backgroundColor: Color(0xFF8B0000),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white70,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SlidersPanel extends StatelessWidget {
  final int randomValue;
  final int beforeValue;
  final int delayValue;
  final Function(int) onRandomChange;
  final Function(int) onBeforeChange;
  final Function(int) onDelayChange;

  const _SlidersPanel({
    required this.randomValue,
    required this.beforeValue,
    required this.delayValue,
    required this.onRandomChange,
    required this.onBeforeChange,
    required this.onDelayChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border.all(color: Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SliderRow(
            label: '前置震动',
            value: randomValue,
            min: 0,
            max: 30,
            onChanged: onRandomChange,
          ),
          SizedBox(height: 10),
          _SliderRow(
            label: '前置时间',
            value: beforeValue,
            min: 0,
            max: 50,
            onChanged: onBeforeChange,
          ),
          SizedBox(height: 10),
          _SliderRow(
            label: '操作间隔',
            value: delayValue,
            min: 0,
            max: 200,
            onChanged: onDelayChange,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final Function(int) onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$label: $value',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
            Text(
              '$value',
              style: TextStyle(
                color: Color(0xFF3CC51F),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          activeColor: Color(0xFF3CC51F),
          inactiveColor: Colors.grey[700],
          divisions: max - min,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int mode;
  final int endpointMode;
  final Function(int) onModeChange;
  final Function(int) onEndpointChange;

  const _BottomBar({
    required this.mode,
    required this.endpointMode,
    required this.onModeChange,
    required this.onEndpointChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trigger mode
        Text(
          '触发模式',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Row(
          children: [
            _ModeButton(
              label: '关闭',
              selected: mode == 0,
              color: Color(0xFF3CC51F),
              onTap: () => onModeChange(0),
            ),
            SizedBox(width: 6),
            _ModeButton(
              label: 'On-Q',
              selected: mode == 1,
              color: Color(0xFF3CC51F),
              onTap: () => onModeChange(1),
            ),
            SizedBox(width: 6),
            _ModeButton(
              label: 'On-Whel',
              selected: mode == 2,
              color: Color(0xFF3CC51F),
              onTap: () => onModeChange(2),
            ),
          ],
        ),
        SizedBox(height: 12),

        // Endpoint mode
        Text(
          '键盘模式',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Row(
          children: [
            _ModeButton(
              label: 'Ste',
              selected: endpointMode == 0,
              onTap: () => onEndpointChange(0),
            ),
            SizedBox(width: 6),
            _ModeButton(
              label: 'Dym',
              selected: endpointMode == 1,
              onTap: () => onEndpointChange(1),
            ),
            SizedBox(width: 6),
            _ModeButton(
              label: 'Wde',
              selected: endpointMode == 2,
              onTap: () => onEndpointChange(2),
            ),
            SizedBox(width: 6),
            _ModeButton(
              label: 'Ato',
              selected: endpointMode == 3,
              onTap: () => onEndpointChange(3),
            ),
            SizedBox(width: 6),
            _ModeButton(
              label: 'Atw',
              selected: endpointMode == 4,
              onTap: () => onEndpointChange(4),
            ),
            SizedBox(width: 6),
            _ModeButton(
              label: 'Man',
              selected: endpointMode == 5,
              onTap: () => onEndpointChange(5),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  static const _accentColor = Color(0xFF3CC51F);

  const _ModeButton({
    required this.label,
    required this.selected,
    this.color = _accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? color : Color(0xFF2C2C2E),
          foregroundColor: selected ? Colors.white : Colors.grey[400],
          padding: EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
