import 'package:bodega/l10n/l10n.dart';

/// MB of 10^6 bytes, as Finder and GNOME Files count.
double _mb(int bytes) => bytes / 1000000;

/// The progress of a download: an app's installer, an update or a backend.
/// Without a total, only what has arrived.
String downloadProgressText(
  AppL10n l10n, {
  required int received,
  int? total,
}) => total == null || total <= 0
    ? l10n.downloadProgressNoTotal(_mb(received))
    : l10n.downloadProgress(received / total, _mb(received), _mb(total));
