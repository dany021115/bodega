import 'package:bodega/domain/entities/dependency.dart';
import 'package:bodega/l10n/l10n.dart';

/// The words of the dependencies (DA8): exhaustive switches over the domain's
/// codes, so a new code fails analysis until it is worded. Product names and
/// a setting's section, key and value are shown as they are.
extension DependencyText on AppL10n {
  String archOf(Arch arch) => switch (arch) {
    Arch.x86 => depsArch32,
    Arch.x64 => depsArch64,
  };

  String needOf(Need need) => switch (need) {
    Need.recommended => depsNeedRecommended,
    Need.optional => depsNeedOptional,
  };

  /// "4.5 MB", in the user's language.
  String sizeOf(int bytes) => depsSize(bytes / 1000000);

  /// A runtime as one line: name, bits and size.
  String dependencyLine(Dependency dependency) => depsItem(
    dependency.name,
    archOf(dependency.arch),
    sizeOf(dependency.bytes),
  );

  /// Why a program needs a runtime.
  String reasonOf(DependencyNeed need) => switch (need.reason) {
    NeedReason.knownFix => fixReason(need.fix),
    NeedReason.notInWine => depsReasonNotInWine(need.dll ?? ''),
    NeedReason.imported => depsReasonImported(need.dll ?? ''),
  };

  /// Why a known fix helps its game. Keyed by the fix's id, so it keeps a
  /// default for an id with no sentence of its own.
  String fixReason(String? fix) => switch (fix) {
    'blur' => depsFixBlur,
    'need-for-speed-most-wanted-2012' => depsFixNfsMostWanted2012,
    _ => depsFixOther,
  };

  String settingStateOf(SettingState state) => switch (state) {
    SettingState.applied => depsSettingApplied,
    SettingState.notApplied => depsSettingNotApplied,
    SettingState.noFile => depsSettingNoFile,
  };

  /// A setting as one line: `[Section] Name = value`.
  String settingLine(SettingNeed setting) =>
      depsSetting('[${setting.section}] ${setting.name} = ${setting.value}');
}
