import 'package:bloc/bloc.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'view_mode_event.dart';
part 'view_mode_state.dart';
part 'view_mode_bloc.freezed.dart';

/// Whether the library shows a grid or a list. Kept between runs.
@lazySingleton
class ViewModeBloc extends Bloc<ViewModeEvent, ViewModeState> {
  final Preferences _preferences;

  ViewModeBloc(this._preferences)
    : super(ViewModeState(isGrid: _preferences.getLibraryViewGrid() ?? true)) {
    on<ViewModeToggleEvent>((event, emit) => _set(!state.isGrid, emit));
    on<ViewModeSetEvent>((event, emit) => _set(event.isGrid, emit));
  }

  Future<void> _set(bool isGrid, Emitter<ViewModeState> emit) async {
    await _preferences.saveLibraryViewGrid(isGrid);
    emit(state.copyWith(isGrid: isGrid));
  }
}
