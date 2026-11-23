part of 'app_games_bloc.dart';

@freezed
sealed class AppGamesEvent with _$AppGamesEvent {
  const factory AppGamesEvent.load(String bottle) = AppGamesLoadEvent;
  const factory AppGamesEvent.setOn(String key, bool on) = AppGamesSetOnEvent;

  /// Saves the verdict and makes the form's URL, which the page opens.
  const factory AppGamesEvent.report(
    AppGame game,
    GameVerdict verdict,
    String note,
  ) = AppGamesReportEvent;
}
