import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// L1: the app follows the system's language, and any language it doesn't
/// have gets English.
void main() {
  Future<String> cancelIn(WidgetTester tester, Locale system) async {
    tester.platformDispatcher.localesTestValue = [system];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) => Text(context.l10n.commonCancel)),
      ),
    );
    return tester.widget<Text>(find.byType(Text)).data!;
  }

  testWidgets('a Spanish system gets Spanish', (tester) async {
    expect(await cancelIn(tester, const Locale('es', 'ES')), 'Cancelar');
  });

  testWidgets('an English system gets English', (tester) async {
    expect(await cancelIn(tester, const Locale('en', 'GB')), 'Cancel');
  });

  testWidgets('any other language gets English', (tester) async {
    expect(await cancelIn(tester, const Locale('fr', 'FR')), 'Cancel');
  });
}
