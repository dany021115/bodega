import 'package:bodega/app/presentation/bottles/widgets/windows_user_dialog.dart';
import 'package:bodega/domain/entities/user_problem.dart';
import 'package:bodega/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<String?>> open(WidgetTester tester, String current) async {
    final chosen = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen.add(
              await showWindowsUserDialog(
                context,
                current: current,
                macUser: 'quasar',
                problem: (user) =>
                    user.contains('/') ? UserProblem.badCharacter : null,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
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
    expect(find.text('Use quasar'), findsNothing);
    expect(save(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'a/b');
    await tester.pump();
    expect(
      find.text('the name cannot contain " / \\ [ ] : ; | = , + * ? < >'),
      findsOneWidget,
    );
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
