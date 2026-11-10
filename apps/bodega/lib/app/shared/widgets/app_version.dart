import 'package:bodega/l10n/l10n.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The version the running app was built with, read from the app itself.
class AppVersion extends StatelessWidget {
  static final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  /// Just `v1.2.3`, for the narrow sidebar.
  final bool compact;

  const AppVersion({super.key, required this.compact});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        // Nothing until it is known, and nothing if the platform can't say.
        final version = snapshot.data?.version;
        if (version == null) return const SizedBox.shrink();

        return Text(
          compact ? 'v$version' : context.l10n.shellVersion(version),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle(context).caption,
        );
      },
    );
  }
}
