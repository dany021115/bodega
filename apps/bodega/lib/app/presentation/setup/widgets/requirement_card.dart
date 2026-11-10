import 'package:bodega/app/shared/engine_text.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One thing the computer lacks. Its command, when it has one, can be copied.
class RequirementCard extends StatelessWidget {
  final HostIssue issue;

  const RequirementCard({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final command = issue.command;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issueTitle(context.l10n, issue),
              style: styles.subsectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(issueDetail(context.l10n, issue), style: styles.bodySecondary),
            if (command != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: AppRadius.xsBorder,
                ),
                child: SelectableText(command, style: styles.mono),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: command));
                  if (context.mounted) {
                    AppToast.success(context, context.l10n.setupCommandCopied);
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(context.l10n.setupCopyCommand),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
