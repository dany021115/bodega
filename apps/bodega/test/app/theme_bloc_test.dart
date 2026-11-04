import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/theme/theme_bloc.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPreferences extends Mock implements Preferences {}

void main() {
  late _MockPreferences preferences;

  setUp(() {
    preferences = _MockPreferences();
    when(() => preferences.getDarkTheme()).thenReturn(null);
    when(() => preferences.saveDarkTheme(any())).thenAnswer((_) async {});
  });

  test('starts dark', () {
    expect(ThemeBloc(preferences).state.isDark, isTrue);
  });

  blocTest<ThemeBloc, ThemeState>(
    'toggle changes the theme and saves it',
    build: () => ThemeBloc(preferences),
    act: (bloc) => bloc.add(const ThemeEvent.toggle()),
    expect: () => [const ThemeState(isDark: false)],
    verify: (_) => verify(() => preferences.saveDarkTheme(false)).called(1),
  );
}
