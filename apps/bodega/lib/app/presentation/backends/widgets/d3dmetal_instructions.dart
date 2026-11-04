import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// D3DMetal is never downloaded or bundled: the user brings their own (P13).
class D3DMetalInstructions extends StatelessWidget {
  const D3DMetalInstructions({super.key});

  static final _apple = Uri.parse(
    'https://developer.apple.com/games/game-porting-toolkit/',
  );

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1. Consíguelo de Apple, en Game Porting Toolkit, o usa una copia '
          'tuya que ya tengas.',
          style: styles.body,
        ),
        TextButton.icon(
          onPressed: () => launchUrl(_apple),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Abrir developer.apple.com'),
        ),
        Text(
          '2. Elige la carpeta que contiene wine/ y external/, o lib/.',
          style: styles.body,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('3. Pulsa Comprobar.', style: styles.body),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Su uso se rige por la licencia de Apple. La copia de CrossOver no '
          'se acepta. Solo se ha probado con las copias de Whisky y Sikarugir.',
          style: styles.caption,
        ),
      ],
    );
  }
}
