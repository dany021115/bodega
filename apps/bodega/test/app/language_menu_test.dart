// The side bar's language item opens a short menu: System, from the ARBs, and
// the two languages by their own names, the same in both locales (L4). That a
// choice switches the running app and is kept is app_locale_test.dart's (L5).

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/locale/locale_bloc.dart';
import 'package:bodega/app/shared/widgets/language_menu.dart';
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

  /// The item at the foot of a side bar, with its menu open.
  Future<void> openMenu(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      BlocProvider<LocaleBloc>.value(
        value: language,
        child: wrapApp(
          const Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(width: 220, child: LanguageMenu(expanded: true)),
            ),
          ),
          locale: locale,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.translate_rounded));
    await tester.pumpAndSettle();
  }

  /// The menu entry named [name].
  Finder entry(String name) => find.widgetWithText(MenuItemButton, name);

  /// Whether the entry named [name] shows the check of the current choice.
  bool checked(WidgetTester tester, String name) => tester.any(
    find.descendant(
      of: entry(name),
      matching: find.byIcon(Icons.check_rounded),
    ),
  );

  for (final locale in const [Locale('en'), Locale('es')]) {
    final lang = '(${locale.languageCode})';

    testWidgets('three entries, the current one checked $lang', (tester) async {
      final l10n = lookupAppL10n(locale);
      expect(find.text(LanguageMenu.english), findsNothing);
      await openMenu(tester, locale: locale);

      expect(find.text(l10n.navLanguage), findsOneWidget);
      expect(find.byType(MenuItemButton), findsNWidgets(3));
      for (final name in [
        l10n.languageSystem,
        LanguageMenu.english,
        LanguageMenu.spanish,
      ]) {
        expect(entry(name).hitTestable(), findsOneWidget);
      }
      // No choice saved: System is the current one.
      expect(checked(tester, l10n.languageSystem), isTrue);
      expect(checked(tester, LanguageMenu.english), isFalse);
      expect(checked(tester, LanguageMenu.spanish), isFalse);
    });
  }

  testWidgets('a saved choice is the checked entry', (tester) async {
    final en = lookupAppL10n(const Locale('en'));
    choice('es');
    await openMenu(tester);
    expect(checked(tester, LanguageMenu.spanish), isTrue);
    expect(checked(tester, en.languageSystem), isFalse);
    expect(checked(tester, LanguageMenu.english), isFalse);
  });

  testWidgets('an entry sends its choice and closes the menu', (tester) async {
    await openMenu(tester);
    await tester.tap(entry(LanguageMenu.spanish));
    await tester.pumpAndSettle();
    verify(() => language.add(const LocaleEvent.set('es'))).called(1);
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testWidgets('System sends no language, to forget the choice', (tester) async {
    final en = lookupAppL10n(const Locale('en'));
    choice('en');
    await openMenu(tester);
    await tester.tap(entry(en.languageSystem));
    await tester.pumpAndSettle();
    verify(() => language.add(const LocaleEvent.set(null))).called(1);
  });

  testWidgets('the current entry sends nothing', (tester) async {
    choice('en');
    await openMenu(tester);
    await tester.tap(entry(LanguageMenu.english));
    await tester.pumpAndSettle();
    verifyNever(() => language.add(any()));
  });
}
