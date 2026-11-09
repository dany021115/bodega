import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/view_mode/view_mode_bloc.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPreferences extends Mock implements Preferences {}

void main() {
  late _MockPreferences preferences;

  setUp(() {
    preferences = _MockPreferences();
    when(() => preferences.getLibraryViewGrid()).thenReturn(null);
    when(() => preferences.saveLibraryViewGrid(any())).thenAnswer((_) async {});
  });

  test('starts as a grid when nothing was saved', () {
    expect(ViewModeBloc(preferences).state.isGrid, isTrue);
  });

  test('starts as the saved view', () {
    when(() => preferences.getLibraryViewGrid()).thenReturn(false);
    expect(ViewModeBloc(preferences).state.isGrid, isFalse);
  });

  blocTest<ViewModeBloc, ViewModeState>(
    'toggle switches the view and saves it',
    build: () => ViewModeBloc(preferences),
    act: (bloc) => bloc.add(const ViewModeEvent.toggle()),
    expect: () => [const ViewModeState(isGrid: false)],
    verify: (_) =>
        verify(() => preferences.saveLibraryViewGrid(false)).called(1),
  );

  blocTest<ViewModeBloc, ViewModeState>(
    'set saves the given view',
    build: () => ViewModeBloc(preferences),
    act: (bloc) => bloc.add(const ViewModeEvent.set(false)),
    expect: () => [const ViewModeState(isGrid: false)],
    verify: (_) =>
        verify(() => preferences.saveLibraryViewGrid(false)).called(1),
  );
}
