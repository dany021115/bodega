import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BottleLogsCard extends StatelessWidget {
  final BottleDetailState state;

  const BottleLogsCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final colors = Theme.of(context).colorScheme;
    final logs = state.detail?.logs ?? const [];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Logs', style: styles.subsectionTitle),
            const SizedBox(height: AppSpacing.sm),
            if (logs.isEmpty)
              Text('Todavía no hay logs.', style: styles.bodySecondary),
            for (final log in logs)
              InkWell(
                borderRadius: AppRadius.xsBorder,
                onTap: () => context.read<BottleDetailBloc>().add(
                  BottleDetailEvent.openLog(log.path),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          log.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: log.path == state.logPath
                              ? styles.cardTitle
                              : styles.body,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        log.exitCode == null
                            ? 'en curso'
                            : 'salió con ${log.exitCode}',
                        style: styles.caption,
                      ),
                    ],
                  ),
                ),
              ),
            if (state.logPath != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: AppRadius.xsBorder,
                ),
                child: SelectionArea(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.logLines.length,
                    itemBuilder: (context, index) =>
                        Text(state.logLines[index], style: styles.mono),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
