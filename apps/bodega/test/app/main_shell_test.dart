import 'package:bodega/app/bloc/theme/theme_bloc.dart';
import 'package:bodega/app/shared/widgets/main_shell.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:bodega/device/helpers/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:responsive_framework/responsive_framework.dart';

class _MockPreferences extends Mock implements Preferences {}

void main() {
  Future<void> pumpAt(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 700);
    addTearDown(tester.view.reset);

    final preferences = _MockPreferences();
    when(() => preferences.getDarkTheme()).thenReturn(null);

    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const SizedBox.expand()),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => ThemeBloc(preferences),
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: appBreakpoints,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('at 1000 px the sidebar shows text', (tester) async {
    await pumpAt(tester, 1000);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Backends'), findsOneWidget);
  });

  testWidgets('at 600 px it shows only icons', (tester) async {
    await pumpAt(tester, 600);
    expect(find.text('Biblioteca'), findsNothing);
    expect(find.byIcon(Icons.apps_rounded), findsOneWidget);
    expect(find.byIcon(Icons.memory_rounded), findsOneWidget);
  });
}
