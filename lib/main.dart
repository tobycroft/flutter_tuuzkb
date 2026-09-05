import 'package:flutter/material.dart';
import 'package:flutter_tuuzkb/pages/connection_page.dart';
import 'package:flutter_tuuzkb/pages/home_page.dart';
import 'package:flutter_tuuzkb/pages/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TuuzKBApp());
}

class TuuzKBApp extends StatefulWidget {
  const TuuzKBApp({super.key});

  @override
  State<TuuzKBApp> createState() => _TuuzKBAppState();
}

class _TuuzKBAppState extends State<TuuzKBApp> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const SettingsPage(),
    const ConnectionPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Auto reconnect on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Reconnect will be handled by the pages themselves
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TUU ZKB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF3CC51F),
          surface: const Color(0xFF1C1C1E),
          onSurface: Colors.grey.shade300,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: _pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF1C1C1E),
          selectedItemColor: const Color(0xFF3CC51F),
          unselectedItemColor: Colors.grey[600],
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: '硬件控制',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sync_outlined),
              activeIcon: Icon(Icons.sync),
              label: '连接控制',
            ),
          ],
        ),
      ),
    );
  }
}
