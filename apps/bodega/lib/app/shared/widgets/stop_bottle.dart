import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Asks first: stopping a bottle closes everything open in it.
Future<void> confirmStopBottle(BuildContext context, String bottle) async {
  final bloc = context.read<LibraryBloc>();
  final l10n = context.l10n;
  final confirmed = await confirm(
    context,
    title: l10n.bottleStopTitle(bottle),
    message: l10n.bottleStopConfirm(bottle),
    action: l10n.commonStop,
  );
  if (confirmed) bloc.add(LibraryEvent.stop(bottle));
}
