import 'package:engine/engine.dart';
import 'package:test/test.dart';

/// The engine grep's pattern (engine-codes.md), spelled so that the grep does
/// not find it here: the accented letters as escapes, and each word with a `_`
/// that is taken out before use.
final spanish = RegExp(
  '[\u00e1\u00e9\u00ed\u00f3\u00fa\u00fc\u00f1\u00bf\u00a1]|'
  '\\b(${_words.map((word) => word.replaceAll('_', '')).join('|')})\\b',
  caseSensitive: false,
);

const _words = [
  'bo_tellas?',
  'fal_ta',
  'instal_ad[oa]s?',
  'instal_ador',
  'descono_cid[oa]',
  'avi_so',
  'pis_ta',
  'no_ta',
  'usua_rio',
  'resolu_cion',
  'man_dos',
  'opc_ion',
  'carpe_ta',
  'u_so',
  'ru_ta',
  'h_ay',
  'exis_te',
  'arre_glo',
  'siste_ma',
  'soporta_d[oa]',
  'disponi_ble',
  'nom_bre',
  'licen_cia',
  'jue_gos?',
  'prue_ba',
  'son_da',
  'ro_to',
  'na_da',
  'u_no',
  'va_lor',
  'u_na',
  'l_os',
  'l_as',
  'pa_ra',
  'es_ta',
  'c_on',
];

const _log = '/h/bottles/steam/logs/x.log';

/// One of each failure, and one more for each branch of a message.
final failures = <EngineFailure>[
  const BottleNotFound('nope'),
  const BottleExists('steam'),
  const BottleNotReady('steam'),
  const BottleOpen('steam'),
  const BottleSetupFailed(_log, true),
  const BottleSetupFailed(_log, false),
  const BadBottleName('a b'),
  const BadWindowsPath((part: 'odd:', path: '/games/odd:/game.exe')),
  for (final problem in UserNameProblem.values) BadUserName('player', problem),
  const AppNotFound('steam'),
  const AppNotFound('steam', 'steam:220'),
  const AppAlreadyAdded('steam'),
  const MissingFile('/games/game.exe'),
  const ChecksumMissing('/downloads/engine-11.0.tar.gz.sha256'),
  const ChecksumMismatch('/downloads/engine-11.0.tar.gz'),
  const IncompleteArchive('engine-11.0.tar.gz', 'engine/bin/wine'),
  const CorruptData('/h/bottles/steam/apps.json', 'Unexpected end of input'),
  const NoRuntime(),
  const AlreadyInstalled('/h/runtimes/engine-11.0'),
  const NotAvailable('d3dmetal', 'Linux'),
  const NotDownloadable('d3dmetal'),
  const NotDownloadable('dxmt'),
  const BackendNotInstalled('d3dmetal'),
  const BackendNotInstalled('dxvk'),
  for (final kind in ChoiceKind.values) BadChoice(kind, 'nope'),
  const NoD3DMetal('/downloads/gptk.dmg', 'redist/lib'),
  const CrossOverCopy(),
  const MountFailed('/downloads/gptk.dmg', 'hdiutil: attach failed'),
  const Cancelled(),
  const LicenseNotAccepted(),
  const CatalogBlocked('epic'),
  const NotHttps('http://example.com/setup.exe'),
  for (final tool in WineTool.values) WineToolFailed(tool, 3, _log),
  const InstallerNoExe('Program Files (x86)/Steam/steam.exe', _log),
  const ProcessFailed('/usr/bin/tar -xzf x.tar.gz', 2, 'tar: bad archive\n'),
  const ProcessFailed('wine --version', null, ''),
  ...switchFailures.keys,
];

/// The six Switch failures, each with its message as SE20 gives it.
final switchFailures = <EngineFailure, String>{
  const NoEmulator('Ryubing', 'Ryujinx.app'):
      'Ryubing not found: Bodega looks for Ryujinx.app in /Applications and '
      '~/Applications, or takes one from bodega switch emulator <path>',
  const NotAnEmulator('/Users/q/Other.app', 'Ryubing'):
      '/Users/q/Other.app is not Ryubing: its Info.plist names another app',
  const NotASwitchGame('/Users/q/readme.txt', [
    'xci',
    'nsp',
    'pfs0',
    'nca',
    'nro',
    'nso',
  ]): '/Users/q/readme.txt is not a Switch game: .xci .nsp .pfs0 .nca .nro '
      '.nso, or an nxnative app',
  const SwitchGameNotFound('/Users/q/g.nsp'):
      '/Users/q/g.nsp is not among the Switch games: bodega switch list',
  const SwitchGameRunning('/Users/q/a b.nsp'):
      '/Users/q/a b.nsp is already running: bodega switch stop '
      '"/Users/q/a b.nsp"',
  const NoSwitchKeys('/Users/q/Downloads'):
      'no .keys file at /Users/q/Downloads',
};

/// The command a message keeps from today's text (E4), or null. Exhaustive,
/// so that a new failure does not compile here until it has a case.
String? hintOf(EngineFailure failure) => switch (failure) {
  BottleExists(:final bottle) ||
  BottleNotReady(:final bottle) ||
  BottleOpen(:final bottle) => 'bodega stop $bottle',
  NoRuntime() => 'bodega install <engine.tar.gz> <hostlibs.tar.gz>',
  ChecksumMissing() => 'gh release download',
  BackendNotInstalled(backend: 'd3dmetal') ||
  NotDownloadable(backend: 'd3dmetal') => 'bodega backend import d3dmetal',
  BackendNotInstalled(:final backend) => 'bodega backend install $backend',
  BadChoice(kind: ChoiceKind.catalogApp) => 'bodega catalog list',
  BadChoice(kind: ChoiceKind.fix) => 'bodega fix list',
  AppNotFound(:final bottle, key: null) => 'bodega run $bottle',
  AlreadyInstalled(:final path) => 'rm -rf "$path"',
  NoEmulator() => 'bodega switch emulator <path>',
  SwitchGameNotFound() => 'bodega switch list',
  SwitchGameRunning(:final path) => 'bodega switch stop "$path"',
  BottleNotFound() ||
  BottleSetupFailed() ||
  BadBottleName() ||
  BadWindowsPath() ||
  BadUserName() ||
  AppNotFound() ||
  AppAlreadyAdded() ||
  MissingFile() ||
  ChecksumMismatch() ||
  IncompleteArchive() ||
  CorruptData() ||
  NotAvailable() ||
  NotDownloadable() ||
  BadChoice() ||
  NoD3DMetal() ||
  CrossOverCopy() ||
  MountFailed() ||
  Cancelled() ||
  LicenseNotAccepted() ||
  CatalogBlocked() ||
  NotHttps() ||
  WineToolFailed() ||
  InstallerNoExe() ||
  ProcessFailed() ||
  NotAnEmulator() ||
  NotASwitchGame() ||
  NoSwitchKeys() => null,
};

void main() {
  test('the Spanish pattern finds Spanish and passes English', () {
    for (final word in ['fal_ta', 'c_on', 'bo_tellas']) {
      expect('x ${word.replaceAll('_', '')} y', matches(spanish), reason: word);
    }
    expect('acci\u00f3n', matches(spanish));
    expect('the bottle is open: bodega stop steam', isNot(matches(spanish)));
  });

  test('a failure prints its English message', () {
    expect(
      '${const BottleOpen('steam')}',
      'the bottle steam is open: bodega stop steam',
    );
  });

  // build.yml and build-hostlibs.yml tag each release with its tarball's
  // name. These two are named like real releases of dany021115/bodega, with
  // their free-text note (the workflows' ref_note input) in English.
  test('a missing checksum names the release of its tarball, engine or '
      'hostlibs (E4)', () {
    for (final tag in [
      'engine-wine-11.0-20261030T202616Z-first-build',
      'hostlibs-x86_64-20261102T194229Z-first-hostlibs',
    ]) {
      expect(
        ChecksumMissing('/d/$tag.tar.gz.sha256').message,
        '/d/$tag.tar.gz.sha256 is missing: '
        'gh release download $tag -R dany021115/bodega',
      );
    }
  });

  test('the list holds each of the 37 failures', () {
    expect(
      failures.map((failure) => failure.runtimeType).toSet(),
      hasLength(37),
    );
  });

  test('each Switch failure reads as SE20 says, with no link', () {
    expect(switchFailures, hasLength(6));
    for (final MapEntry(key: failure, value: text) in switchFailures.entries) {
      final name = '${failure.runtimeType}';
      expect(failure.message, text, reason: name);
      expect('$failure', text, reason: name);
      expect(text, isNot(matches(spanish)), reason: name);
      expect(text, isNot(matches(RegExp(r'://|www\.'))), reason: name);
    }
  });

  test('each failure is in English and keeps its hint', () {
    for (final failure in failures) {
      final text = failure.message;
      final name = '${failure.runtimeType}';
      expect(text, isNotEmpty, reason: name);
      expect(text, isNot(matches(spanish)), reason: '$name: $text');
      expect('$failure', text, reason: name);
      if (hintOf(failure) case final hint?) {
        expect(text, contains(hint), reason: name);
      }
    }
  });

  // The hints of a run, and the note a fix that missed leaves in its log.
  test('each run hint is in English, and keeps its command (E4, E5)', () {
    final texts = {
      for (final hint in LogHint.values) '$hint': hint.english,
      'fixNotApplied': fixNotApplied,
      for (final game in ['POLYGON', null])
        'describeAntiCheatHint($game)': describeAntiCheatHint((game: game)),
    };
    for (final MapEntry(:key, :value) in texts.entries) {
      expect(value, isNotEmpty, reason: key);
      expect(value, isNot(matches(spanish)), reason: '$key: $value');
    }
    expect(LogHint.otherServer.english, contains('bodega stop <bottle>'));
    expect(
      describeAntiCheatHint((game: 'POLYGON')),
      allOf(startsWith('POLYGON uses Easy Anti-Cheat'), contains('error 206')),
    );
    expect(
      describeAntiCheatHint((game: null)),
      allOf(
        startsWith('This game uses Easy Anti-Cheat'),
        contains('error 206'),
      ),
    );
  });

  test('each log hint has a marker of its own; the fix one is the note', () {
    final markers = [for (final hint in LogHint.values) hint.marker];
    expect(markers, everyElement(isNotEmpty));
    expect(markers.toSet(), hasLength(LogHint.values.length));
    expect(LogHint.fixNotApplied.marker, fixNotApplied);
  });

  test('each code is in English', () {
    const path = (part: 'odd:', path: '/games/odd:/game.exe');
    final texts = {
      for (final value in UserNameProblem.values) '$value': value.english,
      for (final value in WineTool.values) '$value': value.english,
      for (final value in ChoiceKind.values) '$value': value.english,
      'describePathProblem': describePathProblem(path),
    };
    for (final MapEntry(:key, :value) in texts.entries) {
      expect(value, isNotEmpty, reason: key);
      expect(value, isNot(matches(spanish)), reason: '$key: $value');
    }
    expect(
      describePathProblem(path),
      allOf(contains('"odd:"'), contains('/games/odd:/game.exe')),
    );
  });

  test('each step is in English, and names its subject', () {
    for (final step in GptkStep.values) {
      expect(step.english, isNotEmpty, reason: '$step');
      expect(step.english, isNot(matches(spanish)), reason: '$step');
    }
    // What each kind names, as installEntry gives it; null for the others.
    const subjects = {
      InstallStepKind.unpinnedDownload: 'cdn.example.com',
      InstallStepKind.syncMismatch: 'msync',
      InstallStepKind.creatingBottle: 'steam',
      InstallStepKind.registry: 'ServicesPipeTimeout',
    };
    for (final kind in InstallStepKind.values) {
      final subject = subjects[kind];
      final text = describeInstallStep((kind: kind, subject: subject));
      expect(text, isNotEmpty, reason: '$kind');
      expect(text, isNot(matches(spanish)), reason: '$kind: $text');
      if (subject != null) expect(text, contains(subject), reason: '$kind');
    }
  });

  test('each host issue and backend role is in English (E3, E4)', () {
    const pad = 'Microsoft X-Box 360 pad';
    final texts = {
      for (final kind in HostIssueKind.values)
        '$kind': describeHostIssue((
          kind: kind,
          subject: kind == HostIssueKind.padNoAccess ? pad : null,
          command: 'sudo apt install x',
        )),
      for (final role in BackendRole.values) '$role': role.english,
    };
    expect(texts.values.toSet(), hasLength(texts.length));
    for (final MapEntry(:key, :value) in texts.entries) {
      expect(value, isNotEmpty, reason: key);
      expect(value, isNot(matches(spanish)), reason: '$key: $value');
      // The command is the issue's own, printed apart.
      expect(value, isNot(contains('sudo apt install x')), reason: key);
    }
    expect(texts['${HostIssueKind.padNoAccess}'], contains(pad));
  });
}
