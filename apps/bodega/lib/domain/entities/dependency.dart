import 'package:freezed_annotation/freezed_annotation.dart';

part 'dependency.freezed.dart';

/// A runtime's architecture: a program's bits decide which one it needs;
/// [all] is one install for both, as .NET's, PhysX's and the fonts'.
enum Arch { x86, x64, all }

/// What the bottle shows of a runtime; [unknown] when its files can't be read.
enum DependencyStatus { installed, notInstalled, unknown }

/// How much Bodega wants a runtime for a program (D5).
enum Need { recommended, optional }

/// Why: a known fix names it, Wine has no copy of a DLL the program imports,
/// or the program imports a DLL that Wine also provides.
enum NeedReason { knownFix, notInWine, imported }

/// Where a fix's change to a game's own file stands.
enum SettingState { applied, notApplied, noFile }

/// A Windows runtime Bodega installs from its vendor's files, for one [arch].
/// [name] is a product name, shown as it is.
@freezed
abstract class Dependency with _$Dependency {
  const Dependency._();

  const factory Dependency({
    required String id,
    required String name,
    required Arch arch,

    /// What its files weigh together, shown before anything downloads.
    required int bytes,
    required DependencyStatus status,

    /// How many files it downloads: a file of the user's can stand in for
    /// one only.
    @Default(1) int files,
  }) = _Dependency;

  bool get installed => status == DependencyStatus.installed;
}

/// A runtime one program needs. [dll] is the import that pointed to it, [fix]
/// the fix that named it.
@freezed
abstract class DependencyNeed with _$DependencyNeed {
  const factory DependencyNeed({
    required Dependency dependency,
    required Need need,
    required NeedReason reason,
    String? dll,
    String? fix,
  }) = _DependencyNeed;
}

/// A change a fix makes to a game's own settings file: [name] in [section]
/// becomes [value]. [game] is the fix's title.
@freezed
abstract class SettingNeed with _$SettingNeed {
  const factory SettingNeed({
    required String fix,
    required String game,
    required String section,
    required String name,
    required String value,
    required SettingState state,
  }) = _SettingNeed;
}

/// What Bodega proposes for one application of a bottle.
@freezed
abstract class AppNeeds with _$AppNeeds {
  const AppNeeds._();

  const factory AppNeeds({
    required String key,
    required String title,
    @Default(<DependencyNeed>[]) List<DependencyNeed> dependencies,
    @Default(<SettingNeed>[]) List<SettingNeed> settings,
  }) = _AppNeeds;

  /// Something recommended that the user can do now: a runtime not installed,
  /// or a setting whose file is there and not changed yet. This opens the
  /// dialog by itself after the app is added.
  bool get hasRecommended =>
      dependencies.any(
        (need) => need.need == Need.recommended && !need.dependency.installed,
      ) ||
      settings.any((setting) => setting.state == SettingState.notApplied);

  bool get isEmpty => dependencies.isEmpty && settings.isEmpty;
}

/// Every runtime of a bottle with its status, and what each app needs.
@freezed
abstract class BottleDependencies with _$BottleDependencies {
  const factory BottleDependencies({
    @Default(<Dependency>[]) List<Dependency> all,

    /// When the bottle was read: a check is a few file reads, done again by
    /// "Check again".
    DateTime? checkedAt,

    /// The apps with at least one need, in the bottle's order.
    @Default(<AppNeeds>[]) List<AppNeeds> apps,
  }) = _BottleDependencies;
}

/// One thing to do in a bottle: a runtime for an arch, or a fix's settings.
@freezed
sealed class NeedItem with _$NeedItem {
  const factory NeedItem.runtime(String id, Arch arch) = RuntimeItem;
  const factory NeedItem.settings(String fix) = SettingsItem;
}
