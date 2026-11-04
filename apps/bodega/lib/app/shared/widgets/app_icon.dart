import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/resources/assets_catalog_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The app's logo by catalog id, or the initial of its title if it is the
/// user's own.
class AppIcon extends StatelessWidget {
  final String id;
  final String title;
  final double size;

  const AppIcon({
    super.key,
    required this.id,
    required this.title,
    this.size = 48,
  });

  // Epic's 313131 counts as black: it would not show on the dark theme.
  static const Map<String, (String, Color?)> _logos = {
    'steam': (AssetsCatalogIcons.steam, null),
    'rockstar': (AssetsCatalogIcons.rockstargames, AppColor.brandRockstar),
    'ea-app': (AssetsCatalogIcons.ea, null),
    'ubisoft-connect': (AssetsCatalogIcons.ubisoft, null),
    'battle-net': (AssetsCatalogIcons.battledotnet, AppColor.brandBattleNet),
    'epic-games': (AssetsCatalogIcons.epicgames, null),
    'gog-galaxy': (AssetsCatalogIcons.gogdotcom, AppColor.brandGog),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final logo = _logos[id];

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: AppRadius.smBorder,
        ),
        child: logo == null
            ? Text(
                title.isEmpty ? '?' : title.characters.first.toUpperCase(),
                style: AppTextStyle(context).sectionTitle,
              )
            : SvgPicture.asset(
                logo.$1,
                width: size * 0.56,
                height: size * 0.56,
                colorFilter: ColorFilter.mode(
                  _paint(logo.$2, colors.onSurface, theme.brightness),
                  BlendMode.srcIn,
                ),
              ),
      ),
    );
  }

  Color _paint(Color? brand, Color fallback, Brightness brightness) {
    if (brand == null) return fallback;
    return brightness == Brightness.dark
        ? Color.lerp(brand, Colors.white, 0.25)!
        : brand;
  }
}
