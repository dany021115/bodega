import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/presentation/backends/widgets/backend_card.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BackendsPage extends StatefulWidget {
  const BackendsPage({super.key});

  @override
  State<BackendsPage> createState() => _BackendsPageState();
}

class _BackendsPageState extends State<BackendsPage> {
  @override
  void initState() {
    super.initState();
    context.read<BackendsBloc>().add(const BackendsEvent.load());
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final caps = context.read<SetupBloc>().state.capabilities;

    return Scaffold(
      body: BlocBuilder<BackendsBloc, BackendsState>(
        builder: (context, state) {
          if (state.isLoading) return const CustomLoading();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              Text('Backends', style: styles.screenTitle),
              if (state.error case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                SelectableText(
                  error.message,
                  style: styles.body?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              for (final backend in state.backends)
                if (backend.name != 'd3dmetal' || caps.d3dmetal) ...[
                  const SizedBox(height: AppSpacing.md),
                  BackendCard(backend: backend, state: state),
                ],
            ],
          );
        },
      ),
    );
  }
}
