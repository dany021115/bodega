part of 'engine.dart';

// English texts for the codes that are records, for the CLI and logs. Enums
// carry theirs in an `english` field (design §4).

/// Easy Anti-Cheat's failure under Wine (I11): the game [hint] names, or this
/// game when its log names none.
String describeAntiCheatHint(AntiCheatHint hint) =>
    '${hint.game ?? 'This game'} uses Easy Anti-Cheat, which could not load '
    'under Wine on ${hostPlatform.displayName} (error 206). It is not a fault '
    "of your install: it depends on the game's developers and on Epic.";

/// What the host lacks, and why it matters. The command that installs it, if
/// there is one, is the issue's own: the CLI prints it apart.
String describeHostIssue(HostIssue issue) => switch (issue.kind) {
  HostIssueKind.noRosetta => 'Rosetta 2 is missing: Windows games run on it',
  HostIssueKind.unsupportedCpu =>
    'unsupported processor: Bodega needs an x86_64 processor',
  HostIssueKind.noVulkan =>
    'Vulkan is missing: games draw with it, through DXVK',
  HostIssueKind.noAudio =>
    'audio is missing: Wine needs PulseAudio, or PipeWire with its Pulse '
        'support',
  HostIssueKind.padNoAccess =>
    'no access to the gamepad ${issue.subject}, so Wine will not see it: '
        'install the gamepad udev rules (on Arch, the package is in '
        'multilib), then unplug the gamepad and plug it in again',
  HostIssueKind.noSdl =>
    'SDL2 is missing: Wine reads gamepads through it, and without it falls '
        'back to udev, which knows fewer gamepads',
};

/// Why Windows refuses the path of [problem].
String describePathProblem(PathProblem problem) =>
    '"${problem.part}" in ${problem.path}: Windows does not allow names that '
    'end in a dot or a space, or that hold <>:"|?*';

/// What a catalog install is doing, one line per [step].
String describeInstallStep(InstallStep step) {
  final subject = step.subject ?? '';
  return switch (step.kind) {
    InstallStepKind.unpinnedDownload =>
      'No pinned checksum: trusting HTTPS and $subject',
    InstallStepKind.downloading => 'Downloading the installer',
    InstallStepKind.syncMismatch =>
      'The bottle keeps its sync, $subject, though the app asks for another: '
          'change it if the app fails',
    InstallStepKind.creatingBottle => 'Creating the bottle $subject',
    InstallStepKind.registry => 'Registry: $subject',
    InstallStepKind.runningInstaller => 'Running the installer',
    InstallStepKind.waiting => 'Waiting for the installation to finish',
  };
}
