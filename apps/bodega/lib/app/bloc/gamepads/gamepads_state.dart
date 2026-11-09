part of 'gamepads_bloc.dart';

@freezed
abstract class GamepadsState with _$GamepadsState {
  const factory GamepadsState({
    @Default(true) bool isLoading,

    /// Null where there is nothing to show, or until the first look.
    GamepadReport? report,
    AppError? error,
  }) = _GamepadsState;
}
