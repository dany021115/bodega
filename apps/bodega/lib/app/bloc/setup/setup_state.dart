part of 'setup_bloc.dart';

@freezed
abstract class SetupState with _$SetupState {
  const SetupState._();

  const factory SetupState({
    @Default(true) bool isChecking,
    @Default(false) bool isInstalling,
    @Default(false) bool rosetta,
    @Default(false) bool runtime,
    String? engine,
    String? hostlibs,
    AppError? error,
  }) = _SetupState;

  bool get isReady => rosetta && runtime;
}
