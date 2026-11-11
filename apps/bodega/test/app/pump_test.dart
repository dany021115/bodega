import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/pump.dart';

/// Reads the ARBs, as every screen will.
class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => Text(context.l10n.commonCancel);
}

void main() {
  final en = lookupAppL10n(const Locale('en'));
  final es = lookupAppL10n(const Locale('es'));

  Locale localeOf(WidgetTester tester) =>
      Localizations.localeOf(tester.element(find.byType(_Probe)));

  // Left alone, Flutter would resolve this machine to Spanish.
  void spanishMachine(WidgetTester tester) {
    tester.platformDispatcher.localesTestValue = const [Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  testWidgets('wrapApp reads English on a Spanish machine, or the locale '
      'asked (N8)', (tester) async {
    spanishMachine(tester);

    await tester.pumpWidget(wrapApp(const _Probe()));
    expect(localeOf(tester), const Locale('en'));
    expect(find.text('Cancel'), findsOneWidget);

    await tester.pumpWidget(
      wrapApp(const _Probe(), locale: const Locale('es')),
    );
    expect(localeOf(tester), const Locale('es'));
    expect(find.text(es.commonCancel), findsOneWidget);
    expect(find.text(en.commonCancel), findsNothing);
  });

  testWidgets('wrapRouter pins the locale too (N8)', (tester) async {
    spanishMachine(tester);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const _Probe())],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(wrapRouter(router));
    expect(localeOf(tester), const Locale('en'));
    expect(find.text('Cancel'), findsOneWidget);

    await tester.pumpWidget(wrapRouter(router, locale: const Locale('es')));
    expect(localeOf(tester), const Locale('es'));
    expect(find.text(es.commonCancel), findsOneWidget);
  });

  testWidgets('a bare MaterialApp fails the assert, which names the helpers '
      '(N8)', (tester) async {
    // What tests pumped before pump.dart: Material's own delegates, without
    // AppL10n's. Torn off, so that N8's grep, which keeps every test on the
    // helpers, still lists only pump.dart.
    const bare = MaterialApp.new;
    await tester.pumpWidget(bare(home: const _Probe()));

    final error = tester.takeException();
    expect(error, isA<AssertionError>());
    expect('$error', allOf(contains('wrapApp'), contains('wrapRouter')));
  });
}
