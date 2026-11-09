import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/device/theme/gradient.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';

/// What a bottle without applications shows in their place.
class BottleEmptyApps extends StatelessWidget {
  final VoidCallback? onAdd;

  const BottleEmptyApps({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppGradient.brand,
              borderRadius: AppRadius.lgBorder,
            ),
            child: ExcludeSemantics(
              child: Icon(
                Icons.add_box_outlined,
                size: 36,
                color: colors.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Esta botella está vacía',
            style: styles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Instala una app popular o agrega tu propio .exe.',
            style: styles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          GradientButton(
            label: 'Agregar app',
            icon: Icons.add_rounded,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
