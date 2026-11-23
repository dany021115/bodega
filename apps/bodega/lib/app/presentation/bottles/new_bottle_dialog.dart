import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/new_bottle/new_bottle_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_column.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/text/error_text.dart';
import 'package:bodega/app/shared/text/runtime_text.dart';
import 'package:bodega/app/shared/widgets/copy_details_button.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/gradient.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The rule NewBottleBloc applies to a name: the engine's directory name.
final _nameRule = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');

Future<void> showNewBottleDialog(BuildContext context) {
  // The graphics choices come from the installed backends and runtimes.
  final backends = context.read<BackendsBloc>()
    ..add(const BackendsEvent.load());
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) =>
          getIt<NewBottleBloc>()
            ..add(NewBottleEvent.nativeAvailable(backends.state.nativeUsable)),
      child: const NewBottleDialog(),
    ),
  );
}

class NewBottleDialog extends StatelessWidget {
  const NewBottleDialog({super.key});

  String? _nameError(AppL10n l10n, NewBottleState state) {
    if (state.name.isEmpty) return null;
    if (!_nameRule.hasMatch(state.name)) return l10n.bottleNameRule;
    final taken = state.taken.any(
      (bottle) => bottle.toLowerCase() == state.name.toLowerCase(),
    );
    return taken ? l10n.newBottleNameTaken : null;
  }

  @override
  Widget build(BuildContext context) {
    // D26: Native is preselected once the engine is known to be usable.
    return BlocListener<BackendsBloc, BackendsState>(
      listenWhen: (before, after) => before.nativeUsable != after.nativeUsable,
      listener: (context, backends) => context.read<NewBottleBloc>().add(
        NewBottleEvent.nativeAvailable(backends.nativeUsable),
      ),
      child: _dialog(context),
    );
  }

  Widget _dialog(BuildContext context) {
    return BlocConsumer<NewBottleBloc, NewBottleState>(
      listenWhen: (before, after) => before.createdName != after.createdName,
      listener: (context, state) {
        final created = state.createdName;
        if (created == null) return;
        context.read<BottlesBloc>().add(const BottlesEvent.load());
        context.read<LibraryBloc>().add(const LibraryEvent.load());
        // The bottle is made; its page offers Wine Mono again (MB7).
        if (state.monoFailed) {
          AppToast.warning(context, context.l10n.newBottleMonoFailed(created));
        }
        Navigator.of(context).pop();
        RouterManager.go(AppRoute.bottleDetail, params: {'name': created});
      },
      builder: (context, state) {
        final bloc = context.read<NewBottleBloc>();
        final l10n = context.l10n;
        final styles = AppTextStyle(context);
        final colors = Theme.of(context).colorScheme;
        final busy = state.isCreating;

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
                                l10n.newBottleTitle,
                                style: styles.sectionTitle,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                l10n.newBottleSubtitle,
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
                              child: Text(switch (state.step) {
                                final step? => bottleStepText(l10n, step),
                                null => l10n.newBottleCreating,
                              }, style: styles.body),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      // It scrolls: three dropdowns, the notes and an error
                      // must not push the buttons out of a 720×480 window.
                      Flexible(
                        child: SingleChildScrollView(
                          child: _form(context, state),
                        ),
                      ),
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
                            label: l10n.newBottleCreate,
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

  /// The name, the dropdowns, the note and the error: what scrolls.
  Widget _form(BuildContext context, NewBottleState state) {
    final bloc = context.read<NewBottleBloc>();
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final colors = Theme.of(context).colorScheme;
    final native = state.runtime == RuntimeKind.mach9;

    return BlocBuilder<BackendsBloc, BackendsState>(
      builder: (context, backends) {
        // The engine is offered only where the native one is usable (MA6).
        final engines = backends.nativeUsable;
        final graphics = native
            ? _names(l10n, backends.mach9?.backends ?? const [])
            : _backendItems(l10n, backends.backends);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room above the label of a focused field, inside the scroll.
            const SizedBox(height: AppSpacing.xs),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.commonName,
                errorText: _nameError(l10n, state),
              ),
              onChanged: (name) => bloc.add(NewBottleEvent.nameChanged(name)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                if (engines) ...[
                  Expanded(
                    child: DropdownButtonFormField<RuntimeKind>(
                      key: ValueKey('engine ${state.runtime}'),
                      isExpanded: true,
                      initialValue: state.runtime,
                      decoration: InputDecoration(labelText: l10n.bottleEngine),
                      items: [
                        for (final kind in [
                          RuntimeKind.mach9,
                          RuntimeKind.bodega,
                        ])
                          DropdownMenuItem(
                            value: kind,
                            child: Text(
                              runtimeKindText(l10n, kind),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (kind) {
                        if (kind != null && kind != state.runtime) {
                          bloc.add(NewBottleEvent.runtimeChanged(kind));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: state.windows,
                    decoration: InputDecoration(
                      labelText: l10n.bottleWindowsVersion,
                    ),
                    items: [
                      for (final MapEntry(:key, :value)
                          in BottleColumn.windowsNames.entries)
                        DropdownMenuItem(
                          value: key,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (windows) {
                      if (windows != null) {
                        bloc.add(NewBottleEvent.windowsChanged(windows));
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  // A new engine is a new list: the field starts over.
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('graphics ${state.runtime}'),
                    isExpanded: true,
                    initialValue: state.backend,
                    decoration: InputDecoration(labelText: l10n.bottleGraphics),
                    items: graphics,
                    onChanged: (backend) {
                      if (backend != null) {
                        bloc.add(NewBottleEvent.backendChanged(backend));
                      }
                    },
                  ),
                ),
              ],
            ),
            if (engines) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.newBottleNativeHint, style: styles.caption),
            ],
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
                      native ? l10n.newBottleNoteNative : l10n.newBottleNote,
                      style: styles.caption,
                    ),
                  ),
                ],
              ),
            ),
            if (state.error case final error?) ...[
              const SizedBox(height: AppSpacing.md),
              SelectableText(
                error.localized(l10n),
                style: styles.body?.copyWith(color: colors.error),
              ),
              CopyDetailsButton(error: error),
            ],
          ],
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _backendItems(
    AppL10n l10n,
    List<BackendInfo> backends,
  ) => _names(l10n, [
    for (final backend in backends)
      if (backend.installed) backend.name,
  ]);

  /// Automatic, then [names]: the one "Automatic" of the list.
  List<DropdownMenuItem<String>> _names(AppL10n l10n, List<String> names) => [
    DropdownMenuItem(value: 'auto', child: Text(l10n.bottleGraphicsAuto)),
    for (final name in names)
      if (name != 'auto') DropdownMenuItem(value: name, child: Text(name)),
  ];
}
