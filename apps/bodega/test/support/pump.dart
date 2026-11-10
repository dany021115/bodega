import 'package:bodega/device/helpers/breakpoints.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// Wraps [home] in a `MaterialApp` with the app's text, as `main.dart` does,
/// so `context.l10n` resolves.
///
/// The locale is pinned, English unless the test passes another, so the
/// machine's language never decides what a test reads. [theme] stays
/// Material's default when null, and [breakpoints] adds the app's
/// `ResponsiveBreakpoints`, which the pages read.
Widget wrapApp(
  Widget home, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  bool breakpoints = false,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: theme,
  builder: breakpoints ? _breakpoints : null,
  home: home,
);

/// [wrapApp] for a test that drives a [GoRouter].
Widget wrapRouter(
  GoRouter router, {
  Locale locale = const Locale('en'),
  bool breakpoints = false,
}) => MaterialApp.router(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  builder: breakpoints ? _breakpoints : null,
  routerConfig: router,
);

Widget _breakpoints(BuildContext context, Widget? child) =>
    ResponsiveBreakpoints.builder(child: child!, breakpoints: appBreakpoints);
