part of 'sections_bloc.dart';

@freezed
abstract class SectionsState with _$SectionsState {
  const factory SectionsState({@Default({}) Set<String> collapsed}) =
      _SectionsState;
}
