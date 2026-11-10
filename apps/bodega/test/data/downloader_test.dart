import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bytes = Uint8List.fromList(
    List.generate(300 * 1024, (index) => index % 251),
  );
  late Directory dir;
  late HttpServer server;
  late Downloader downloader;
  late String url;
  late String dest;
  // What the server does with each request; by default, honours Range.
  late Future<void> Function(HttpRequest request) handler;
  String? lastRange;

  Future<void> honourRange(HttpRequest request) async {
    final range = request.headers.value('range');
    final start = range == null
        ? 0
        : int.parse(range.substring(6, range.length - 1));
    request.response
      ..statusCode = range == null ? 200 : 206
      ..contentLength = bytes.length - start
      ..add(bytes.sublist(start));
    await request.response.close();
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('bodega-download');
    dest = '${dir.path}/setup.exe';
    handler = honourRange;
    lastRange = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      lastRange = request.headers.value('range');
      handler(request);
    });
    url = 'http://127.0.0.1:${server.port}/setup.exe';
    downloader = Downloader(Dio())..httpsOnly = false;
  });

  tearDown(() async {
    await server.close(force: true);
    dir.deleteSync(recursive: true);
  });

  test('downloads whole, with progress up to the total', () async {
    final seen = <(int, int?)>[];

    final path = await downloader.fetch(
      url,
      dest,
      cancel: CancelToken(),
      onProgress: (received, total) => seen.add((received, total)),
    );

    expect(path, dest);
    expect(File(dest).readAsBytesSync(), bytes);
    expect(File('$dest.part').existsSync(), isFalse);
    expect(seen.last, (bytes.length, bytes.length));
    expect(lastRange, isNull);
  });

  test('resumes a .part with Range, counting what it had', () async {
    File('$dest.part').writeAsBytesSync(bytes.sublist(0, 1000));
    final seen = <(int, int?)>[];

    await downloader.fetch(
      url,
      dest,
      cancel: CancelToken(),
      onProgress: (received, total) => seen.add((received, total)),
    );

    expect(lastRange, 'bytes=1000-');
    expect(File(dest).readAsBytesSync(), bytes);
    expect(seen.last, (bytes.length, bytes.length));
  });

  test('a server that ignores Range starts over from zero', () async {
    File('$dest.part').writeAsBytesSync(List.filled(1000, 9));
    handler = (request) async {
      request.response
        ..contentLength = bytes.length
        ..add(bytes);
      await request.response.close();
    };

    await downloader.fetch(url, dest, cancel: CancelToken());

    expect(lastRange, 'bytes=1000-');
    expect(File(dest).readAsBytesSync(), bytes);
  });

  test('416 throws the leftover away and downloads again', () async {
    File('$dest.part').writeAsBytesSync(List.filled(bytes.length + 5, 9));
    handler = (request) async {
      if (request.headers.value('range') != null) {
        request.response.statusCode = 416;
        await request.response.close();
        return;
      }
      await honourRange(request);
    };

    await downloader.fetch(url, dest, cancel: CancelToken());

    expect(File(dest).readAsBytesSync(), bytes);
  });

  test(
    'asks for raw bytes, so that sizes and Range mean what they say',
    () async {
      String? asked;
      handler = (request) async {
        asked = request.headers.value('accept-encoding');
        await honourRange(request);
      };

      await downloader.fetch(url, dest, cancel: CancelToken());

      expect(asked, 'identity');
      expect(File(dest).readAsBytesSync(), bytes);
    },
  );

  test('a server that compresses anyway is not taken for a cut', () async {
    final compressed = gzip.encode(bytes);
    handler = (request) async {
      request.response
        ..headers.set('content-encoding', 'gzip')
        ..contentLength = compressed.length
        ..add(compressed);
      await request.response.close();
    };

    await downloader.fetch(url, dest, cancel: CancelToken());

    expect(File(dest).readAsBytesSync(), bytes);
  });

  // Dart's server holds small writes back, so these two use the raw socket.
  Future<Socket> sendPart(HttpRequest request) async {
    request.response.contentLength = bytes.length;
    final socket = await request.response.detachSocket();
    socket.add(bytes.sublist(0, 1000));
    await socket.flush();
    return socket;
  }

  test('cancelling returns null and removes the .part', () async {
    final hold = Completer<void>();
    handler = (request) async {
      final socket = await sendPart(request);
      await hold.future;
      socket.destroy();
    };
    final cancel = CancelToken();

    final path = await downloader.fetch(
      url,
      dest,
      cancel: cancel,
      onProgress: (_, _) => cancel.cancel(),
    );
    hold.complete();

    expect(path, isNull);
    expect(File('$dest.part').existsSync(), isFalse);
    expect(File(dest).existsSync(), isFalse);
  });

  test('a cut download fails and keeps the .part to resume', () async {
    handler = (request) async => (await sendPart(request)).destroy();

    await expectLater(
      downloader.fetch(url, dest, cancel: CancelToken()),
      throwsA(anything),
    );

    expect(File(dest).existsSync(), isFalse);
    expect(File('$dest.part').lengthSync(), 1000);
  });

  test('refuses what is not HTTPS, without asking', () async {
    downloader.httpsOnly = true;

    await expectLater(
      downloader.fetch(url, dest, cancel: CancelToken()),
      throwsA(isA<DownloadNotHttpsError>()),
    );

    expect(lastRange, isNull);
    expect(File('$dest.part').existsSync(), isFalse);
  });

  test('refuses a redirect out of HTTPS, writing nothing', () async {
    final strict = Downloader(
      Dio()
        ..httpClientAdapter = _FakeAdapter([
          RedirectRecord(302, 'GET', Uri.parse('http://evil.example/setup')),
        ]),
    );

    await expectLater(
      strict.fetch('https://a.example/setup', dest, cancel: CancelToken()),
      throwsA(isA<DownloadNotHttpsError>()),
    );

    expect(File('$dest.part').existsSync(), isFalse);
  });

  test('a redirect that stays in HTTPS is fine', () async {
    final strict = Downloader(
      Dio()
        ..httpClientAdapter = _FakeAdapter([
          RedirectRecord(302, 'GET', Uri.parse('https://cdn.example/setup')),
        ]),
    );

    await strict.fetch('https://a.example/setup', dest, cancel: CancelToken());

    expect(File(dest).readAsStringSync(), 'exe');
  });
}

class _FakeAdapter implements HttpClientAdapter {
  final List<RedirectRecord> redirects;

  _FakeAdapter(this.redirects);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString('exe', 200, isRedirect: true)
        ..redirects = redirects;

  @override
  void close({bool force = false}) {}
}
