import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle_step.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'new_bottle_event.dart';
part 'new_bottle_state.dart';
part 'new_bottle_bloc.freezed.dart';

/// The same rule the engine applies to a bottle's directory name.
final _validName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');

@injectable
class NewBottleBloc extends Bloc<NewBottleEvent, NewBottleState> {
  final BottleRepository _repository;

  NewBottleBloc(this._repository) : super(const NewBottleState()) {
    on<NewBottleLoadEvent>((event, emit) async {
      final result = await _repository.list();
      result.match(
        (error) => emit(state.copyWith(error: error)),
        (bottles) => emit(
          state.copyWith(taken: [for (final bottle in bottles) bottle.name]),
        ),
      );
    });
    on<NewBottleNameChangedEvent>(
      (event, emit) => emit(state.copyWith(name: event.name)),
    );
    on<NewBottleWindowsChangedEvent>(
      (event, emit) => emit(state.copyWith(windows: event.windows)),
    );
    on<NewBottleBackendChangedEvent>(
      (event, emit) => emit(state.copyWith(backend: event.backend)),
    );
    on<NewBottleRuntimeChangedEvent>(
      (event, emit) => emit(
        state.copyWith(
          runtime: event.runtime,
          runtimePicked: true,
          backend: 'auto',
        ),
      ),
    );
    on<NewBottleNativeAvailableEvent>((event, emit) {
      if (state.runtimePicked || state.isCreating) return;
      final runtime = event.available ? RuntimeKind.mach9 : RuntimeKind.bodega;
      if (runtime == state.runtime) return;
      emit(state.copyWith(runtime: runtime, backend: 'auto'));
    });
    on<NewBottleSubmitEvent>((event, emit) async {
      if (!state.canSubmit) return;
      final name = state.name;
      emit(
        state.copyWith(
          isCreating: true,
          step: null,
          monoFailed: false,
          error: null,
        ),
      );
      // A Rosetta bottle has one step, which the dialog shows by default.
      final result = state.runtime == RuntimeKind.bodega
          ? await _repository.create(
              name,
              windows: state.windows,
              backend: state.backend,
            )
          : await _repository.create(
              name,
              windows: state.windows,
              backend: state.backend,
              runtime: state.runtime,
              onStep: (step) => emit(state.copyWith(step: step)),
            );
      result.match(
        // Mono is the last step: when it fails, the bottle is made (MB5).
        (error) => state.step == BottleStep.mono
            ? emit(
                state.copyWith(
                  isCreating: false,
                  createdName: name,
                  monoFailed: true,
                  error: error,
                ),
              )
            : emit(state.copyWith(isCreating: false, error: error)),
        (_) => emit(state.copyWith(isCreating: false, createdName: name)),
      );
    });

    add(const NewBottleEvent.load());
  }
}
