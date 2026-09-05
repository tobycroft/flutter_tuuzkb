import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_tuuzkb/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const TuuzKBApp());
    await tester.pump();

    // Verify bottom navigation bar is present
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('硬件控制'), findsOneWidget);
    expect(find.text('连接控制'), findsOneWidget);
  });
}
