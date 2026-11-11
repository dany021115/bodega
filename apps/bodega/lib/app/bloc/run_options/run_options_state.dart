part of 'run_options_bloc.dart';

@freezed
abstract class RunOptionsState with _$RunOptionsState {
  const factory RunOptionsState({
    @Default('') String bottle,
    @Default('') String program,
    @Default('') String args,

    /// `NAME=value`, one per line.
    @Default('') String env,

    /// Null keeps what the bottle would choose.
    String? backend,
    @Default(true) bool avx,
    @Default(false) bool save,
    @Default('') String title,
    @Default(false) bool isRunning,

    /// The log of the launch, once it started.
    String? log,
    AppError? error,
  }) = _RunOptionsState;
}
