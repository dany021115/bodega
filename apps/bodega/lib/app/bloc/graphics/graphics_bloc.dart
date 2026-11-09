import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/domain/repository/backend_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'graphics_event.dart';
part 'graphics_state.dart';
part 'graphics_bloc.freezed.dart';

/// What the apps' exes draw with, read once each (design §2).
@lazySingleton
class GraphicsBloc extends Bloc<GraphicsEvent, GraphicsState> {
  final BackendRepository _repository;

  /// Asked already, read or not: builds ask again while a read is running.
  final _asked = <String>{};

  GraphicsBloc(this._repository) : super(const GraphicsState()) {
    on<GraphicsLoadEvent>(_load);
  }

  Future<void> _load(
    GraphicsLoadEvent event,
    Emitter<GraphicsState> emit,
  ) async {
    // Steam's games all start steam.exe: what it draws with says nothing of
    // the game.
    final exes = {
      for (final exe in event.exes)
        if (!exe.toLowerCase().endsWith('steam.exe') &&
            _asked.add(GraphicsState.keyOf(event.bottle, exe)))
          exe,
    }.toList();
    if (exes.isEmpty) return;
    final result = await _repository.graphics(event.bottle, exes);
    // ponytail: a failed read is not retried this session; the app just shows
    // no label for it.
    final found = result.getOrElse((_) => const {});
    emit(
      state.copyWith(
        byKey: {
          ...state.byKey,
          for (final exe in exes)
            GraphicsState.keyOf(event.bottle, exe): found[exe],
        },
      ),
    );
  }
}
