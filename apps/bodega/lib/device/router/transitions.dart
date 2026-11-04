import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PageTransitions {
  static CustomTransitionPage<void> fadeTransition({
    required Widget child,
    required GoRouterState state,
    Duration duration = const Duration(milliseconds: 180),
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.name,
      child: child,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}
