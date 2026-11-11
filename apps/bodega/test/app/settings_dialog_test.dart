// The Settings dialog holds the language only: System, from the ARBs, and the
// two languages by their own names, the same in both locales (L4). That a
// choice switches the running app and is kept is app_locale_test.dart's (L5).

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/locale/locale_bloc.dart';
import 'package:bodega/app/presentation/settings/settings_dialog.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/pump.dart';

class _MockLocale extends MockBloc<LocaleEvent, LocaleState>
    implements LocaleBloc {}

void main() {
  late _MockLocale language;

  /// The language bloc, whose state has [code] as the choice.
  void choice(String? code) => whenListen(
    language,
    const Stream<LocaleState>.empty(),
    initialState: LocaleState(code: code),
  );

  setUpAll(() => registerFallbackValue(const LocaleEvent.set(null)));

  setUp(() {
    language = _MockLocale();
    choice(null);
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      BlocProvider<LocaleBloc>.value(
        value: language,
        child: wrapApp(const SettingsDialog(), locale: locale),
      ),
    );
  }

  /// The radio tile whose title is [name].
  Finder radio(String name) =>
      find.widgetWithText(RadioListTile<String?>, name);

  for (final locale in const [Locale('en'), Locale('es')]) {
    final lang = '(${locale.languageCode})';

    testWidgets('one Language section of three choices, and Close $lang', (
      tester,
    ) async {
      final l10n = lookupAppL10n(locale);
      await pumpDialog(tester, locale: locale);

      expect(find.text(l10n.navSettings), findsOneWidget);
      expect(
        tester.getSemantics(find.text(l10n.settingsLanguage)),
        isSemantics(label: l10n.settingsLanguage, isHeader: true),
      );
      expect(find.byType(RadioGroup<String?>), findsOneWidget);
      expect(find.byType(RadioListTile<String?>), findsNWidgets(3));
      // System is a word of the ARBs; the languages keep their own names.
      for (final name in [
        l10n.settingsLanguageSystem,
        SettingsDialog.english,
        SettingsDialog.spanish,
      ]) {
        expect(radio(name), findsOneWidget, reason: name);
      }
      expect(find.widgetWithText(TextButton, l10n.commonClose), findsOneWidget);
      // No theme switch: the light theme is not offered yet.
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
    });
  }

  group('the active choice is checked, in a group', () {
    final en = lookupAppL10n(const Locale('en'));
    final names = {
      null: en.settingsLanguageSystem,
      'en': SettingsDialog.english,
      'es': SettingsDialog.spanish,
    };

    for (final MapEntry(key: code, value: active) in names.entries) {
      testWidgets(active, (tester) async {
        choice(code);
        await pumpDialog(tester);
        for (final name in names.values) {
          expect(
            tester.getSemantics(radio(name)),
            isSemantics(
              label: name,
              hasCheckedState: true,
              isChecked: name == active,
              isInMutuallyExclusiveGroup: true,
            ),
            reason: name,
          );
        }
      });
    }
  });

  testWidgets('a language adds its code, and System adds null', (tester) async {
    final en = lookupAppL10n(const Locale('en'));
    choice('en');
    await pumpDialog(tester);

    await tester.tap(radio(SettingsDialog.spanish));
    await tester.pump();
    verify(() => language.add(const LocaleEvent.set('es'))).called(1);

    await tester.tap(radio(en.settingsLanguageSystem));
    await tester.pump();
    verify(() => language.add(const LocaleEvent.set(null))).called(1);

    // The active one is already the choice: it adds nothing.
    await tester.tap(radio(SettingsDialog.english));
    await tester.pump();
    verifyNever(() => language.add(const LocaleEvent.set('en')));
  });

  testWidgets('Close shuts it', (tester) async {
    final en = lookupAppL10n(const Locale('en'));
    await tester.pumpWidget(
      BlocProvider<LocaleBloc>.value(
        value: language,
        child: wrapApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDialog), findsOneWidget);

    await tester.tap(find.text(en.commonClose));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsDialog), findsNothing);
    verifyNever(() => language.add(any()));
  });
}
