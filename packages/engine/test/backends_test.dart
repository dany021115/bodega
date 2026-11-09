import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';
import 'engine_test.dart' show fakeRuntime;

/// A pinned-style tarball: one top folder holding the layer.
Future<(String, String)> fakeLayer(String dir, List<String> files) async {
  for (final file in files) {
    File('$dir/src/v9/$file').createSync(recursive: true);
  }
  final tarball = '$dir/layer.tar.gz';
  await Process.run('/usr/bin/tar', ['-czf', tarball, '-C', '$dir/src', 'v9']);
  return (tarball, (await sha256Line(tarball)).split(' ').first);
}

/// A D3DMetal folder in the `wine/+external/` layout, under [root].
void fakeD3DMetal(String root, {List<String> skip = const []}) {
  for (final file in [
    for (final m in ['d3d11', 'd3d12', 'dxgi', 'nvngx']) ...[
      'wine/x86_64-windows/$m.dll',
      'wine/x86_64-unix/$m.so',
    ],
    'external/libd3dshared.dylib',
    'external/D3DMetal.framework/D3DMetal',
  ]) {
    if (!skip.contains(file)) File('$root/$file').createSync(recursive: true);
  }
}

/// A file with just enough PE header, plus [text].
File fakePe(String path, int machine, String text) {
  final header = ByteData(70)
    ..setUint8(0, 0x4D)
    ..setUint8(1, 0x5A)
    ..setUint32(60, 64, Endian.little)
    ..setUint8(64, 0x50)
    ..setUint8(65, 0x45)
    ..setUint16(68, machine, Endian.little);
  return File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync([...header.buffer.asUint8List(), ...text.codeUnits]);
}

void install(String home, String name) =>
    Directory('$home/backends/$name/wine').createSync(recursive: true);

void main() {
  useMac();
  late String tmp, home;
  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
  });
  tearDown(() => Directory(tmp).deleteSync(recursive: true));

  test('backendEnv', () {
    const base = 'winemenubuilder.exe=d';
    final layer = '$home/backends';
    expect(backendEnv(home, 'wine'), {'CX_ACTIVE_GRAPHICS_BACKEND': 'wined3d'});
    expect(backendEnv(home, 'dxmt'), {
      'CX_ACTIVE_GRAPHICS_BACKEND': 'dxmt',
      'WINEDLLPATH_PREPEND': '$layer/dxmt/wine',
      'DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN': '1',
    });
    expect(backendEnv(home, 'dxvk'), {
      'CX_ACTIVE_GRAPHICS_BACKEND': 'dxvk',
      'WINEDLLPATH_PREPEND': '$layer/dxvk/wine',
      'WINEDLLOVERRIDES': '$base;d3d10core,d3d11=n,b',
    });
    final d3dmetal = {
      'CX_ACTIVE_GRAPHICS_BACKEND': 'd3dmetal',
      'WINEDLLPATH_PREPEND': '$layer/d3dmetal/wine',
      'CX_APPLEGPTK_LIBD3DSHARED_PATH':
          '$layer/d3dmetal/external/libd3dshared.dylib',
    };
    expect(backendEnv(home, 'd3dmetal'), d3dmetal);
    install(home, 'dxmt');
    expect(backendEnv(home, 'd3dmetal'), {
      ...d3dmetal,
      'WINEDLLPATH_PREPEND': '$layer/d3dmetal/wine:$layer/dxmt/wine',
      'DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN': '1',
    });
    expect(backendEnv(home, 'wine', hud: true)['MTL_HUD_ENABLED'], '1');
    for (final name in backendNames) {
      expect(
        backendEnv(home, name).keys.where((k) => k.startsWith('DYLD')),
        isEmpty,
      );
    }
    expect(pinnedBackend('dxmt')!.url, contains('dxmt-highball'));
    expect(pinnedBackend('dxmt')!.sha256, startsWith('89e731b8'));
    expect(pinnedBackend('d3dmetal'), isNull);
    final env = wineEnv('/p', const {}, backendEnv(home, 'dxvk'));
    expect(env['WINEDLLOVERRIDES'], startsWith(base));
    expect(env['WINEPREFIX'], '/p');
  });

  test('installBackend', () async {
    final (tarball, sum) = await fakeLayer(tmp, [
      'x86_64-windows/d3d11.dll',
      'i386-windows/d3d11.dll',
      'x86_64-unix/winemetal.so',
    ]);
    List<String> slots() => [
      for (final e in Directory('$home/backends').listSync())
        e.path.split('/').last,
    ];

    await expectLater(
      installBackend(home, 'dxmt', tarball: tarball, sha256: '0' * 64),
      throwsA(contains('checksum incorrecto')),
    );
    expect(Directory('$home/backends/dxmt').existsSync(), isFalse);

    final dest = await installBackend(
      home,
      'dxmt',
      tarball: tarball,
      sha256: sum,
    );
    expect(dest, '$home/backends/dxmt');
    for (final file in [
      'x86_64-windows/d3d11.dll',
      'i386-windows/d3d11.dll',
      'x86_64-unix/winemetal.so',
    ]) {
      expect(File('$dest/wine/$file').existsSync(), isTrue, reason: file);
    }
    expect(slots(), ['dxmt']);
    await expectLater(
      installBackend(home, 'dxmt', tarball: tarball, sha256: sum),
      throwsA(contains('ya instalado')),
    );

    // A file:// download, then again from the finished file.
    final viaUrl = await installBackend(
      home,
      'dxvk',
      url: 'file://$tarball',
      sha256: sum,
    );
    expect(File('$viaUrl/wine/i386-windows/d3d11.dll').existsSync(), isTrue);
    File(tarball).deleteSync();
    Directory(viaUrl).deleteSync(recursive: true);
    await installBackend(home, 'dxvk', url: 'file://$tarball', sha256: sum);

    final bad = await fakeLayer('$tmp/bad', ['x86_64-windows/other.dll']);
    await expectLater(
      installBackend(home, 'dxvk2', tarball: bad.$1, sha256: bad.$2),
      throwsA(contains('sin instalador')),
    );
    Directory('$home/backends/dxvk').deleteSync(recursive: true);
    await expectLater(
      installBackend(home, 'dxvk', tarball: bad.$1, sha256: bad.$2),
      throwsA(contains('sin x86_64-windows/d3d11.dll')),
    );
    expect(slots(), ['dxmt']);
    await expectLater(
      installBackend(home, 'd3dmetal'),
      throwsA(contains('backend import d3dmetal')),
    );
  });

  test('importD3DMetal', () async {
    fakeD3DMetal('$tmp/ok');
    final dest = await importD3DMetal(home, '$tmp/ok');
    final unix = '$dest/wine/x86_64-unix';
    expect(File('$dest/external/libd3dshared.dylib').existsSync(), isTrue);
    expect(
      File('$dest/external/D3DMetal.framework/D3DMetal').existsSync(),
      isTrue,
    );
    // The fake source has plain files: the links are rebuilt anyway.
    for (final module in ['d3d11', 'd3d12', 'dxgi', 'nvngx']) {
      expect(
        Link('$unix/$module.so').targetSync(),
        '../../external/libd3dshared.dylib',
      );
    }
    expect(File('$unix/d3d12.so').existsSync(), isTrue);
    expect(File('$dest/wine/x86_64-windows/d3d12.dll').existsSync(), isTrue);
    await expectLater(
      importD3DMetal(home, '$tmp/ok'),
      throwsA(contains('ya instalado')),
    );
    Directory(dest).deleteSync(recursive: true);

    fakeD3DMetal('$tmp/whisky/lib');
    await importD3DMetal(home, '$tmp/whisky');
    expect(File('$dest/external/libd3dshared.dylib').existsSync(), isTrue);
    expect(
      Link('$dest/wine/x86_64-unix/d3d12.so').targetSync(),
      '../../external/libd3dshared.dylib',
    );
    Directory(dest).deleteSync(recursive: true);

    fakeD3DMetal('$tmp/CrossOver.app/Contents/gptk');
    Link('$tmp/link').createSync('$tmp/CrossOver.app/Contents/gptk');
    for (final path in ['$tmp/CrossOver.app/Contents/gptk', '$tmp/link']) {
      await expectLater(
        importD3DMetal(home, path),
        throwsA(contains('CrossOver.app')),
        reason: path,
      );
    }
    fakeD3DMetal('$tmp/other');
    File('$tmp/other/wine/x86_64-unix/dxgi.so').writeAsStringSync('otra');
    await expectLater(
      importD3DMetal(home, '$tmp/other'),
      throwsA(contains('no es la misma biblioteca')),
    );
    fakeD3DMetal('$tmp/hole', skip: ['wine/x86_64-windows/d3d12.dll']);
    await expectLater(
      importD3DMetal(home, '$tmp/hole'),
      throwsA(contains('d3d12.dll')),
    );
    expect(Directory(dest).existsSync(), isFalse);
    expect(Directory('$home/backends/.tmp-d3dmetal').existsSync(), isFalse);
  });

  test('settings', () async {
    final dir = '$home/bottles/t';
    Directory(dir).createSync();
    final program = fakePe('$tmp/Blur.exe', 0x14C, 'nada').path;
    Future<String> origin() async {
      final c = await resolveBackend(home, dir, program, program);
      return '${c.name} ${c.origin}';
    }

    expect(await origin(), 'wine auto');
    install(home, 'dxmt');
    setBackend(home, 't', 'dxmt', exe: 'Blur.exe');
    expect(File('$dir/settings.json').readAsStringSync(), contains('blur.exe'));
    expect(await origin(), 'dxmt exe');
    setBackend(home, 't', 'wine');
    expect(await origin(), 'dxmt exe');
    setBackend(home, 't', 'auto', exe: r'C:\x\BLUR.EXE');
    expect(await origin(), 'wine botella');

    final before = File('$dir/settings.json').readAsStringSync();
    expect(() => setBackend(home, 't', 'foo'), throwsA(contains('foo')));
    expect(File('$dir/settings.json').readAsStringSync(), before);
    expect(() => setBackend(home, 'nope', 'wine'), throwsA(contains('nope')));

    File('$dir/settings.json').writeAsStringSync('{roto');
    await expectLater(origin(), throwsA(contains('settings.json')));
    File('$dir/settings.json').writeAsStringSync('{"backend":"foo"}');
    await expectLater(origin(), throwsA(contains('settings.json')));
    File('$dir/settings.json').writeAsStringSync('{"sync":"foo"}');
    await expectLater(origin(), throwsA(contains('settings.json')));

    // A2: an exception goes, but the program's variables stay.
    File('$dir/settings.json').writeAsStringSync(
      '{"backend":"wine","programs":{"blur.exe":'
      '{"backend":"dxmt","env":{"FOO":"1"}},"a.exe":{"backend":"dxmt"}}}',
    );
    setBackend(home, 't', 'auto', exe: 'Blur.exe');
    setBackend(home, 't', 'auto', exe: 'a.exe');
    final kept = jsonDecode(File('$dir/settings.json').readAsStringSync());
    expect(kept['programs'], {
      'blur.exe': {
        'env': {'FOO': '1'},
      },
    });
    setBackend(home, 't', 'dxmt', exe: 'blur.exe');
    expect(await origin(), 'dxmt exe');
    final both = jsonDecode(File('$dir/settings.json').readAsStringSync());
    expect(both['programs']['blur.exe']['env'], {'FOO': '1'});

    // A1: a change stops the bottle first; the same value touches nothing.
    final (engine, hostlibs) = await fakeRuntime(tmp, 'engine-s');
    await installRuntime(home, engine, hostlibs);
    Directory('$dir/prefix').createSync();
    final server = File('$dir/prefix/server.log');
    expect(await setSync(home, 't', 'msync'), isFalse);
    expect(server.existsSync(), isFalse);
    expect(await setSync(home, 't', 'none'), isTrue);
    expect(server.readAsStringSync(), contains('k'));
    final saved = jsonDecode(File('$dir/settings.json').readAsStringSync());
    expect(saved['sync'], 'none');
    expect(saved['backend'], 'wine');
    expect(saved['programs']['blur.exe']['backend'], 'dxmt');
    final read = bottleSettings(home, 't');
    expect(read.sync, 'none');
    expect(read.backend, 'wine');
    expect(read.programs['blur.exe']?.env, {'FOO': '1'});
    await expectLater(setSync(home, 't', 'foo'), throwsA(contains('foo')));
    expect(
      jsonDecode(File('$dir/settings.json').readAsStringSync())['sync'],
      'none',
    );
  });

  test('resolve', () async {
    final dir = '$home/bottles/t';
    Directory(dir).createSync();
    for (final name in ['dxmt', 'dxvk']) {
      install(home, name);
    }
    final x = fakePe('$tmp/x.exe', 0x8664, 'nada').path;
    Future<String> pick({String? option}) async {
      final c = await resolveBackend(home, dir, x, x, option: option);
      return '${c.name} ${c.origin}';
    }

    setBackend(home, 't', 'dxvk');
    setBackend(home, 't', 'dxmt', exe: 'x.exe');
    expect(await pick(option: 'wine'), 'wine opcion');
    expect(await pick(), 'dxmt exe');
    setBackend(home, 't', 'auto', exe: 'x.exe');
    expect(await pick(), 'dxvk botella');
    expect(await pick(option: 'auto'), 'wine auto');
    setBackend(home, 't', 'auto');
    expect(await pick(), 'wine auto');

    await expectLater(
      pick(option: 'd3dmetal'),
      throwsA(contains('bodega backend import d3dmetal')),
    );
    Directory('$home/backends/dxvk').deleteSync(recursive: true);
    setBackend(home, 't', 'dxvk');
    await expectLater(pick(), throwsA(contains('bodega backend install dxvk')));
    setBackend(home, 't', 'auto');
    install(home, 'dxvk');

    Future<String> auto(int machine, String text) async {
      final exe = fakePe('$tmp/a.exe', machine, text).path;
      return (await resolveBackend(home, dir, exe, exe)).name;
    }

    expect(await auto(0x8664, 'x D3D12.DLL y'), 'wine');
    install(home, 'd3dmetal');
    expect(await auto(0x8664, 'x D3D12.DLL y'), 'd3dmetal');
    expect(await auto(0x14C, 'x d3d12.dll y'), 'wine');
    expect(await auto(0x14C, 'x d3d11.dll y'), 'dxmt');
    expect(await auto(0x8664, 'x DXGI.dll y'), 'dxmt');
    expect(
      await auto(0x8664, 'd\x003\x00d\x001\x001\x00.\x00d\x00l\x00l'),
      'dxmt',
    );
    Directory('$home/backends/dxmt').deleteSync(recursive: true);
    expect(await auto(0x8664, 'x d3d10.dll y'), 'dxvk');
    expect(await auto(0x8664, 'sin nada'), 'wine');
    // A4: D3D9 games that mention newer DLLs.
    install(home, 'dxmt');
    expect(await auto(0x14C, 'd3d9.dll d3d10 dxgi.dll'), 'wine');
    expect(await auto(0x8664, 'd3d9.dll d3d11.dll'), 'dxmt');
    expect(await auto(0x8664, 'solo d3d10.dll'), 'dxmt');
    final notPe = File('$tmp/n.exe')..writeAsStringSync('d3d12.dll');
    expect(
      (await resolveBackend(home, dir, notPe.path, notPe.path)).name,
      'wine',
    );
    expect((await resolveBackend(home, dir, 'notepad', null)).name, 'wine');
  });

  test('exeGraphics and backendFits (G1, G3)', () async {
    Future<String> read(int machine, String text) async {
      final g = await exeGraphics(fakePe('$tmp/g.exe', machine, text).path);
      return g == null ? 'nada' : '${g.directx} ${g.bits}';
    }

    // Blur: D3D9 that probes d3d10 and dxgi.
    expect(await read(0x14C, 'd3d9.dll d3d10 dxgi.dll'), 'DX9 32');
    expect(await read(0x8664, 'x D3D12.DLL d3d11.dll'), 'DX12 64');
    expect(
      await read(0x8664, 'd\x003\x00d\x001\x001\x00.\x00d\x00l\x00l'),
      'DX11 64',
    );
    expect(await read(0x14C, 'solo dxgi.dll'), 'DX10 32');
    expect(await read(0x14C, 'opengl32.dll'), ' 32');
    expect(await exeGraphics('$tmp/no.exe'), isNull);
    File('$tmp/n.exe').writeAsStringSync('d3d12.dll');
    expect(await exeGraphics('$tmp/n.exe'), isNull);

    bool fits(String backend, int bits, String directx) =>
        hostPlatform.backendFits(backend, (bits: bits, directx: directx));
    expect(fits('d3dmetal', 32, 'DX9'), isFalse);
    expect(fits('d3dmetal', 32, 'DX11'), isFalse);
    expect(fits('d3dmetal', 64, 'DX12'), isTrue);
    expect(fits('dxmt', 64, 'DX12'), isFalse);
    expect(fits('dxvk', 32, 'DX9'), isFalse);
    expect(fits('dxvk', 32, 'DX10'), isTrue);
    expect(fits('wine', 32, 'DX9'), isTrue);
    expect(fits('d3dmetal', 32, ''), isTrue);
  });

  test('findGptkDmg picks the newest finished dmg (I2)', () async {
    final dir = Directory('$tmp/descargas')..createSync();
    expect(await findGptkDmg('3.0', dir.path), isNull);
    File('${dir.path}/Game_Porting_Toolkit_3.0.dmg')
      ..writeAsStringSync('viejo')
      ..setLastModifiedSync(DateTime(2025));
    File('${dir.path}/Game_Porting_Toolkit_3.0 (1).dmg').writeAsStringSync('');
    File('${dir.path}/Game_Porting_Toolkit_3.0.dmg.crdownload')
        .writeAsStringSync('');
    File('${dir.path}/Game_Porting_Toolkit_4.0_beta_2.dmg')
        .writeAsStringSync('');
    expect(await findGptkDmg('3.0', dir.path), endsWith('3.0 (1).dmg'));
    expect(await findGptkDmg('4.0', dir.path), endsWith('4.0_beta_2.dmg'));
    expect(gptkReleases.where((r) => r.tested).single.version, '3.0');
  });

  test('d3dmetalVersion reads the framework (I1)', () async {
    expect(await d3dmetalVersion(home), isNull);
    File(
        '$home/backends/d3dmetal/external/D3DMetal.framework/Resources/Info.plist',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>'
        '<key>CFBundleShortVersionString</key><string>3.0</string>'
        '</dict></plist>',
      );
    expect(await d3dmetalVersion(home), '3.0');
  }, skip: File('/usr/bin/plutil').existsSync() ? false : 'needs plutil');

  test(
    'installD3DMetalDmg imports from a dmg, or a dmg inside it (I3)',
    () async {
      Future<String> dmg(String name, String src) async {
        await Process.run('/usr/bin/hdiutil', [
          'create',
          '-quiet',
          '-srcfolder',
          src,
          '-volname',
          name,
          '-ov',
          '$tmp/$name.dmg',
        ]);
        return '$tmp/$name.dmg';
      }

      fakeD3DMetal('$tmp/eval/redist/lib');
      File(
          '$tmp/eval/redist/lib/external/D3DMetal.framework/Resources/Info.plist',
        )
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>'
          '<key>CFBundleShortVersionString</key><string>3.0</string>'
          '</dict></plist>',
        );
      final eval = await dmg('Evaluation environment', '$tmp/eval');
      Directory('$tmp/outer').createSync();
      File(eval).copySync('$tmp/outer/Evaluation environment.dmg');
      final outer = await dmg('Game_Porting_Toolkit_3.0', '$tmp/outer');
      Directory('$tmp/empty').createSync();
      final empty = await dmg('vacio', '$tmp/empty');

      Future<String> mounts() async =>
          '${(await Process.run('/usr/bin/hdiutil', ['info'])).stdout}';

      final steps = <String>[];
      expect(await installD3DMetalDmg(home, eval), '3.0');
      expect(await installD3DMetalDmg(home, outer, onStep: steps.add), '3.0');
      expect(steps, contains('Importando D3DMetal'));
      expect(
        Link('$home/backends/d3dmetal/wine/x86_64-unix/d3d11.so').targetSync(),
        '../../external/libd3dshared.dylib',
      );
      await expectLater(
        installD3DMetalDmg(home, empty),
        throwsA(contains('falta redist/lib')),
      );
      expect(await mounts(), isNot(contains(tmp)));
    },
    skip: File('/usr/bin/hdiutil').existsSync() ? false : 'needs hdiutil',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('listBackends', () {
    expect(listBackends(home), {
      'wine': true,
      'dxmt': false,
      'dxvk': false,
      'd3dmetal': false,
    });
    install(home, 'dxvk');
    expect(listBackends(home)['dxvk'], isTrue);
  });

  test('parseRun', () {
    final plain = parseRun(['t', 'cmd', '/c', 'echo', '--hud'])!;
    expect(plain.bottle, 't');
    expect(plain.hud, isFalse);
    expect(plain.args, ['/c', 'echo', '--hud']);
    final full = parseRun(['--hud', '--backend', 'dxmt', 't', 'a.exe'])!;
    expect(full.hud, isTrue);
    expect(full.backend, 'dxmt');
    expect(full.program, 'a.exe');
    for (final bad in <List<String>>[
      [],
      ['t'],
      ['--backend'],
      ['--backend', 'dxmt', 't'],
      ['--otra', 't', 'a.exe'],
    ]) {
      expect(parseRun(bad), isNull, reason: '$bad');
    }
  });
}
