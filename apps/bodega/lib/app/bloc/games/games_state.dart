part of 'games_bloc.dart';

/// A rating chip of the Games page: one per [GameRating], and games no one
/// reported.
enum RatingFilter { works, playable, broken, blocked, none }

@freezed
abstract class GamesState with _$GamesState {
  const GamesState._();

  const factory GamesState({
    @Default(true) bool isLoading,
    @Default([]) List<GameConfig> games,
    @Default('') String query,
    RatingFilter? rating,
    String? backend,
    AppError? error,
  }) = _GamesState;

  String get _text => query.trim().toLowerCase();

  List<GameConfig> get visibleGames => [
    for (final game in games)
      if (game.title.toLowerCase().contains(_text) &&
          (rating == null ||
              (rating == RatingFilter.none
                  ? game.rating == null
                  : game.rating?.name == rating!.name)) &&
          (backend == null || game.backend == backend))
        game,
  ];
}
