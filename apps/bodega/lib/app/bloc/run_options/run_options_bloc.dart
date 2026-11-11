import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/repository/library_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'run_options_event.dart';
part 'run_options_state.dart';
part 'run_options_bloc.freezed.dart';

/// `Ejecutar con opciones` (V11). It launches, and the dialog hands the log to
/// the library, which follows what is open.
@injectable
class RunOptionsBloc extends Bloc<RunOptionsEvent, RunOptionsState> {
  final LibraryRepository _repository;

  RunOptionsBloc(this._repository) : super(const RunOptionsState()) {
    on<RunOptionsStartEvent>(
      (event, emit) => emit(
        RunOptionsState(
          bottle: event.bottle,
          program: event.program,
          args: event.args,
          title: event.title,
        ),
      ),
    );
    on<RunOptionsChangedEvent>((event, emit) => emit(event.state));
    on<RunOptionsSubmitEvent>(_submit);
  }

  Future<void> _submit(
    RunOptionsSubmitEvent event,
    Emitter<RunOptionsState> emit,
  ) async {
    if (state.isRunning || state.program.trim().isEmpty) return;
    final env = parseEnv(state.env);
    if (env.isLeft()) {
      return emit(state.copyWith(error: env.getLeft().toNullable()));
    }
    final variables = env.getOrElse((_) => const {});
    final args = splitArgs(state.args);
    final program = state.program.trim();
    emit(state.copyWith(isRunning: true, error: null));

    if (state.save) {
      final saved = await _repository.saveLauncher(
        state.bottle,
        state.title.trim().isEmpty
            ? program.split(RegExp(r'[/\\]')).last
            : state.title.trim(),
        program,
        args: args,
        env: variables,
      );
      if (saved case Left(value: final error)) {
        return emit(state.copyWith(isRunning: false, error: error));
      }
    }

    final launched = await _repository.launch(
      state.bottle,
      program,
      args: args,
      env: variables,
      backend: state.backend,
      avx: state.avx,
    );
    launched.match(
      (error) => emit(state.copyWith(isRunning: false, error: error)),
      (log) => emit(state.copyWith(isRunning: false, log: log)),
    );
  }
}

/// `NAME=value`, one per line; blank lines are skipped.
Either<AppError, Map<String, String>> parseEnv(String text) {
  final env = <String, String>{};
  final name = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  for (final (index, raw) in text.split('\n').indexed) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final at = line.indexOf('=');
    if (at <= 0 || !name.hasMatch(line.substring(0, at))) {
      return left(AppError.badEnvLine(index + 1, line));
    }
    env[line.substring(0, at)] = line.substring(at + 1);
  }
  return right(env);
}

/// Arguments as a shell would split them, quotes included.
List<String> splitArgs(String text) => [
  for (final match in RegExp(r'"([^"]*)"|(\S+)').allMatches(text))
    match[1] ?? match[2]!,
];
