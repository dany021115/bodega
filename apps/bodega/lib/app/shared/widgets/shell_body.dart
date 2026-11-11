import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/switch/switch_bloc.dart';
import 'package:bodega/app/bloc/update/update_bloc.dart';
import 'package:bodega/app/shared/text/error_text.dart';
import 'package:bodega/app/shared/text/hint_text.dart';
import 'package:bodega/app/shared/text/switch_text.dart';
import 'package:bodega/app/shared/widgets/install_panel.dart';
import 'package:bodega/app/shared/widgets/update_dialog.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The section, the installation panel, and what the global blocs announce.
class ShellBody extends StatelessWidget {
  final Widget child;

  const ShellBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // A3: a newer version opens its dialog once.
        BlocListener<UpdateBloc, UpdateState>(
          listenWhen: (previous, current) =>
              previous.update == null && current.update != null,
          listener: (context, state) => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const UpdateDialog(),
          ),
        ),
        BlocListener<LibraryBloc, LibraryState>(
          listenWhen: (previous, current) =>
              previous.toastId != current.toastId,
          listener: (context, state) {
            if (state.toast case final hint?) {
              AppToast.warning(context, hint.localized(context.l10n));
            }
          },
        ),
        BlocListener<LibraryBloc, LibraryState>(
          listenWhen: (previous, current) =>
              current.error != null && previous.error != current.error,
          listener: (context, state) =>
              AppToast.error(context, state.error!.localized(context.l10n)),
        ),
        // switch-support SA12: what an add found, and a game that ended
        // badly, wherever the user is when it happens.
        BlocListener<SwitchBloc, SwitchState>(
          listenWhen: (previous, current) =>
              previous.noticeId != current.noticeId,
          listener: (context, state) {
            if (state.notice case final notice?) {
              final text = switchNoticeText(context.l10n, notice);
              switch (notice) {
                case SwitchAddedNotice():
                  AppToast.success(context, text);
                case SwitchExitedNotice():
                  AppToast.warning(context, text);
              }
            }
          },
        ),
        // The bloc clears its error before each call, so the same failure
        // twice toasts twice.
        BlocListener<SwitchBloc, SwitchState>(
          listenWhen: (previous, current) =>
              current.error != null && previous.error != current.error,
          listener: (context, state) =>
              AppToast.error(context, state.error!.localized(context.l10n)),
        ),
        BlocListener<InstallBloc, InstallState>(
          listenWhen: (previous, current) =>
              previous.phase != current.phase &&
              (current.phase == InstallPhase.done ||
                  current.phase == InstallPhase.idle),
          listener: (context, state) {
            context.read<BottlesBloc>().add(const BottlesEvent.load());
            context.read<CatalogBloc>().add(const CatalogEvent.load());
            context.read<LibraryBloc>().add(const LibraryEvent.load());
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: child),
          const InstallPanel(),
        ],
      ),
    );
  }
}
