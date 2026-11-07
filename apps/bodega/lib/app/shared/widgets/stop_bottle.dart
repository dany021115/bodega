import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Asks first: stopping a bottle closes everything open in it.
Future<void> confirmStopBottle(BuildContext context, String bottle) async {
  final bloc = context.read<LibraryBloc>();
  final confirmed = await confirm(
    context,
    title: 'Parar la botella $bottle',
    message:
        'Se cerrará todo lo que esté abierto en la botella $bottle. '
        'Lo que no hayas guardado se perderá.',
    action: 'Parar',
  );
  if (confirmed) bloc.add(LibraryEvent.stop(bottle));
}
