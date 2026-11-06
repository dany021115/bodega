part of 'setup_bloc.dart';

@freezed
abstract class SetupState with _$SetupState {
  const SetupState._();

  const factory SetupState({
    @Default(true) bool isChecking,
    @Default(false) bool isInstalling,
    @Default([]) List<HostIssue> issues,
    @Default(HostCapabilities()) HostCapabilities capabilities,
    @Default(false) bool runtime,
    String? engine,
    String? hostlibs,
    AppError? error,
  }) = _SetupState;

  bool get isReady => issues.isEmpty && runtime;
}
