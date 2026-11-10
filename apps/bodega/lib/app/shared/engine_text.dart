import 'package:bodega/domain/entities/hint.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:bodega/domain/entities/progress_step.dart';
import 'package:bodega/domain/entities/user_problem.dart';
import 'package:bodega/l10n/app_localizations.dart';

/// The title of [issue] in the user's language; the engine's text for an id
/// the app doesn't know.
String issueTitle(AppLocalizations l10n, HostIssue issue) => switch (issue.id) {
  'rosetta' => l10n.issueRosettaTitle,
  'cpu' => l10n.issueCpuTitle,
  'vulkan' => l10n.issueVulkanTitle,
  'audio' => l10n.issueAudioTitle,
  'padPermission' => l10n.issuePadPermissionTitle(issue.args['name'] ?? ''),
  'sdl' => l10n.issueSdlTitle,
  _ => issue.title,
};

/// The detail of [issue] in the user's language; the engine's text for an id
/// the app doesn't know.
String issueDetail(AppLocalizations l10n, HostIssue issue) =>
    switch (issue.id) {
      'rosetta' => l10n.issueRosettaDetail,
      'cpu' => l10n.issueCpuDetail,
      'vulkan' => l10n.issueVulkanDetail,
      'audio' => l10n.issueAudioDetail,
      'padPermission' => l10n.issuePadPermissionDetail(
        issue.args['node'] ?? '',
      ),
      'sdl' => l10n.issueSdlDetail,
      _ => issue.detail,
    };

/// [hint] in the user's language; the engine's text for an id the app
/// doesn't know.
String hintText(AppLocalizations l10n, Hint hint) => switch (hint.id) {
  'freetype' => l10n.hintFreetype,
  'gnutls' => l10n.hintGnutls,
  'wineserver' => l10n.hintWineserver,
  'openFailed' => l10n.hintOpenFailed,
  'fixNotApplied' => l10n.hintFixNotApplied,
  'easyAntiCheat' => l10n.hintEasyAntiCheat(switch (hint.args['game']) {
    final game? when game.isNotEmpty => game,
    _ => l10n.hintThisGame,
  }, hint.args['platform'] ?? ''),
  _ => hint.text,
};

/// [step] in the user's language; the engine's text for an id the app
/// doesn't know.
String stepText(AppLocalizations l10n, ProgressStep step) => switch (step.id) {
  'noChecksum' => l10n.stepNoChecksum(step.args['host'] ?? ''),
  'downloading' => l10n.stepDownloading,
  'syncKept' => l10n.stepSyncKept(
    step.args['bottleSync'] ?? '',
    step.args['app'] ?? '',
    step.args['appSync'] ?? '',
  ),
  'creatingBottle' => l10n.stepCreatingBottle(step.args['bottle'] ?? ''),
  'registry' => l10n.stepRegistry(step.args['value'] ?? ''),
  'runningInstaller' => l10n.stepRunningInstaller,
  'waitingInstall' => l10n.stepWaitingInstall,
  'opening' => l10n.stepOpening(step.args['file'] ?? ''),
  'acceptLicense' => l10n.stepAcceptLicense,
  'importingD3DMetal' => l10n.stepImportingD3DMetal,
  _ => step.text,
};

/// Why a name cannot be a Windows user name, in the user's language.
String userProblemText(AppLocalizations l10n, UserProblem problem) =>
    switch (problem) {
      UserProblem.empty => l10n.bottlesUserEmpty,
      UserProblem.tooLong => l10n.bottlesUserTooLong,
      UserProblem.badCharacter => l10n.bottlesUserBadCharacter,
      UserProblem.dotsOrSpaces => l10n.bottlesUserDotsOrSpaces,
    };
