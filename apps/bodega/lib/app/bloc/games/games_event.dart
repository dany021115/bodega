part of 'games_bloc.dart';

@freezed
sealed class GamesEvent with _$GamesEvent {
  const factory GamesEvent.load() = GamesLoadEvent;
  const factory GamesEvent.search(String query) = GamesSearchEvent;
  const factory GamesEvent.rating(RatingFilter rating) = GamesRatingEvent;
  const factory GamesEvent.backend(String backend) = GamesBackendEvent;
}
