import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/host_capabilities.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:bodega/domain/repository/runtime_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'setup_event.dart';
part 'setup_state.dart';
part 'setup_bloc.freezed.dart';

@lazySingleton
class SetupBloc extends Bloc<SetupEvent, SetupState> {
  final RuntimeRepository _runtime;

  SetupBloc(this._runtime) : super(const SetupState()) {
    on<SetupCheckEvent>((event, emit) async {
      emit(state.copyWith(isChecking: true, error: null));
      await _refresh(emit);
    });
    on<SetupEngineChosenEvent>(
      (event, emit) => emit(state.copyWith(engine: event.path, error: null)),
    );
    on<SetupHostlibsChosenEvent>(
      (event, emit) => emit(state.copyWith(hostlibs: event.path, error: null)),
    );
    on<SetupInstallEvent>((event, emit) async {
      final engine = state.engine, hostlibs = state.hostlibs;
      if (engine == null || hostlibs == null) return;
      emit(state.copyWith(isInstalling: true, error: null));
      final result = await _runtime.install(engine: engine, hostlibs: hostlibs);
      await result.match(
        (error) async =>
            emit(state.copyWith(isInstalling: false, error: error)),
        (_) async {
          emit(state.copyWith(isInstalling: false));
          await _refresh(emit);
        },
      );
    });
  }

  Future<void> _refresh(Emitter<SetupState> emit) async {
    final result = await _runtime.status();
    result.match(
      (error) => emit(state.copyWith(isChecking: false, error: error)),
      (status) => emit(
        state.copyWith(
          isChecking: false,
          issues: status.issues,
          capabilities: status.capabilities,
          runtime: status.runtime,
        ),
      ),
    );
  }
}
