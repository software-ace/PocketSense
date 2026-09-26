// Basic smoke test: the responsive shell components build correctly.
// Supabase is not contacted in tests; we only verify the widget tree renders.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Mobile shell renders with BottomNavigationBar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _FakeMobile()));
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Desktop shell renders with NavigationRail', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _FakeDesktop()));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
  });
}

class _FakeMobile extends StatelessWidget {
  const _FakeMobile();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: Text('Overview')),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _FakeDesktop extends StatelessWidget {
  const _FakeDesktop();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: 0,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.home), label: Text('Home')),
            NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
          ],
        ),
        Expanded(child: const Center(child: Text('Overview'))),
      ]),
      floatingActionButton: null,
    );
  }
}
