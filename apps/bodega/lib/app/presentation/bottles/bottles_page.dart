import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';

class BottlesPage extends StatelessWidget {
  const BottlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyState(
        icon: Icons.wine_bar_rounded,
        title: 'Botellas',
        message: 'Esta sección llega en el siguiente hito.',
      ),
    );
  }
}
