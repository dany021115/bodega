part of 'view_mode_bloc.dart';

@freezed
sealed class ViewModeEvent with _$ViewModeEvent {
  const factory ViewModeEvent.toggle() = ViewModeToggleEvent;
  const factory ViewModeEvent.set(bool isGrid) = ViewModeSetEvent;
}
