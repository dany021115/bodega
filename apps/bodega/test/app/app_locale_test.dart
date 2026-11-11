// The language BodegaApp starts in with no choice saved: the system's ordered
// list, resolved over en and es by Flutter's default resolution, with no
// callback (L2). Flutter's own text, Material's and Cupertino's, follows it
// (L7). A choice in Settings applies at once, and the next start begins in it
// (L5).

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/graphics/graphics_bloc.dart';
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/locale/locale_bloc.dart';
import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/bloc/theme/theme_bloc.dart';
import 'package:bodega/app/bloc/update/update_bloc.dart';
import 'package:bodega/app/bloc/view_mode/view_mode_bloc.dart';
import 'package:bodega/app/presentation/setup/setup_page.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:bodega/di.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:bodega/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSetup extends MockBloc<SetupEvent, SetupState>
    implements SetupBloc {}

class _MockTheme extends MockBloc<ThemeEvent, ThemeState>
    implements ThemeBloc {}

class _MockUpdate extends MockBloc<UpdateEvent, UpdateState>
    implements UpdateBloc {}

class _MockBackends extends MockBloc<BackendsEvent, BackendsState>
    implements BackendsBloc {}

class _MockBottles extends MockBloc<BottlesEvent, BottlesState>
    implements BottlesBloc {}

class _MockCatalog extends MockBloc<CatalogEvent, CatalogState>
    implements CatalogBloc {}

class _MockGraphics extends MockBloc<GraphicsEvent, GraphicsState>
    implements GraphicsBloc {}

class _MockInstall extends MockBloc<InstallEvent, InstallState>
    implements InstallBloc {}

class _MockLibrary extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

class _MockViewMode extends MockBloc<ViewModeEvent, ViewModeState>
    implements ViewModeBloc {}

class _MockSections extends MockBloc<SectionsEvent, SectionsState>
    implements SectionsBloc {}

class _MockPreferences extends Mock implements Preferences {}

void main() {
  final en = lookupAppL10n(const Locale('en'));
  final es = lookupAppL10n(const Locale('es'));
  late _MockPreferences preferences;

  setUp(() {
    // No choice saved, unless a test says otherwise before the app starts.
    preferences = _MockPreferences();
    when(() => preferences.getLanguage()).thenReturn(null);
    when(() => preferences.saveLanguage(any())).thenAnswer((_) async {});
    // Without the engine the app stops at the setup page, which reads only
    // this bloc: the app's own text, and Flutter's, in one page.
    final setup = _MockSetup();
    whenListen(
      setup,
      const Stream<SetupState>.empty(),
      initialState: const SetupState(isChecking: false),
    );
    final theme = _MockTheme();
    whenListen(
      theme,
      const Stream<ThemeState>.empty(),
      initialState: const ThemeState(),
    );
    getIt
      ..registerSingleton<SetupBloc>(setup)
      ..registerSingleton<ThemeBloc>(theme)
      ..registerSingleton<UpdateBloc>(_MockUpdate())
      ..registerSingleton<BackendsBloc>(_MockBackends())
      ..registerSingleton<BottlesBloc>(_MockBottles())
      ..registerSingleton<CatalogBloc>(_MockCatalog())
      ..registerSingleton<GraphicsBloc>(_MockGraphics())
      ..registerSingleton<InstallBloc>(_MockInstall())
      ..registerSingleton<LibraryBloc>(_MockLibrary())
      ..registerSingleton<ViewModeBloc>(_MockViewMode())
      ..registerSingleton<SectionsBloc>(_MockSections())
      // The real bloc, built when the app asks for it: it reads the saved
      // choice in its constructor.
      ..registerLazySingleton<LocaleBloc>(() => LocaleBloc(preferences));
  });

  tearDown(getIt.reset);

  /// Starts the app on a system whose languages are [system], in its order,
  /// and gives the context of the page it opens.
  Future<BuildContext> start(WidgetTester tester, List<Locale> system) async {
    tester.platformDispatcher.localesTestValue = system;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const BodegaApp());
    await tester.pumpAndSettle();
    return tester.element(find.byType(SetupPage));
  }

  group('with no choice saved, the system list decides (L2)', () {
    for (final (system, language) in const [
      ([Locale('fr', 'FR'), Locale('es', 'ES')], Locale('es')),
      ([Locale('de', 'DE')], Locale('en')),
      ([Locale('en', 'GB'), Locale('es', 'ES')], Locale('en')),
      // Linux with LANG=C: the embedder passes g_get_language_names(), which
      // is ["C"], as one locale whose language code is C.
      ([Locale('C')], Locale('en')),
    ]) {
      testWidgets('$system gives $language', (tester) async {
        final context = await start(tester, system);
        expect(Localizations.localeOf(context), language);

        final shown = lookupAppL10n(language).setupTitle;
        final other = lookupAppL10n(
          Locale(language.languageCode == 'en' ? 'es' : 'en'),
        ).setupTitle;
        expect(find.text(shown), findsOneWidget);
        expect(find.text(other), findsNothing);
      });
    }
  });

  group("Flutter's own text follows the app's language (L7)", () {
    testWidgets('Spanish on a Spanish system', (tester) async {
      final context = await start(tester, const [Locale('es', 'ES')]);
      expect(MaterialLocalizations.of(context), isA<MaterialLocalizationEs>());
      expect(
        CupertinoLocalizations.of(context),
        isA<CupertinoLocalizationEs>(),
      );
    });

    testWidgets('English on an English system', (tester) async {
      final context = await start(tester, const [Locale('en', 'US')]);
      expect(MaterialLocalizations.of(context), isA<MaterialLocalizationEn>());
      expect(
        CupertinoLocalizations.of(context),
        isA<CupertinoLocalizationEn>(),
      );
    });
  });

  // The side bar's language menu sends these events (language_menu_test.dart);
  // the setup page has no side bar, so the test sends them to the app's bloc.
  group('a language choice applies at once and is kept (L5)', () {
    /// The language of the page the app shows.
    Locale shown(WidgetTester tester) =>
        Localizations.localeOf(tester.element(find.byType(SetupPage)));

    /// Picks [code] as the language menu does.
    void pick(String? code) => getIt<LocaleBloc>().add(LocaleEvent.set(code));

    testWidgets('Spanish switches the app', (tester) async {
      await start(tester, const [Locale('en', 'US')]);
      expect(find.text(en.setupTitle), findsOneWidget);

      pick('es');
      // No restart: the bloc's new state reaches the running app.
      await tester.pumpAndSettle();

      expect(shown(tester), const Locale('es'));
      expect(find.text(es.setupTitle), findsOneWidget);
      expect(find.text(en.setupTitle), findsNothing);
      verify(() => preferences.saveLanguage('es')).called(1);
    });

    testWidgets('a saved choice shows from the first frame', (tester) async {
      when(() => preferences.getLanguage()).thenReturn('es');
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const BodegaApp());

      expect(shown(tester), const Locale('es'));
      expect(find.text(es.setupTitle), findsOneWidget);
      expect(find.text(en.setupTitle), findsNothing);
    });

    testWidgets('System forgets the choice, and the system list decides', (
      tester,
    ) async {
      // A Spanish system, where the saved English wins.
      when(() => preferences.getLanguage()).thenReturn('en');
      await start(tester, const [Locale('es', 'ES')]);
      expect(shown(tester), const Locale('en'));

      pick(null);
      await tester.pumpAndSettle();

      expect(shown(tester), const Locale('es'));
      expect(find.text(es.setupTitle), findsOneWidget);
      verify(() => preferences.saveLanguage(null)).called(1);
    });
  });
}
