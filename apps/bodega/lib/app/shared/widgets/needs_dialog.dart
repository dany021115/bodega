import 'package:bodega/app/bloc/dependencies/dependencies_bloc.dart';
import 'package:bodega/app/shared/text/dependency_text.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/dependency.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the dialog of what [needs] proposes for one app of [bottle], its
/// recommended items checked, or, with [all] instead, every runtime of the
/// bottle not installed yet, none checked (DA5).
Future<void> showNeedsDialog(
  BuildContext context, {
  required String bottle,
  AppNeeds? needs,
  List<Dependency>? all,
}) => showDialog<void>(
  context: context,
  builder: (_) => BlocProvider.value(
    value: context.read<DependenciesBloc>(),
    child: NeedsDialog(bottle: bottle, needs: needs, all: all),
  ),
);

/// One line of the dialog: a runtime of [need] or of [dependency] (by hand),
/// or a [setting].
typedef _Option = ({
  NeedItem item,
  DependencyNeed? need,
  Dependency? dependency,
  SettingNeed? setting,
});

class NeedsDialog extends StatefulWidget {
  final String bottle;
  final AppNeeds? needs;
  final List<Dependency>? all;

  const NeedsDialog({super.key, required this.bottle, this.needs, this.all});

  @override
  State<NeedsDialog> createState() => _NeedsDialogState();
}

class _NeedsDialogState extends State<NeedsDialog> {
  late final List<_Option> _options;
  late final Set<NeedItem> _checked;

  @override
  void initState() {
    super.initState();
    final needs = widget.needs;
    _options = needs == null
        ? [
            for (final dependency in widget.all ?? const <Dependency>[])
              if (!dependency.installed)
                (
                  item: NeedItem.runtime(dependency.id, dependency.arch),
                  need: null,
                  dependency: dependency,
                  setting: null,
                ),
          ]
        : [
            for (final need in needs.dependencies)
              if (!need.dependency.installed)
                (
                  item: NeedItem.runtime(
                    need.dependency.id,
                    need.dependency.arch,
                  ),
                  need: need,
                  dependency: need.dependency,
                  setting: null,
                ),
            for (final setting in needs.settings)
              if (setting.state == SettingState.notApplied)
                (
                  item: NeedItem.settings(setting.fix),
                  need: null,
                  dependency: null,
                  setting: setting,
                ),
          ];
    // Recommended runtimes and settings start checked; optional ones and the
    // list by hand do not.
    _checked = {
      for (final option in _options)
        if (option.need?.need == Need.recommended || option.setting != null)
          option.item,
    };
  }

  Widget _subtitle(AppL10n l10n, AppTextStyle styles, _Option option) {
    final need = option.setting != null ? Need.recommended : option.need?.need;
    final reason = option.setting != null
        ? l10n.fixReason(option.setting!.fix)
        : option.need == null
        ? null
        : l10n.reasonOf(option.need!);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (need != null)
            StatusChip(
              label: l10n.needOf(need),
              color: need == Need.recommended
                  ? AppColor.statusTested
                  : AppColor.statusUntested,
            ),
          if (reason != null) Text(reason, style: styles.caption),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final needs = widget.needs;

    return AlertDialog(
      title: Text(
        needs == null ? l10n.depsDialogAll : l10n.depsDialogFor(needs.title),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_options.isEmpty)
                Text(l10n.depsDialogNone, style: styles.bodySecondary),
              for (final option in _options)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _checked.contains(option.item),
                  onChanged: (value) => setState(
                    () => value == true
                        ? _checked.add(option.item)
                        : _checked.remove(option.item),
                  ),
                  title: Text(
                    option.setting != null
                        ? l10n.settingLine(option.setting!)
                        : l10n.dependencyLine(option.dependency!),
                  ),
                  subtitle: option.need == null && option.setting == null
                      ? null
                      : _subtitle(l10n, styles, option),
                ),
              if (_options.any((option) => option.item is RuntimeItem)) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.depsWholeBottle, style: styles.caption),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.depsNotNow),
        ),
        FilledButton(
          onPressed: _checked.isEmpty
              ? null
              : () {
                  context.read<DependenciesBloc>().add(
                    DependenciesEvent.install(widget.bottle, [
                      for (final option in _options)
                        if (_checked.contains(option.item)) option.item,
                    ]),
                  );
                  Navigator.of(context).pop();
                },
          child: Text(l10n.commonInstall),
        ),
      ],
    );
  }
}
