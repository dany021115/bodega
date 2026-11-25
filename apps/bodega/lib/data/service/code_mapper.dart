import 'package:bodega/domain/entities/backend_role.dart';
import 'package:bodega/domain/entities/gptk_step.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:bodega/domain/entities/install_step.dart';
import 'package:bodega/domain/entities/bottle_step.dart';
import 'package:bodega/domain/entities/mach9_step.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:bodega/domain/entities/runtime_block.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:bodega/domain/entities/user_name_problem.dart';
import 'package:bodega/domain/entities/wine_tool.dart';
import 'package:engine/engine.dart' as engine;

// The engine's codes as their domain twins (design §5). Each enum maps in an
// exhaustive switch, so a value the engine adds fails the build here until
// the domain has it.

GptkStep gptkStepOf(engine.GptkStep step) => switch (step) {
  engine.GptkStep.opening => GptkStep.opening,
  engine.GptkStep.acceptLicense => GptkStep.acceptLicense,
  engine.GptkStep.importing => GptkStep.importing,
};

/// A step of a catalog install, with what it names. The engine gives a
/// subject to the kinds that name one.
InstallStep installStepOf(engine.InstallStep step) {
  final subject = step.subject ?? '';
  return switch (step.kind) {
    engine.InstallStepKind.unpinnedDownload => InstallStep.unpinnedDownload(
      subject,
    ),
    engine.InstallStepKind.downloading => const InstallStep.downloading(),
    engine.InstallStepKind.syncMismatch => InstallStep.syncMismatch(subject),
    engine.InstallStepKind.creatingBottle => InstallStep.creatingBottle(
      subject,
    ),
    engine.InstallStepKind.installingMono => const InstallStep.installingMono(),
    engine.InstallStepKind.registry => InstallStep.registry(subject),
    engine.InstallStepKind.runningInstaller =>
      const InstallStep.runningInstaller(),
    engine.InstallStepKind.waiting => const InstallStep.waiting(),
  };
}

BackendRole backendRoleOf(engine.BackendRole role) => switch (role) {
  engine.BackendRole.dx11to12x64 => BackendRole.dx11to12x64,
  engine.BackendRole.dx10to11 => BackendRole.dx10to11,
  engine.BackendRole.dx9to11 => BackendRole.dx9to11,
  engine.BackendRole.everythingElse => BackendRole.everythingElse,
  engine.BackendRole.dx8to12 => BackendRole.dx8to12,
  engine.BackendRole.everythingSlower => BackendRole.everythingSlower,
};

/// A host or gamepad issue: its kind, the gamepad it names and its command,
/// never text.
HostIssue hostIssueOf(engine.HostIssue issue) => HostIssue(
  kind: switch (issue.kind) {
    engine.HostIssueKind.noRosetta => HostIssueKind.noRosetta,
    engine.HostIssueKind.unsupportedCpu => HostIssueKind.unsupportedCpu,
    engine.HostIssueKind.noVulkan => HostIssueKind.noVulkan,
    engine.HostIssueKind.noAudio => HostIssueKind.noAudio,
    engine.HostIssueKind.padNoAccess => HostIssueKind.padNoAccess,
    engine.HostIssueKind.noSdl => HostIssueKind.noSdl,
  },
  subject: issue.subject,
  command: issue.command,
);

/// A path Windows refuses: the engine's record names its bad component.
PathProblem pathProblemOf(engine.PathProblem problem) =>
    PathProblem.windowsName(part: problem.part, path: problem.path);

UserNameProblem userNameProblemOf(engine.UserNameProblem problem) =>
    switch (problem) {
      engine.UserNameProblem.empty => UserNameProblem.empty,
      engine.UserNameProblem.tooLong => UserNameProblem.tooLong,
      engine.UserNameProblem.badCharacter => UserNameProblem.badCharacter,
      engine.UserNameProblem.onlyDots => UserNameProblem.onlyDots,
      engine.UserNameProblem.taken => UserNameProblem.taken,
    };

WineTool wineToolOf(engine.WineTool tool) => switch (tool) {
  engine.WineTool.wineboot => WineTool.wineboot,
  engine.WineTool.reg => WineTool.reg,
  engine.WineTool.installer => WineTool.installer,
  engine.WineTool.winecfg => WineTool.winecfg,
  engine.WineTool.mono => WineTool.mono,
};

RuntimeKind runtimeKindOf(engine.RuntimeKind kind) => switch (kind) {
  engine.RuntimeKind.bodega => RuntimeKind.bodega,
  engine.RuntimeKind.mach9 => RuntimeKind.mach9,
};

engine.RuntimeKind engineRuntimeOf(RuntimeKind kind) => switch (kind) {
  RuntimeKind.bodega => engine.RuntimeKind.bodega,
  RuntimeKind.mach9 => engine.RuntimeKind.mach9,
};

RuntimeBlock runtimeBlockOf(engine.RuntimeBlock block) => switch (block) {
  engine.RuntimeBlock.notThisHost => RuntimeBlock.notThisHost,
  engine.RuntimeBlock.appleSiliconOnly => RuntimeBlock.appleSiliconOnly,
  engine.RuntimeBlock.macosTooOld => RuntimeBlock.macosTooOld,
};

Mach9Step mach9StepOf(engine.Mach9Step step) => switch (step) {
  engine.Mach9Step.downloadingMono => Mach9Step.downloadingMono,
  engine.Mach9Step.downloading => Mach9Step.downloading,
  engine.Mach9Step.mounting => Mach9Step.mounting,
  engine.Mach9Step.checkingSignature => Mach9Step.checkingSignature,
  engine.Mach9Step.copying => Mach9Step.copying,
  engine.Mach9Step.checking => Mach9Step.checking,
  engine.Mach9Step.switching => Mach9Step.switching,
  engine.Mach9Step.probing => Mach9Step.probing,
};

BottleStep bottleStepOf(engine.BottleStep step) => switch (step) {
  engine.BottleStep.prefix => BottleStep.prefix,
  engine.BottleStep.mono => BottleStep.mono,
};
