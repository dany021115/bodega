import 'package:bodega/app/bloc/locale/locale_bloc.dart';
import 'package:bodega/app/shared/widgets/side_bar_item.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// L4: the side bar's language item. A tap opens a short list (System,
/// English, Español); a choice applies at once and is kept (L5).
class LanguageMenu extends StatelessWidget {
  /// The two languages by their own names, not ARB keys: each can be read
  /// whatever language is active.
  static const english = 'English';
  static const spanish = 'Español';

  final bool expanded;

  const LanguageMenu({super.key, required this.expanded});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final code = context.select((LocaleBloc bloc) => bloc.state.code);

    return MenuAnchor(
      menuChildren: [
        // null is System: the system's ordered list decides.
        for (final (value, name) in [
          (null, l10n.languageSystem),
          ('en', english),
          ('es', spanish),
        ])
          Semantics(
            inMutuallyExclusiveGroup: true,
            checked: value == code,
            child: MenuItemButton(
              leadingIcon: Icon(
                value == code ? Icons.check_rounded : null,
                size: 18,
              ),
              onPressed: () {
                if (value != code) {
                  context.read<LocaleBloc>().add(LocaleEvent.set(value));
                }
              },
              child: Text(name),
            ),
          ),
      ],
      builder: (context, controller, _) => SideBarItem(
        icon: Icons.translate_rounded,
        label: l10n.navLanguage,
        selected: false,
        expanded: expanded,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
