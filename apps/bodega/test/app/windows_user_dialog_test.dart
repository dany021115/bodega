import 'package:bodega/app/presentation/bottles/widgets/windows_user_dialog.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';

void main() {
  final en = lookupAppL10n(const Locale('en'));

  Future<List<String?>> open(WidgetTester tester, String current) async {
    final chosen = <String?>[];
    await tester.pumpWidget(
      wrapApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen.add(
              await showWindowsUserDialog(
                context,
                current: current,
                macUser: 'quasar',
                problem: (user) => user.contains('/') ? 'no slashes' : null,
              ),
            ),
            child: const Text('show'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    return chosen;
  }

  FilledButton save(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));

  testWidgets('checks the name while it is typed and saves it (U3, U5)', (
    tester,
  ) async {
    final chosen = await open(tester, '');
    expect(find.text('quasar'), findsOneWidget);
    expect(find.text(en.windowsUserUseHost('quasar')), findsNothing);
    expect(save(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'a/b');
    await tester.pump();
    expect(find.text('no slashes'), findsOneWidget);
    expect(save(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), ' Dany ');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(chosen, ['Dany']);
  });

  testWidgets('a bottle with its own name can go back to the host one', (
    tester,
  ) async {
    final chosen = await open(tester, 'Dany');
    await tester.tap(find.text('Use quasar'));
    await tester.pumpAndSettle();
    expect(chosen, ['']);
  });
}
