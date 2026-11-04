import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/presentation/setup/widgets/rosetta_card.dart';
import 'package:bodega/app/presentation/setup/widgets/runtime_card.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);

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
                    Text('Preparar Bodega', style: styles.screenTitle),
                    const SizedBox(height: AppSpacing.xl),
                    if (state.isChecking)
                      const CustomLoading()
                    else ...[
                      if (!state.rosetta) ...[
                        const RosettaCard(),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (!state.runtime) ...[
                        RuntimeCard(state: state),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (state.error case final error?) ...[
                        SelectableText(
                          error.message,
                          style: styles.body?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      TextButton.icon(
                        onPressed: state.isInstalling
                            ? null
                            : () => context.read<SetupBloc>().add(
                                const SetupEvent.check(),
                              ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Volver a comprobar'),
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
