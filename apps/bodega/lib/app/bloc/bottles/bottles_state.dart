part of 'bottles_bloc.dart';

@freezed
abstract class BottlesState with _$BottlesState {
  const factory BottlesState({
    @Default(true) bool isLoading,
    @Default([]) List<Bottle> bottles,
    AppError? error,
  }) = _BottlesState;
}
