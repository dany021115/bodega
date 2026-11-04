import 'package:bloc/bloc.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'sections_event.dart';
part 'sections_state.dart';
part 'sections_bloc.freezed.dart';

/// Which sections of a bottle's column are folded, the same for every bottle.
@injectable
class SectionsBloc extends Bloc<SectionsEvent, SectionsState> {
  final Preferences preferences;

  SectionsBloc(this.preferences)
    : super(
        SectionsState(collapsed: preferences.getCollapsedSections().toSet()),
      ) {
    on<SectionsToggleEvent>((event, emit) async {
      final collapsed = {...state.collapsed};
      if (!collapsed.remove(event.id)) collapsed.add(event.id);
      emit(state.copyWith(collapsed: collapsed));
      await preferences.saveCollapsedSections(collapsed.toList());
    });
  }
}
