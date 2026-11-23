part of 'bottle_detail_bloc.dart';

@freezed
abstract class BottleDetailState with _$BottleDetailState {
  const factory BottleDetailState({
    @Default(true) bool isLoading,
    @Default(false) bool isBusy,
    @Default(false) bool deleted,

    /// Wine Mono is being installed (MB7).
    @Default(false) bool installingMono,

    /// What moving to the Native engine is doing; null when it is not (PA8).
    NativeMoveStep? moveStep,

    /// How many moves have ended well, so a page tells each once, and the
    /// runtimes the last one says to install again.
    @Default(0) int moves,
    @Default([]) List<String> reinstall,

    /// The new name, once a rename has succeeded.
    String? renamedTo,
    BottleDetail? detail,
    String? logPath,
    @Default([]) List<String> logLines,
    AppError? error,
  }) = _BottleDetailState;
}
