import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/app_update.dart';
import 'package:bodega/domain/repository/update_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'update_event.dart';
part 'update_state.dart';
part 'update_bloc.freezed.dart';

/// A newer version of the app, and its install (A1–A4).
@lazySingleton
class UpdateBloc extends Bloc<UpdateEvent, UpdateState> {
  final UpdateRepository _repository;

  UpdateBloc(this._repository) : super(const UpdateState()) {
    on<UpdateCheckEvent>((event, emit) async {
      final update = (await _repository.check()).toNullable();
      if (update != null) emit(UpdateState(update: update));
    });
    on<UpdateSkipEvent>((event, emit) async {
      final update = state.update;
      if (update != null) await _repository.skip(update.version);
      emit(const UpdateState());
    });
    on<UpdateInstallEvent>(_install);
    on<UpdateCancelEvent>((event, emit) => _repository.cancel());
  }

  Future<void> _install(
    UpdateInstallEvent event,
    Emitter<UpdateState> emit,
  ) async {
    final update = state.update;
    if (update == null || !update.installable || state.isBusy) return;
    emit(
      state.copyWith(
        phase: UpdatePhase.downloading,
        received: 0,
        total: null,
        error: null,
      ),
    );
    var shown = -1;
    final downloaded = await _repository.download(update, (received, total) {
      // One emit per megabyte: a 447 MB dmg would flood the page.
      final mark = received >> 20;
      if (mark == shown) return;
      shown = mark;
      emit(state.copyWith(received: received, total: total));
    });
    // A3: a failure or a cancel leaves everything as it was.
    final file = downloaded.toNullable();
    if (file == null) {
      emit(
        state.copyWith(
          phase: UpdatePhase.available,
          error: downloaded.getLeft().toNullable(),
        ),
      );
      return;
    }
    emit(state.copyWith(phase: UpdatePhase.installing));
    (await _repository.install(file)).match(
      (error) =>
          emit(state.copyWith(phase: UpdatePhase.available, error: error)),
      (_) => _repository.quit(),
    );
  }
}
