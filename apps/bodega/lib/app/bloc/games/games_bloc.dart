import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/domain/repository/game_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'games_event.dart';
part 'games_state.dart';
part 'games_bloc.freezed.dart';

/// The Games page (A2): every configuration, searched and filtered.
@injectable
class GamesBloc extends Bloc<GamesEvent, GamesState> {
  final GameRepository _games;

  GamesBloc(this._games) : super(const GamesState()) {
    on<GamesLoadEvent>((event, emit) async {
      final result = await _games.games();
      result.match(
        (error) => emit(state.copyWith(isLoading: false, error: error)),
        (games) =>
            emit(state.copyWith(isLoading: false, games: games, error: null)),
      );
    });
    on<GamesSearchEvent>(
      (event, emit) => emit(state.copyWith(query: event.query)),
    );
    // Tapping the chosen chip again clears it.
    on<GamesRatingEvent>(
      (event, emit) => emit(
        state.copyWith(
          rating: state.rating == event.rating ? null : event.rating,
        ),
      ),
    );
    on<GamesBackendEvent>(
      (event, emit) => emit(
        state.copyWith(
          backend: state.backend == event.backend ? null : event.backend,
        ),
      ),
    );
  }
}
