import 'package:bodega/app/shared/widgets/side_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/catalog')) return 1;
    if (location.startsWith('/bottles')) return 2;
    if (location.startsWith('/backends')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final expanded = ResponsiveBreakpoints.of(context).largerOrEqualTo(DESKTOP);

    return Scaffold(
      body: Row(
        children: [
          SideBar(selectedIndex: _selectedIndex(context), expanded: expanded),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
