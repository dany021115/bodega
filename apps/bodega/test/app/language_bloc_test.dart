import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/language/language_bloc.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPreferences extends Mock implements Preferences {}

void main() {
  late _MockPreferences preferences;

  setUp(() {
    preferences = _MockPreferences();
    when(() => preferences.getLanguage()).thenReturn(null);
    when(() => preferences.saveLanguage(any())).thenAnswer((_) async {});
  });

  test('follows the system by default', () {
    expect(LanguageBloc(preferences).state.code, isNull);
  });

  test('starts with the saved language', () {
    when(() => preferences.getLanguage()).thenReturn('es');
    expect(LanguageBloc(preferences).state.code, 'es');
  });

  blocTest<LanguageBloc, LanguageState>(
    'set saves the language and emits it',
    build: () => LanguageBloc(preferences),
    act: (bloc) => bloc.add(const LanguageEvent.set('en')),
    expect: () => [const LanguageState(code: 'en')],
    verify: (_) => verify(() => preferences.saveLanguage('en')).called(1),
  );

  blocTest<LanguageBloc, LanguageState>(
    'null goes back to the system',
    build: () => LanguageBloc(preferences),
    seed: () => const LanguageState(code: 'es'),
    act: (bloc) => bloc.add(const LanguageEvent.set(null)),
    expect: () => [const LanguageState()],
    verify: (_) => verify(() => preferences.saveLanguage(null)).called(1),
  );
}
