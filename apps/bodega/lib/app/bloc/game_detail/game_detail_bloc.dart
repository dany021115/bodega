import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/domain/repository/game_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'game_detail_event.dart';
part 'game_detail_state.dart';
part 'game_detail_bloc.freezed.dart';

/// A game's page (A3).
@injectable
class GameDetailBloc extends Bloc<GameDetailEvent, GameDetailState> {
  final GameRepository _games;

  GameDetailBloc(this._games) : super(const GameDetailState()) {
    on<GameDetailLoadEvent>((event, emit) async {
      final result = await _games.game(event.id);
      result.match(
        (error) => emit(GameDetailState(isLoading: false, error: error)),
        (game) => emit(GameDetailState(isLoading: false, game: game)),
      );
    });
  }
}
