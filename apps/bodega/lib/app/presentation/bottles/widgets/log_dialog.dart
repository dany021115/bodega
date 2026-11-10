import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> showLogDialog(BuildContext context, String name, String path) {
  final bloc = context.read<BottleDetailBloc>()
    ..add(BottleDetailEvent.openLog(path));
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: LogDialog(name: name),
    ),
  );
}

/// The last lines of a log. They don't fit in the bottle's column.
class LogDialog extends StatelessWidget {
  final String name;

  const LogDialog({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final size = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: Container(
        width: size.width * 0.8,
        height: size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: AppRadius.xsBorder,
        ),
        child: BlocBuilder<BottleDetailBloc, BottleDetailState>(
          buildWhen: (previous, current) =>
              previous.logLines != current.logLines,
          builder: (context, state) {
            if (state.logLines.isEmpty) return const CustomLoading();
            return SelectionArea(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: state.logLines.length,
                itemBuilder: (context, index) =>
                    Text(state.logLines[index], style: styles.mono),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonClose),
        ),
      ],
    );
  }
}
