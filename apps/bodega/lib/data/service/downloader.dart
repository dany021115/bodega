import 'dart:io';

import 'package:bodega/domain/entities/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// HTTPS downloads to `<dest>.part`, resumable, with progress (design §4). It
/// streams by hand instead of `dio.download` to see the status and the final
/// URL before writing anything.
@lazySingleton
class Downloader {
  final Dio _dio;

  Downloader(this._dio);

  @visibleForTesting
  bool httpsOnly = true;

  /// Returns [dest], or null if [cancel] fired, which removes the `.part`. Any
  /// other failure leaves it, for the next attempt to resume.
  // ponytail: no If-Range; a file changed on the server between two attempts
  // ends up mixed. Installers without a checksum would fail when run; send the
  // saved ETag if that ever shows up.
  Future<String?> fetch(
    String url,
    String dest, {
    required CancelToken cancel,
    void Function(int received, int? total)? onProgress,
  }) async {
    _requireHttps(Uri.parse(url));
    final part = File('$dest.part');
    part.parent.createSync(recursive: true);
    final offset = part.existsSync() ? part.lengthSync() : 0;

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            // Range and Content-Length count raw bytes; compressed by the
            // server, they would count something else.
            'accept-encoding': 'identity',
            if (offset > 0) 'range': 'bytes=$offset-',
          },
          validateStatus: (status) =>
              status == 200 || status == 206 || status == 416,
        ),
      );
      _requireHttps(response.realUri);

      // The leftover is already whole, or longer than the file now is.
      if (response.statusCode == 416) {
        part.deleteSync();
        return await fetch(url, dest, cancel: cancel, onProgress: onProgress);
      }

      // A server that ignores Range answers 200: from zero (design §4).
      final resumed = response.statusCode == 206;
      final compressed = response.headers.value('content-encoding') != null;
      final length = compressed
          ? null
          : int.tryParse(
              response.headers.value(Headers.contentLengthHeader) ?? '',
            );
      var received = resumed ? offset : 0;
      final total = length == null ? null : received + length;

      final sink = part.openWrite(
        mode: resumed ? FileMode.append : FileMode.write,
      );
      try {
        await for (final chunk in response.data!.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.close();
      }

      if (total != null && received != total) {
        throw AppError.downloadCut(received, total);
      }
      part.renameSync(dest);
      return dest;
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) rethrow;
      if (part.existsSync()) part.deleteSync();
      return null;
    }
  }

  /// The app asks only for HTTPS: anything else, a redirect included, is
  /// refused before a byte is written.
  void _requireHttps(Uri uri) {
    if (httpsOnly && uri.scheme != 'https') {
      throw AppError.unknown(detail: 'not an HTTPS download: $uri');
    }
  }
}
