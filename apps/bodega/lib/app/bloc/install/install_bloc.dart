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
    emit(InstallState(phase: InstallPhase.downloading, app: app));

    // Progress arrives per chunk; one state per percent is enough.
    var shown = -1;
    final download = await _repository.download(app.id, (received, total) {
      final mark = total == null ? received >> 20 : received * 100 ~/ total;
      if (mark == shown) return;
      shown = mark;
      emit(state.copyWith(received: received, total: total));
    });

    await download.match(
      (error) async =>
          emit(state.copyWith(phase: InstallPhase.failed, error: error)),
      (setup) async {
        if (setup == null) return emit(const InstallState());

        emit(state.copyWith(phase: InstallPhase.installing));
        final result = await _repository.install(
          app.id,
          setup,
          (step) => emit(state.copyWith(step: step)),
        );
        result.match(
          (error) => emit(
            state.copyWith(
              phase: InstallPhase.failed,
              error: error,
              // download() refused an existing bottle, so this one is ours.
              bottleLeft: _repository.bottleExists(app.id),
            ),
          ),
          (_) => emit(state.copyWith(phase: InstallPhase.done)),
        );
      },
    );
  }
}
