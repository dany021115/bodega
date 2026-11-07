part of 'bottle_detail_bloc.dart';

@freezed
abstract class BottleDetailState with _$BottleDetailState {
  const factory BottleDetailState({
    @Default(true) bool isLoading,
    @Default(false) bool isBusy,
    @Default(false) bool deleted,

    /// The new name, once a rename has succeeded.
    String? renamedTo,
    BottleDetail? detail,
    String? logPath,
    @Default([]) List<String> logLines,
    AppError? error,
  }) = _BottleDetailState;
}
