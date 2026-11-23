part of 'game_detail_bloc.dart';

@freezed
abstract class GameDetailState with _$GameDetailState {
  const factory GameDetailState({
    @Default(true) bool isLoading,
    GameConfig? game,
    AppError? error,
  }) = _GameDetailState;
}
