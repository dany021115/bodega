import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/presentation/setup/widgets/requirement_card.dart';
import 'package:bodega/app/presentation/setup/widgets/runtime_card.dart';
import 'package:bodega/app/shared/text/error_text.dart';
import 'package:bodega/app/shared/widgets/copy_details_button.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final l10n = context.l10n;

    return Scaffold(
      body: BlocBuilder<SetupBloc, SetupState>(
        builder: (context, state) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.setupTitle, style: styles.screenTitle),
                    const SizedBox(height: AppSpacing.xl),
                    if (state.isChecking)
                      const CustomLoading()
                    else ...[
                      for (final issue in state.issues) ...[
                        RequirementCard(issue: issue),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (!state.runtime) ...[
                        RuntimeCard(state: state),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (state.error case final error?) ...[
                        SelectableText(
                          error.localized(l10n),
                          style: styles.body?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        CopyDetailsButton(error: error),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      TextButton.icon(
                        onPressed: state.isInstalling
                            ? null
                            : () => context.read<SetupBloc>().add(
                                const SetupEvent.check(),
                              ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(l10n.commonCheckAgain),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
