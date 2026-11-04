import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RosettaCard extends StatelessWidget {
  const RosettaCard({super.key});

  static const _command = 'softwareupdate --install-rosetta --agree-to-license';

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Falta Rosetta', style: styles.subsectionTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Los juegos de Windows corren sobre Rosetta 2. Pega este comando '
              'en Terminal y vuelve a comprobar.',
              style: styles.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.xsBorder,
              ),
              child: SelectableText(_command, style: styles.mono),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: _command));
                if (context.mounted) {
                  AppToast.success(context, 'Comando copiado');
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar comando'),
            ),
          ],
        ),
      ),
    );
  }
}
