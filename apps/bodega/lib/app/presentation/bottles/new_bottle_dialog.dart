import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/new_bottle/new_bottle_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_column.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/error_text.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/gradient.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The rule NewBottleBloc applies to a name: the engine's directory name.
final _nameRule = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');

Future<void> showNewBottleDialog(BuildContext context) {
  // The graphics choices come from the installed backends.
  context.read<BackendsBloc>().add(const BackendsEvent.load());
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => getIt<NewBottleBloc>(),
      child: const NewBottleDialog(),
    ),
  );
}

class NewBottleDialog extends StatelessWidget {
  const NewBottleDialog({super.key});

  String? _nameError(AppLocalizations l10n, NewBottleState state) {
    if (state.name.isEmpty) return null;
    if (!_nameRule.hasMatch(state.name)) return l10n.bottlesNewNameInvalid;
    final taken = state.taken.any(
      (bottle) => bottle.toLowerCase() == state.name.toLowerCase(),
    );
    return taken ? l10n.bottlesNameTaken : null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NewBottleBloc, NewBottleState>(
      listener: (context, state) {
        final created = state.createdName;
        if (created == null) return;
        context.read<BottlesBloc>().add(const BottlesEvent.load());
        context.read<LibraryBloc>().add(const LibraryEvent.load());
        Navigator.of(context).pop();
        RouterManager.go(AppRoute.bottleDetail, params: {'name': created});
      },
      builder: (context, state) {
        final bloc = context.read<NewBottleBloc>();
        final styles = AppTextStyle(context);
        final colors = Theme.of(context).colorScheme;
        final busy = state.isCreating;
        final l10n = context.l10n;

        return PopScope(
          // A bottle being made is not closed halfway.
          canPop: !busy,
          child: Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppGradient.brand,
                            borderRadius: AppRadius.mdBorder,
                          ),
                          child: Icon(
                            Icons.science_rounded,
                            color: colors.onPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.bottlesNewTitle,
                                style: styles.sectionTitle,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                l10n.bottlesNewSubtitle,
                                style: styles.caption,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.commonClose,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (busy)
                      Row(
                        children: [
                          const CustomLoading(size: 20),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                l10n.bottlesCreating,
                                style: styles.body,
                              ),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: l10n.bottlesName,
                          errorText: _nameError(l10n, state),
                        ),
                        onChanged: (name) =>
                            bloc.add(NewBottleEvent.nameChanged(name)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: state.windows,
                              decoration: InputDecoration(
                                labelText: l10n.bottlesWindowsVersion,
                              ),
                              items: [
                                for (final MapEntry(:key, :value)
                                    in BottleColumn.windowsNames.entries)
                                  DropdownMenuItem(
                                    value: key,
                                    child: Text(value),
                                  ),
                              ],
                              onChanged: (windows) {
                                if (windows != null) {
                                  bloc.add(
                                    NewBottleEvent.windowsChanged(windows),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: BlocBuilder<BackendsBloc, BackendsState>(
                              builder: (context, backends) =>
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: state.backend,
                                    decoration: InputDecoration(
                                      labelText: l10n.runOptionsGraphics,
                                    ),
                                    items: _backendItems(
                                      l10n,
                                      backends.backends,
                                    ),
                                    onChanged: (backend) {
                                      if (backend != null) {
                                        bloc.add(
                                          NewBottleEvent.backendChanged(
                                            backend,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: AppRadius.smBorder,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.bottlesNewNote,
                                style: styles.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.error case final error?) ...[
                        const SizedBox(height: AppSpacing.md),
                        SelectableText(
                          error.text(l10n),
                          style: styles.body?.copyWith(color: colors.error),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.commonCancel),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          GradientButton(
                            label: l10n.bottlesCreate,
                            onPressed: state.canSubmit
                                ? () => bloc.add(const NewBottleEvent.submit())
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _backendItems(
    AppLocalizations l10n,
    List<BackendInfo> backends,
  ) => [
    DropdownMenuItem(value: 'auto', child: Text(l10n.bottlesAutomatic)),
    for (final backend in backends)
      if (backend.installed)
        DropdownMenuItem(value: backend.name, child: Text(backend.name)),
  ];
}
