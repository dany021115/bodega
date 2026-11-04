import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPreferences extends Mock implements Preferences {}

void main() {
  late _MockPreferences preferences;

  setUp(() {
    preferences = _MockPreferences();
    when(() => preferences.getCollapsedSections()).thenReturn(const ['logs']);
    when(() => preferences.saveCollapsedSections(any()))
        .thenAnswer((_) async {});
  });

  test('remembers what was folded', () {
    expect(SectionsBloc(preferences).state.collapsed, {'logs'});
  });

  blocTest<SectionsBloc, SectionsState>(
    'toggling folds and unfolds, and saves it',
    build: () => SectionsBloc(preferences),
    act: (bloc) => bloc
      ..add(const SectionsEvent.toggle('actions'))
      ..add(const SectionsEvent.toggle('logs')),
    expect: () => const [
      SectionsState(collapsed: {'logs', 'actions'}),
      SectionsState(collapsed: {'actions'}),
    ],
    verify: (_) =>
        verify(() => preferences.saveCollapsedSections(const ['actions']))
            .called(1),
  );
}
