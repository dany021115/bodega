import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/anti_cheat_game.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:bodega/domain/repository/anti_cheat_repository.dart';
import 'package:bodega/domain/repository/backend_repository.dart';
import 'package:bodega/domain/repository/catalog_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'catalog_event.dart';
part 'catalog_state.dart';
part 'catalog_bloc.freezed.dart';

@lazySingleton
class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  final CatalogRepository _catalog;
  final AntiCheatRepository _antiCheat;
  final BackendRepository _backends;
  bool _askedAntiCheat = false;

  CatalogBloc(this._catalog, this._antiCheat, this._backends)
    : super(const CatalogState()) {
    on<CatalogLoadEvent>((event, emit) async {
      // A failed list gets one more try each time the catalog is opened.
      if (state.antiCheatError != null) _askedAntiCheat = false;
      final result = await _catalog.apps();
      final runtimes = await _backends.runtimes();
      final nativeUsable = runtimes
          .getOrElse((_) => const [])
          .any(
            (runtime) => runtime.kind == RuntimeKind.mach9 && runtime.usable,
          );
      result.match(
        (error) => emit(
          state.copyWith(
            isLoading: false,
            error: error,
            nativeUsable: nativeUsable,
          ),
        ),
        (apps) => emit(
          state.copyWith(
            isLoading: false,
            apps: apps,
            error: null,
            nativeUsable: nativeUsable,
          ),
        ),
      );
    });
    on<CatalogTargetEvent>(
      (event, emit) => emit(state.copyWith(targetBottle: event.bottle)),
    );
    on<CatalogSearchEvent>((event, emit) async {
      emit(state.copyWith(query: event.query));
      if (event.query.trim().length < CatalogState.minAntiCheatQuery ||
          _askedAntiCheat) {
        return;
      }
      _askedAntiCheat = true;
      final result = await _antiCheat.games();
      result.match(
        (error) => emit(state.copyWith(antiCheatError: error)),
        (games) => emit(state.copyWith(antiCheat: games, antiCheatError: null)),
      );
    });
  }
}
