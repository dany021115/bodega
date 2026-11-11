import 'package:bodega/domain/entities/host_issue.dart';
import 'package:bodega/l10n/l10n.dart';

/// A [HostIssue] in the user's language: what is missing, and why it matters.
/// The setup page and a bottle's Gamepads section show it on a requirement
/// card, with the issue's install command apart, to copy. A pad issue names
/// the pad.
///
/// One case per kind and no default, so a kind added to [HostIssueKind] fails
/// the build here until it has its words.
({String title, String detail}) hostIssueText(AppL10n l10n, HostIssue issue) =>
    switch (issue.kind) {
      HostIssueKind.noRosetta => (
        title: l10n.issueNoRosettaTitle,
        detail: l10n.issueNoRosettaDetail,
      ),
      HostIssueKind.unsupportedCpu => (
        title: l10n.issueUnsupportedCpuTitle,
        detail: l10n.issueUnsupportedCpuDetail,
      ),
      HostIssueKind.noVulkan => (
        title: l10n.issueNoVulkanTitle,
        detail: l10n.issueNoVulkanDetail,
      ),
      HostIssueKind.noAudio => (
        title: l10n.issueNoAudioTitle,
        detail: l10n.issueNoAudioDetail,
      ),
      // The engine always names the pad.
      HostIssueKind.padNoAccess => (
        title: l10n.issuePadNoAccessTitle(issue.subject ?? ''),
        detail: l10n.issuePadNoAccessDetail,
      ),
      HostIssueKind.noSdl => (
        title: l10n.issueNoSdlTitle,
        detail: l10n.issueNoSdlDetail,
      ),
    };
