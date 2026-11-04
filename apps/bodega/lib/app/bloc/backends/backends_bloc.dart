import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/repository/backend_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'backends_event.dart';
part 'backends_state.dart';
part 'backends_bloc.freezed.dart';

@lazySingleton
class BackendsBloc extends Bloc<BackendsEvent, BackendsState> {
  final BackendRepository _repository;

  BackendsBloc(this._repository) : super(const BackendsState()) {
    on<BackendsLoadEvent>((event, emit) async {
      emit(state.copyWith(error: null));
      await _load(emit);
    });
    on<BackendsDownloadEvent>((event, emit) async {
      if (state.busy != null) return;
      emit(
        state.copyWith(
          busy: event.name,
          isDownloading: true,
          received: 0,
          total: null,
          error: null,
        ),
      );
      var shown = -1;
      final result = await _repository.download(event.name, (received, total) {
        final mark = total == null ? received >> 20 : received * 100 ~/ total;
        if (mark == shown) return;
        shown = mark;
        emit(state.copyWith(received: received, total: total));
      });
      await _finish(result.map((_) => unit), emit);
    });
    on<BackendsCancelEvent>((event, emit) => _repository.cancelDownload());
    on<BackendsInstallFileEvent>((event, emit) async {
      if (state.busy != null) return;
      emit(
        state.copyWith(busy: event.name, received: 0, total: null, error: null),
      );
      await _finish(
        await _repository.installFile(event.name, event.tarball),
        emit,
      );
    });
    on<BackendsImportEvent>((event, emit) async {
      if (state.busy != null) return;
      emit(
        state.copyWith(busy: 'd3dmetal', received: 0, total: null, error: null),
      );
      await _finish(await _repository.importD3DMetal(event.folder), emit);
    });
    on<BackendsCheckEvent>((event, emit) async {
      if (state.busy != null || state.checking != null) return;
      emit(state.copyWith(checking: event.backend, error: null));
      final result = await _repository.check(event.bottle, event.backend);
      result.match(
        (error) => emit(state.copyWith(checking: null, error: error)),
        (results) => emit(
          state.copyWith(
            checking: null,
            results: {...state.results, event.backend: results},
          ),
        ),
      );
    });
  }

  Future<void> _finish(
    Either<AppError, Unit> result,
    Emitter<BackendsState> emit,
  ) async {
    result.match(
      (error) =>
          emit(state.copyWith(busy: null, isDownloading: false, error: error)),
      (_) => emit(state.copyWith(busy: null, isDownloading: false)),
    );
    await _load(emit);
  }

  Future<void> _load(Emitter<BackendsState> emit) async {
    final backends = await _repository.list();
    final bottles = await _repository.readyBottles();
    emit(
      state.copyWith(
        isLoading: false,
        backends: backends.getOrElse((_) => state.backends),
        bottles: bottles.getOrElse((_) => state.bottles),
        error:
            state.error ??
            backends.getLeft().toNullable() ??
            bottles.getLeft().toNullable(),
      ),
    );
  }
}
