import 'package:freezed_annotation/freezed_annotation.dart';

part 'path_problem.freezed.dart';

/// Why a path cannot be used: nothing is there, or Windows refuses it. The
/// engine's `PathProblem` and its missing files, which `data/` maps here.
@freezed
sealed class PathProblem with _$PathProblem {
  /// Nothing is at [path].
  const factory PathProblem.missing(String path) = PathMissingProblem;

  /// Windows refuses [part], a component of [path]: it ends in a dot or a
  /// space, or holds `<>:"|?*` (trap 11).
  const factory PathProblem.windowsName({
    required String part,
    required String path,
  }) = PathWindowsNameProblem;
}
