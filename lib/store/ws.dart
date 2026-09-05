import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HID按键名称映射表（与Vue版本一致）
final Map<String, String> hidKeyNameMap = {
  '04': 'A', '05': 'B', '06': 'C', '07': 'D', '08': 'E', '09': 'F', '0A': 'G',
  '0B': 'H', '0C': 'I', '0D': 'J', '0E': 'K', '0F': 'L', '10': 'M', '11': 'N',
  '12': 'O', '13': 'P', '14': 'Q', '15': 'R', '16': 'S', '17': 'T', '18': 'U',
  '19': 'V', '1A': 'W', '1B': 'X', '1C': 'Y', '1D': 'Z',
  '1E': '1', '1F': '2', '20': '3', '21': '4', '22': '5',
  '23': '6', '24': '7', '25': '8', '26': '9', '27': '0',
  '28': 'Enter', '29': 'ESC', '2A': 'Backspace', '2B': 'Tab', '2C': 'Space',
  '2D': '-', '2E': '=', '2F': '[', '30': ']',
  '31': '\\', '32': '#', '33': ';', '34': "'",
  '35': '`', '36': ',', '37': '.', '38': '/',
  '39': 'Caps Lock',
  '3A': 'F1', '3B': 'F2', '3C': 'F3', '3D': 'F4', '3E': 'F5', '3F': 'F6',
  '40': 'F7', '41': 'F8', '42': 'F9', '43': 'F10', '44': 'F11', '45': 'F12',
  '46': 'PrintScreen', '47': 'ScrollLock', '48': 'Pause',
  '49': 'Insert', '4A': 'Home', '4B': 'PgUp', '4C': 'Delete',
  '4D': 'End', '4E': 'PgDn', '4F': 'Right', '50': 'Left', '51': 'Down', '52': 'Up',
  '53': 'NumLock',
  '54': 'Num/', '55': 'Num*', '56': 'Num-', '57': 'Num+',
  '58': 'NumEnter', '59': 'Num1', '5A': 'Num2',
  '5B': 'Num3', '5C': 'Num4', '5D': 'Num5',
  '5E': 'Num6', '5F': 'Num7', '60': 'Num8',
  '61': 'Num9', '62': 'Num0', '63': 'Num.',
  '64': 'Keycode45', '65': 'APP',
  '85': 'Keycode107', '87': 'Keycode56', '88': 'J133', '89': 'Keycode14',
  '8A': 'J132', '8B': 'J131', '90': 'Hangul', '91': 'Hanja',
  'E0': 'LCtrl', 'E1': 'LShift', 'E2': 'LAlt', 'E3': 'LWin',
  'E4': 'RCtrl', 'E5': 'RShift', 'E6': 'RAlt', 'E7': 'RWin',
};

class HidKeyInfo {
  final String hex;
  final String name;
  final String display;
  HidKeyInfo({required this.hex, required this.name, required this.display});
}

class OutputDevice {
  final String name;
  OutputDevice({required this.name});
}

typedef VoidCallback = void Function();

class WsStore {
  static final WsStore _instance = WsStore._internal();
  factory WsStore() => _instance;
  WsStore._internal();

  // Connection
  WebSocketChannel? _channel;
  bool _connected = false;
  Timer? _heartbeatTimer;
  String _connectionMessage = '未连接';
  String _connectionClass = 'status-failed';

  // Device state
  List<HidKeyInfo> _maskButton = [];
  String _pid = '';
  String _vid = '';
  int _baud = 0;
  int _endpointBeforeDelayRandom = 0;
  int _endpointBeforeDelay = 0;
  int _endpointDelay = 0;
  int _endpointDynamicMode = 0;
  String _lcd1 = '';
  String _lcd2 = '';
  int _mode = 0;
  bool _macmode = false;
  int _pollingRate = 1;
  String _currentOutput = '';
  List<OutputDevice> _outputs = [];
  String _manufacturer = '';
  String _product = '';
  String _serial = '';

  final List<VoidCallback> _listeners = [];

  // Getters
  String get connectionMessage => _connectionMessage;
  String get connectionClass => _connectionClass;
  List<HidKeyInfo> get maskButton => _maskButton;
  String get pid => _pid;
  String get vid => _vid;
  int get baud => _baud;
  int get endpointBeforeDelayRandom => _endpointBeforeDelayRandom;
  int get endpointBeforeDelay => _endpointBeforeDelay;
  int get endpointDelay => _endpointDelay;
  int get endpointDynamicMode => _endpointDynamicMode;
  String get lcd1 => _lcd1;
  String get lcd2 => _lcd2;
  int get mode => _mode;
  bool get macmode => _macmode;
  int get pollingRate => _pollingRate;
  String get currentOutput => _currentOutput;
  List<OutputDevice> get outputs => _outputs;
  String get manufacturer => _manufacturer;
  String get product => _product;
  String get serial => _serial;
  bool get isConnected => _connected;

  String getKeyName(String code) {
    if (code.isEmpty) return '';
    final key = code.toUpperCase().padLeft(2, '0');
    return hidKeyNameMap[key] ?? key;
  }

  List<HidKeyInfo> parseKeyList(List<String> arr) {
    if (arr.isEmpty) return [];
    return arr.map((c) {
      final name = getKeyName(c);
      final hex = c.toUpperCase().padLeft(2, '0');
      final display = name == hex ? hex : '$name ($hex)';
      return HidKeyInfo(hex: hex, name: name, display: display);
    }).toList();
  }

  List<OutputDevice> _sortOutputs(List<OutputDevice> arr) {
    return [...arr]..sort((a, b) {
      final na = _extractNum(a.name);
      final nb = _extractNum(b.name);
      if (na != nb) return na.compareTo(nb);
      return a.name.compareTo(b.name);
    });
  }

  int _extractNum(String name) {
    final match = RegExp(r'(\d+)').firstMatch(name);
    return match != null ? int.parse(match.group(1)!) : 999999;
  }

  void connectWebSocket(String url) {
    if (_connected) return;

    _connectionMessage = '连接中……';
    _connectionClass = 'status-progress';
    _notifyListeners();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _connected = true;
    } catch (e) {
      _connectionMessage = '连接失败';
      _connectionClass = 'status-failed';
      _connected = false;
      _notifyListeners();
      return;
    }

    _channel!.stream.listen(
      (event) {
        if (event == 'update') {
          requestInfo();
          return;
        }
        try {
          final data = _decodeJson(event);
          if (data != null) _updateFormData(data);
        } catch (e) {
          // ignore parse errors
        }
      },
      onDone: () {
        _connected = false;
        _channel = null;
        _connectionMessage = '连接被关闭';
        _connectionClass = 'status-failed';
        _stopHeartbeat();
        _notifyListeners();
      },
      onError: (e) {
        _connectionMessage = '连接错误';
        _connectionClass = 'status-failed';
        _notifyListeners();
      },
    );

    Future.delayed(Duration(milliseconds: 800)).then((_) {
      if (_connected) {
        _connectionMessage = '连接建立';
        _connectionClass = 'status-success';
        requestInfo();
        _startHeartbeat();
        _notifyListeners();
      }
    });
  }

  void disconnectWebSocket() {
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _stopHeartbeat();
    _connectionMessage = '未连接';
    _connectionClass = 'status-failed';
    _notifyListeners();
  }

  void sendMessage(Map<String, dynamic> msg) {
    if (_connected && _channel != null) {
      _channel!.sink.add(_encodeJson(msg));
    }
  }

  void cmdFunc(String type) {
    sendMessage({'route': 'kbd', 'type': type});
  }

  void requestInfo() {
    sendMessage({'route': 'info'});
  }

  void requestInfoCfgGet() {
    sendMessage({'route': 'infocfgget'});
  }

  void requestSemiConfig(String type, Map<String, dynamic> data) {
    sendMessage({'route': 'semi-config', 'type': type, 'data': data});
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 9), (_) {
      if (_connected) sendMessage({'route': 'ping'});
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> reconnect() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('config_ip') ?? '';
    if (ip.isNotEmpty) {
      connectWebSocket(ip);
    }
  }

  void _updateFormData(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null) continue;
      switch (key) {
        case 'connectionMessage':
          _connectionMessage = value as String;
          break;
        case 'connectionClass':
          _connectionClass = value as String;
          break;
        case 'MaskButton':
          _maskButton = parseKeyList((value as List).cast<String>());
          break;
        case 'pid': _pid = value.toString(); break;
        case 'vid': _vid = value.toString(); break;
        case 'baud': _baud = value as int; break;
        case 'Endpoint_BeforeDelay_Random': _endpointBeforeDelayRandom = value as int; break;
        case 'Endpoint_BeforeDelay': _endpointBeforeDelay = value as int; break;
        case 'Endpoint_delay': _endpointDelay = value as int; break;
        case 'Endpoint_dynamic_mode': _endpointDynamicMode = value as int; break;
        case 'LCD1': _lcd1 = value.toString(); break;
        case 'LCD2': _lcd2 = value.toString(); break;
        case 'Mode': _mode = value as int; break;
        case 'macmode': _macmode = value as bool; break;
        case 'polling_rate': _pollingRate = value as int; break;
        case 'currentOutput': _currentOutput = value.toString(); break;
        case 'outputs':
          final raw = value as List;
          _outputs = raw.map((e) => OutputDevice(name: e['name'] as String)).toList();
          _outputs = _sortOutputs(_outputs);
          break;
        case 'manufacturer': _manufacturer = value.toString(); break;
        case 'product': _product = value.toString(); break;
        case 'serial': _serial = value.toString(); break;
      }
    }
    _notifyListeners();
  }

  VoidCallback subscribe(VoidCallback cb) {
    _listeners.add(cb);
    return () => _listeners.remove(cb);
  }

  void _notifyListeners() {
    for (final cb in _listeners) {
      try { cb(); } catch (e) {}
    }
  }

  // JSON encode/decode
  String _encodeJson(Map<String, dynamic> map) {
    final sb = StringBuffer('{');
    var first = true;
    for (final entry in map.entries) {
      if (!first) sb.write(',');
      first = false;
      sb.write('"${_escStr(entry.key)}":${_encVal(entry.value)}');
    }
    sb.write('}');
    return sb.toString();
  }

  String _encVal(dynamic v) {
    if (v == null) return 'null';
    if (v is bool) return v ? 'true' : 'false';
    if (v is num) return v.toString();
    if (v is String) return '"${_escStr(v)}"';
    if (v is List) {
      final sb = StringBuffer('[');
      for (var i = 0; i < v.length; i++) {
        if (i > 0) sb.write(',');
        sb.write(_encVal(v[i]));
      }
      sb.write(']');
      return sb.toString();
    }
    return '"$v"';
  }

  String _escStr(String s) {
    return s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }

  Map<String, dynamic>? _decodeJson(String str) {
    try {
      return _SimpleDecoder().decode(str) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}

class _SimpleDecoder {
  int _pos = 0;
  String _src = '';

  dynamic decode(String src) {
    _src = src;
    _skipWs();
    return _parseVal();
  }

  void _skipWs() {
    while (_pos < _src.length && _src.codeUnitAt(_pos) <= 32) _pos++;
  }

  dynamic _parseVal() {
    _skipWs();
    if (_pos >= _src.length) return null;
    final c = _src[_pos];
    if (c == '{') return _parseObj();
    if (c == '[') return _parseArr();
    if (c == '"') return _parseStr();
    if (c == 't') { _pos += 4; return true; }
    if (c == 'f') { _pos += 5; return false; }
    if (c == 'n') { _pos += 4; return null; }
    return _parseNum();
  }

  Map<String, dynamic> _parseObj() {
    final result = <String, dynamic>{};
    _pos++;
    _skipWs();
    if (_pos < _src.length && _src[_pos] == '}') { _pos++; return result; }
    while (true) {
      _skipWs();
      final key = _parseStr() as String;
      _skipWs();
      _pos++;
      result[key] = _parseVal();
      _skipWs();
      if (_pos < _src.length && _src[_pos] == ',') { _pos++; continue; }
      break;
    }
    _pos++;
    return result;
  }

  List<dynamic> _parseArr() {
    final result = <dynamic>[];
    _pos++;
    _skipWs();
    if (_pos < _src.length && _src[_pos] == ']') { _pos++; return result; }
    while (true) {
      result.add(_parseVal());
      _skipWs();
      if (_pos < _src.length && _src[_pos] == ',') { _pos++; continue; }
      break;
    }
    _pos++;
    return result;
  }

  String _parseStr() {
    _pos++;
    final sb = StringBuffer();
    while (_pos < _src.length && _src[_pos] != '"') {
      if (_src[_pos] == '\\' && _pos + 1 < _src.length) {
        _pos++;
        switch (_src[_pos]) {
          case '"': sb.write('"'); break;
          case '\\': sb.write('\\'); break;
          case '/': sb.write('/'); break;
          case 'n': sb.write('\n'); break;
          case 't': sb.write('\t'); break;
          case 'r': sb.write('\r'); break;
          default: sb.write(_src[_pos]); break;
        }
      } else {
        sb.write(_src[_pos]);
      }
      _pos++;
    }
    _pos++;
    return sb.toString();
  }

  dynamic _parseNum() {
    int start = _pos;
    if (_src[_pos] == '-') _pos++;
    while (_pos < _src.length) {
      final u = _src.codeUnitAt(_pos);
      if (u >= 48 && u <= 57 || u == 46 || u == 101 || u == 69 || u == 43 || u == 45) {
        _pos++;
      } else {
        break;
      }
    }
    final s = _src.substring(start, _pos);
    return s.contains('.') ? double.parse(s) : int.parse(s);
  }
}
