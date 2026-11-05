import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/repository/install_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'install_event.dart';
part 'install_state.dart';
part 'install_bloc.freezed.dart';

@lazySingleton
class InstallBloc extends Bloc<InstallEvent, InstallState> {
  final InstallRepository _repository;

  InstallBloc(this._repository) : super(const InstallState()) {
    on<InstallStartEvent>(_start);
    on<InstallCancelEvent>((event, emit) {
      if (state.phase == InstallPhase.downloading) {
        _repository.cancelDownload();
      }
    });
    on<InstallDismissEvent>((event, emit) {
      if (!state.isRunning) emit(const InstallState());
    });
    on<InstallRemoveBottleEvent>((event, emit) async {
      final app = state.app;
      if (app == null || !state.bottleLeft) return;
      final result = await _repository.removeBottle(app.id);
      result.match(
        (error) => emit(state.copyWith(error: error)),
        (_) => emit(const InstallState()),
      );
    });
  }

  Future<void> _start(
    InstallStartEvent event,
    Emitter<InstallState> emit,
  ) async {
    if (state.isRunning) return;
    final app = event.app;
    final existing = event.bottle;
    emit(
      InstallState(
        phase: InstallPhase.downloading,
        app: app,
        bottle: existing ?? app.id,
      ),
    );

    final String? setup;
    if (event.setup case final local?) {
      setup = local;
    } else {
      // Progress arrives per chunk; one state per percent is enough.
      var shown = -1;
      final download = await _repository.download(app.id, (received, total) {
        final mark = total == null ? received >> 20 : received * 100 ~/ total;
        if (mark == shown) return;
        shown = mark;
        emit(state.copyWith(received: received, total: total));
      }, intoExisting: existing != null);
      final failed = download.getLeft().toNullable();
      if (failed != null) {
        return emit(state.copyWith(phase: InstallPhase.failed, error: failed));
      }
      setup = download.getRight().toNullable();
      if (setup == null) return emit(const InstallState());
    }

    emit(state.copyWith(phase: InstallPhase.installing));
    final result = await _repository.install(
      app.id,
      setup,
      (step) => emit(state.copyWith(step: step)),
      bottle: existing,
    );
    result.match(
      (error) => emit(
        state.copyWith(
          phase: InstallPhase.failed,
          error: error,
          // Only a bottle of its own, which download() made sure was new: an
          // existing one has other things in it.
          bottleLeft: existing == null && _repository.bottleExists(app.id),
        ),
      ),
      (_) => emit(state.copyWith(phase: InstallPhase.done)),
    );
  }
}
