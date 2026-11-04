import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';

class BackendsPage extends StatelessWidget {
  const BackendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyState(
        icon: Icons.memory_rounded,
        title: 'Backends',
        message: 'Esta sección llega en el siguiente hito.',
      ),
    );
  }
}
