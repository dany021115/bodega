// The language chosen in Settings: read when the bloc is built, so the first
// frame shows it, and saved under PreferenceKey.language, where no value means
// System (L5).

import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/locale/locale_bloc.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPreferences extends Mock implements Preferences {}

void main() {
  late _MockPreferences preferences;

  setUp(() {
    preferences = _MockPreferences();
    when(() => preferences.getLanguage()).thenReturn(null);
    when(() => preferences.saveLanguage(any())).thenAnswer((_) async {});
  });

  group('the first state is the saved choice, with no event', () {
    for (final (saved, code) in const [
      (null, null),
      ('es', 'es'),
      ('en', 'en'),
      // A language the app doesn't speak reads as System.
      ('fr', null),
      ('', null),
    ]) {
      blocTest<LocaleBloc, LocaleState>(
        'saved ${saved == null ? 'nothing' : '"$saved"'}: '
        '${code ?? 'System'}',
        setUp: () => when(() => preferences.getLanguage()).thenReturn(saved),
        build: () => LocaleBloc(preferences),
        expect: () => const <LocaleState>[],
        verify: (bloc) => expect(bloc.state, LocaleState(code: code)),
      );
    }
  });

  blocTest<LocaleBloc, LocaleState>(
    'a choice applies and is saved',
    build: () => LocaleBloc(preferences),
    act: (bloc) => bloc.add(const LocaleEvent.set('es')),
    expect: () => [const LocaleState(code: 'es')],
    verify: (_) => verify(() => preferences.saveLanguage('es')).called(1),
  );

  blocTest<LocaleBloc, LocaleState>(
    'System goes back to no choice, and removes the saved one',
    setUp: () => when(() => preferences.getLanguage()).thenReturn('es'),
    build: () => LocaleBloc(preferences),
    act: (bloc) => bloc.add(const LocaleEvent.set(null)),
    expect: () => [const LocaleState()],
    verify: (_) => verify(() => preferences.saveLanguage(null)).called(1),
  );

  blocTest<LocaleBloc, LocaleState>(
    'a language the app does not speak is System',
    setUp: () => when(() => preferences.getLanguage()).thenReturn('es'),
    build: () => LocaleBloc(preferences),
    act: (bloc) => bloc.add(const LocaleEvent.set('fr')),
    expect: () => [const LocaleState()],
    verify: (_) => verify(() => preferences.saveLanguage(null)).called(1),
  );

  // The real Preferences over the plugin's in-memory store: what the next
  // start reads.
  group('the saved choice', () {
    late SharedPreferences store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await SharedPreferences.getInstance();
    });

    test("is the next start's first state", () async {
      final bloc = LocaleBloc(Preferences(store))
        ..add(const LocaleEvent.set('es'));
      await bloc.close();

      expect(store.getString(PreferenceKey.language.name), 'es');
      expect(
        LocaleBloc(Preferences(store)).state,
        const LocaleState(code: 'es'),
      );
    });

    test('System removes the key, so the system decides again', () async {
      await store.setString(PreferenceKey.language.name, 'es');
      final bloc = LocaleBloc(Preferences(store))
        ..add(const LocaleEvent.set(null));
      await bloc.close();

      expect(store.containsKey(PreferenceKey.language.name), isFalse);
      expect(LocaleBloc(Preferences(store)).state, const LocaleState());
    });
  });
}
