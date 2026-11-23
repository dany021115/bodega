part of 'app_games_bloc.dart';

@freezed
abstract class AppGamesState with _$AppGamesState {
  const factory AppGamesState({
    @Default('') String bottle,
    @Default(true) bool isLoading,
    @Default([]) List<AppGame> apps,
    AppError? error,

    /// The last report's form, for the page to open; [reportId] tells a new
    /// one from the same URL again.
    Uri? report,
    @Default(0) int reportId,
  }) = _AppGamesState;
}
