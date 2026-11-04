import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A section of a bottle's column, that stays folded once folded.
class CollapsibleSection extends StatelessWidget {
  final String id;
  final String title;
  final List<Widget> children;

  const CollapsibleSection({
    super.key,
    required this.id,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final colors = Theme.of(context).colorScheme;
    final expanded = !context.select(
      (SectionsBloc bloc) => bloc.state.collapsed.contains(id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          child: InkWell(
            borderRadius: AppRadius.xsBorder,
            onTap: () =>
                context.read<SectionsBloc>().add(SectionsEvent.toggle(id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      expanded
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(title, style: styles.label)),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[...children, const SizedBox(height: AppSpacing.md)],
      ],
    );
  }
}
