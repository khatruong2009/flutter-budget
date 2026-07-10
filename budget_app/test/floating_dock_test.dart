import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_app/widgets/floating_dock.dart';

const _items = [
  DockItem(icon: Icons.home_outlined, filledIcon: Icons.home, label: 'Home'),
  DockItem(
    icon: Icons.pie_chart_outline,
    filledIcon: Icons.pie_chart,
    label: 'Spend',
  ),
  DockItem(
    icon: Icons.settings_outlined,
    filledIcon: Icons.settings,
    label: 'More',
  ),
];

void main() {
  testWidgets('dragging across dock buttons selects each hovered tab',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DockHost()));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.home)),
    );
    await gesture.moveTo(
      tester.getCenter(find.byIcon(Icons.pie_chart_outline)),
    );
    await tester.pump();
    expect(_currentIndex(tester), 1);

    await gesture.moveTo(
      tester.getCenter(find.byIcon(Icons.settings_outlined)),
    );
    await tester.pump();
    expect(_currentIndex(tester), 2);
    await gesture.up();
  });

  testWidgets('a held finger can move through tabs after long press',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DockHost()));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.home)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(
      tester.getCenter(find.byIcon(Icons.pie_chart_outline)),
    );
    await tester.pump();
    expect(_currentIndex(tester), 1);

    await gesture.moveTo(
      tester.getCenter(find.byIcon(Icons.settings_outlined)),
    );
    await tester.pump();
    expect(_currentIndex(tester), 2);
    await gesture.up();
  });
}

int _currentIndex(WidgetTester tester) {
  return tester.widget<FloatingDock>(find.byType(FloatingDock)).currentIndex;
}

class _DockHost extends StatefulWidget {
  const _DockHost();

  @override
  State<_DockHost> createState() => _DockHostState();
}

class _DockHostState extends State<_DockHost> {
  var _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FloatingDock(
          items: _items,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          onDragSelect: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}
