import 'package:bodega/domain/entities/path_problem.dart';
import 'package:bodega/domain/entities/user_name_problem.dart';
import 'package:bodega/l10n/l10n.dart';

/// Why a name cannot be a bottle's Windows user (U3): under the name field of
/// the Windows user dialog, and as the reason of a refused name's error.
String userNameProblemText(AppL10n l10n, UserNameProblem problem) =>
    switch (problem) {
      UserNameProblem.empty => l10n.problemUserNameEmpty,
      UserNameProblem.tooLong => l10n.problemUserNameTooLong,
      UserNameProblem.badCharacter => l10n.problemUserNameBadCharacter,
      UserNameProblem.onlyDots => l10n.problemUserNameOnlyDots,
      UserNameProblem.taken => l10n.problemUserNameTaken,
    };

/// Why a path cannot be used: nothing is there, or Windows refuses one of its
/// names (trap 11).
String pathProblemText(AppL10n l10n, PathProblem problem) => switch (problem) {
  PathMissingProblem(:final path) => l10n.problemPathMissing(path),
  PathWindowsNameProblem(:final part, :final path) =>
    l10n.problemPathWindowsName(path, part),
};
