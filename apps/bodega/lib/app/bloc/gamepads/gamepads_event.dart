part of 'gamepads_bloc.dart';

@freezed
sealed class GamepadsEvent with _$GamepadsEvent {
  /// Looks again: a gamepad may have been plugged in or the rules installed.
  const factory GamepadsEvent.load() = GamepadsLoadEvent;
}
