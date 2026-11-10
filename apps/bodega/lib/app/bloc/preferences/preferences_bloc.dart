import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/repository/storage_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'preferences_event.dart';
part 'preferences_state.dart';
part 'preferences_bloc.freezed.dart';

@injectable
class PreferencesBloc extends Bloc<PreferencesEvent, PreferencesState> {
  final StorageRepository repository;

  PreferencesBloc(this.repository) : super(const PreferencesState()) {
    on<PreferencesLoadEvent>((event, emit) async {
      emit(state.copyWith(dataFolder: repository.dataFolder, error: null));
      final result = await repository.downloadsSize();
      result.match(
        (error) => emit(state.copyWith(error: error)),
        (bytes) => emit(state.copyWith(cacheBytes: bytes)),
      );
    });
    on<PreferencesClearEvent>((event, emit) async {
      emit(state.copyWith(isClearing: true, error: null));
      final result = await repository.clearDownloads();
      result.match(
        (error) => emit(state.copyWith(isClearing: false, error: error)),
        (_) => emit(state.copyWith(isClearing: false, cacheBytes: 0)),
      );
    });
  }
}
