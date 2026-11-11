part of 'engine.dart';

/// What the engine fails with: one final subclass per failure, holding the
/// data a UI needs to word it in its own language (design §4).
sealed class EngineFailure implements Exception {
  const EngineFailure();

  /// English, for the CLI and logs. The app never shows it.
  String get message;

  @override
  String toString() => message;
}

/// No bottle by that name.
final class BottleNotFound extends EngineFailure {
  const BottleNotFound(this.bottle);

  final String bottle;

  @override
  String get message => 'the bottle $bottle does not exist';
}

/// A bottle by that name is already there: to create, rename or install into.
final class BottleExists extends EngineFailure {
  const BottleExists(this.bottle);

  final String bottle;

  @override
  String get message =>
      'the bottle $bottle already exists; to start over: bodega stop $bottle '
      'and delete its folder (bottles/$bottle)';
}

/// The bottle lacks its prefix, or is missing.
final class BottleNotReady extends EngineFailure {
  const BottleNotReady(this.bottle);

  final String bottle;

  @override
  String get message =>
      'the bottle $bottle is not ready: bodega stop $bottle, delete its '
      'folder (bottles/$bottle) and bodega create $bottle';
}

/// The bottle runs, so it cannot be renamed.
final class BottleOpen extends EngineFailure {
  const BottleOpen(this.bottle);

  final String bottle;

  @override
  String get message => 'the bottle $bottle is open: bodega stop $bottle';
}

/// wineboot ended, but the bottle did not come out ready.
final class BottleSetupFailed extends EngineFailure {
  const BottleSetupFailed(this.log, this.timedOut);

  /// The wineboot log.
  final String log;

  /// Whether `wineserver -w` ran past its 10 minutes and the bottle was
  /// stopped; otherwise the prefix lacks `syswow64/kernel32.dll` or
  /// `system.reg`.
  final bool timedOut;

  @override
  String get message => timedOut
      ? 'wineserver -w ran past 10 min, so the bottle was stopped; log: $log'
      : 'the bottle is not ready: syswow64/kernel32.dll or system.reg is '
            'missing; log: $log';
}

/// A bottle name outside R8.
final class BadBottleName extends EngineFailure {
  const BadBottleName(this.name);

  final String name;

  @override
  String get message =>
      'not a valid bottle name: "$name" (letters without accents, numbers, _ '
      'and -, up to 64, not starting with _ or -)';
}

/// A path that Windows refuses (trap 11).
final class BadWindowsPath extends EngineFailure {
  const BadWindowsPath(this.problem);

  final PathProblem problem;

  @override
  String get message => describePathProblem(problem);
}

/// A Windows user name the bottle cannot take (U3, U4).
final class BadUserName extends EngineFailure {
  const BadUserName(this.user, this.problem);

  final String user;
  final UserNameProblem problem;

  @override
  String get message => switch (problem) {
    UserNameProblem.taken =>
      'C:\\users\\$user already exists in the bottle: delete it or choose '
          'another name',
    UserNameProblem.empty ||
    UserNameProblem.tooLong ||
    UserNameProblem.badCharacter ||
    UserNameProblem.onlyDots =>
      '"$user" cannot be a Windows user name: ${problem.english}',
  };
}

/// The bottle has no application with that key, or none at all.
final class AppNotFound extends EngineFailure {
  const AppNotFound(this.bottle, [this.key]);

  final String bottle;

  /// The key asked for; null when the bottle has no application to open.
  final String? key;

  @override
  String get message => key == null
      ? 'the bottle $bottle has no application installed; use bodega run '
            '$bottle <program>'
      : 'the bottle $bottle has no application $key';
}

/// The bottle already lists that exe.
final class AppAlreadyAdded extends EngineFailure {
  const AppAlreadyAdded(this.bottle);

  final String bottle;

  @override
  String get message => 'the bottle $bottle already has that application';
}

/// A file the user named is not there.
final class MissingFile extends EngineFailure {
  const MissingFile(this.path);

  final String path;

  @override
  String get message => '$path does not exist';
}

/// A runtime tarball without its checksum beside it.
final class ChecksumMissing extends EngineFailure {
  const ChecksumMissing(this.file);

  /// The missing checksum file, `<tarball>.sha256`.
  final String file;

  /// Names the release of the tarball's own name: build.yml and
  /// build-hostlibs.yml tag each engine and hostlibs release with its
  /// tarball's name, and attach the `.sha256` beside it.
  @override
  String get message =>
      '$file is missing: gh release download '
      '${_tag(file.replaceFirst(RegExp(r'\.sha256$'), ''))} '
      '-R dany021115/bodega';
}

/// A download or a file whose SHA-256 is not the one expected.
final class ChecksumMismatch extends EngineFailure {
  const ChecksumMismatch(this.file);

  final String file;

  @override
  String get message => 'wrong checksum for $file';
}

/// An archive or image without a file it must hold.
final class IncompleteArchive extends EngineFailure {
  const IncompleteArchive(this.archive, this.missing);

  final String archive;

  /// What it lacks.
  final String missing;

  @override
  String get message => '$archive is incomplete: $missing is missing';
}

/// A file of the engine's that it cannot read: `apps.json`, `settings.json`
/// or the fixes data.
final class CorruptData extends EngineFailure {
  const CorruptData(this.source, this.detail);

  final String source;

  /// Why, as the parser or the check put it.
  final String detail;

  @override
  String get message => '$source is not valid: $detail';
}

/// No runtime is installed.
final class NoRuntime extends EngineFailure {
  const NoRuntime();

  @override
  String get message =>
      'no runtime installed: bodega install <engine.tar.gz> <hostlibs.tar.gz>';
}

/// A runtime or a backend is already at [path].
final class AlreadyInstalled extends EngineFailure {
  const AlreadyInstalled(this.path);

  final String path;

  @override
  String get message =>
      'already installed: $path. To replace it: bodega stop every bottle, '
      'rm -rf "$path" and install it again';
}

/// Something this host does not offer.
final class NotAvailable extends EngineFailure {
  const NotAvailable(this.what, this.host);

  final String what;

  /// `Mac` or `Linux`, or the system Bodega does not run on.
  final String host;

  @override
  String get message => '$what is not available on $host';
}

/// A backend that Bodega does not download: d3dmetal, or one without a
/// pinned tarball.
final class NotDownloadable extends EngineFailure {
  const NotDownloadable(this.backend);

  final String backend;

  @override
  String get message => backend == 'd3dmetal'
      ? 'Bodega does not download d3dmetal: bodega backend import d3dmetal '
            '<folder>'
      : 'no installer for the backend $backend';
}

/// A backend chosen but not installed (S5).
final class BackendNotInstalled extends EngineFailure {
  const BackendNotInstalled(this.backend);

  final String backend;

  @override
  String get message {
    final command = backend == 'd3dmetal'
        ? 'import d3dmetal <folder>'
        : 'install $backend';
    return '$backend is not installed: bodega backend $command';
  }
}

/// A [value] outside what [kind] admits.
final class BadChoice extends EngineFailure {
  const BadChoice(this.kind, this.value);

  final ChoiceKind kind;
  final String value;

  @override
  String get message => 'unknown ${kind.english}: $value ($_choices)';

  /// What [kind] admits on this host, or the command that lists it.
  String get _choices => switch (kind) {
    ChoiceKind.backend => ['auto', ...backendNames].join(', '),
    ChoiceKind.testBackend => backendNames.join(', '),
    ChoiceKind.gpu => 'auto, discrete',
    ChoiceKind.sync => hostPlatform.capabilities.syncModes.join(', '),
    ChoiceKind.windows => windowsVersions.join(', '),
    ChoiceKind.catalogApp => 'bodega catalog list',
    ChoiceKind.fix => 'bodega fix list',
  };
}

/// No D3DMetal at [source]: a Game Porting Toolkit dmg or a folder.
final class NoD3DMetal extends EngineFailure {
  const NoD3DMetal(this.source, this.missing);

  final String source;

  /// What it lacks.
  final String missing;

  @override
  String get message => 'no D3DMetal in $source: $missing is missing';
}

/// A D3DMetal import from inside CrossOver.app (design §6).
final class CrossOverCopy extends EngineFailure {
  const CrossOverCopy();

  @override
  String get message =>
      'D3DMetal is not imported from CrossOver.app: use your own copy of '
      'D3DMetal';
}

/// `hdiutil attach` could not open a dmg.
final class MountFailed extends EngineFailure {
  const MountFailed(this.image, this.detail);

  final String image;

  /// What hdiutil said.
  final String detail;

  @override
  String get message => 'could not open ${image.split('/').last}: $detail';
}

/// The user cancelled the D3DMetal import.
final class Cancelled extends EngineFailure {
  const Cancelled();

  @override
  String get message => 'installation cancelled';
}

/// Apple's license window was left without an answer.
final class LicenseNotAccepted extends EngineFailure {
  const LicenseNotAccepted();

  @override
  String get message => "Apple's license was not accepted";
}

/// A catalog entry that Bodega does not install.
final class CatalogBlocked extends EngineFailure {
  const CatalogBlocked(this.id);

  final String id;

  @override
  String get message =>
      '$id is blocked in the catalog: bodega catalog show $id';
}

/// An installer URL that is not HTTPS.
final class NotHttps extends EngineFailure {
  const NotHttps(this.url);

  final String url;

  @override
  String get message => 'the URL is not https: $url';
}

/// A Wine program run in a bottle exited with an error.
final class WineToolFailed extends EngineFailure {
  const WineToolFailed(this.tool, this.exitCode, this.log);

  final WineTool tool;
  final int exitCode;
  final String log;

  @override
  String get message => '${tool.english} exited with $exitCode; log: $log';
}

/// The installer ended well, but the exe it should leave is not there.
final class InstallerNoExe extends EngineFailure {
  const InstallerNoExe(this.exe, this.log);

  final String exe;
  final String log;

  @override
  String get message =>
      'the installer finished but $exe is not there; log: $log';
}

/// A host program failed: tar, curl, cp, codesign, hdiutil, or a
/// `wine --version` that gave no version.
final class ProcessFailed extends EngineFailure {
  const ProcessFailed(this.command, this.exitCode, this.output);

  /// The command line.
  final String command;

  /// Null when it ran but did not answer as expected.
  final int? exitCode;

  /// What it printed.
  final String output;

  @override
  String get message {
    final how = exitCode == null ? 'failed' : 'exited with $exitCode';
    final said = output.trim();
    return said.isEmpty ? '$command $how' : '$command $how: $said';
  }
}

/// Why Windows refuses a path (trap 11): its first bad component, and the
/// whole path.
typedef PathProblem = ({String part, String path});

/// Why a name cannot be the Windows user of a bottle (U3, U4).
enum UserNameProblem {
  empty('the name is empty'),
  tooLong('the name is longer than 20 characters'),
  badCharacter(r'the name cannot hold " / \ [ ] : ; | = , + * ? < >'),
  onlyDots('the name cannot be only dots or spaces'),

  /// The bottle has a profile folder by that name already.
  taken('the bottle already has a profile folder by that name');

  const UserNameProblem(this.english);

  /// For the CLI and logs.
  final String english;
}

/// The Wine programs whose exit code the engine checks.
enum WineTool {
  wineboot('wineboot'),

  /// `reg add`, for the catalog, the user, high resolution and the fixes.
  reg('reg add'),

  /// A catalog entry's installer, or msiexec for an MSI.
  installer('the installer'),
  winecfg('winecfg');

  const WineTool(this.english);

  /// For the CLI and logs.
  final String english;
}

/// The kinds of value that the engine checks against what it admits.
enum ChoiceKind {
  /// A bottle's, a program's or a launch's backend: `auto` or one of
  /// [backendNames].
  backend('backend'),

  /// The backend a probe runs with: one of [backendNames], never `auto`.
  testBackend('backend to test'),
  gpu('GPU'),
  sync('sync mode'),
  windows('Windows version'),
  catalogApp('catalog app'),

  /// A fix's id or its Steam app id.
  fix('fix');

  const ChoiceKind(this.english);

  /// For the CLI and logs.
  final String english;
}
