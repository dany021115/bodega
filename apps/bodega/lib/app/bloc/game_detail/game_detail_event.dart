part of 'game_detail_bloc.dart';

@freezed
sealed class GameDetailEvent with _$GameDetailEvent {
  const factory GameDetailEvent.load(String id) = GameDetailLoadEvent;
}
