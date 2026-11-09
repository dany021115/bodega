part of 'view_mode_bloc.dart';

@freezed
abstract class ViewModeState with _$ViewModeState {
  const factory ViewModeState({@Default(true) bool isGrid}) = _ViewModeState;
}
