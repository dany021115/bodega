import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';

void write(String path, String text) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);
}

void main() {
  late String tmp, home;

  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega-linux')
        .resolveSymbolicLinksSync();
    home = '$tmp/home';
    hostPlatform = const LinuxPlatform();
  });

  tearDown(() {
    hostPlatform = HostPlatform.detect();
    Directory(tmp).deleteSync(recursive: true);
  });

  /// A bottle `b` whose prefix is ready (R7), as Wine leaves it.
  void makeBottle() {
    final prefix = '$home/bottles/b/prefix';
    write('$prefix/system.reg', '');
    write('$prefix/drive_c/windows/syswow64/kernel32.dll', '');
    Directory('$prefix/drive_c/windows/system32').createSync(recursive: true);
  }

  /// The dxvk layer with its VERSION, as the package ships it.
  void makeLayer() {
    for (final file in ['x64/d3d11.dll', 'x64/d3d12.dll', 'x32/d3d11.dll']) {
      write('$home/backends/dxvk/wine/$file', '$file v1');
    }
    write('$home/backends/dxvk/VERSION', 'v1');
  }

  test('baseEnv keeps the session and drops the rest', () {
    final env = hostPlatform.baseEnv({
      'USER': 'ana',
      'HOME': '/h',
      'DISPLAY': ':0',
      'WAYLAND_DISPLAY': 'wayland-0',
      'XDG_RUNTIME_DIR': '/run/user/1000',
      'FOO': 'x',
    });
    expect(env['USER'], 'ana');
    expect(env['LOGNAME'], 'ana');
    expect(env['HOME'], '/h');
    expect(env['DXVK_LOG_LEVEL'], 'none');
    expect(env['VKD3D_DEBUG'], 'none');
    expect(env['VKD3D_SHADER_DEBUG'], 'none');
    expect(env['DISPLAY'], ':0');
    expect(env['WAYLAND_DISPLAY'], 'wayland-0');
    expect(env['XDG_RUNTIME_DIR'], '/run/user/1000');
    for (final key in [
      'FOO',
      'WINEMSYNC',
      'ROSETTA_ADVERTISE_AVX',
      'MVK_CONFIG_LOG_LEVEL',
    ]) {
      expect(env.containsKey(key), isFalse, reason: key);
    }
  });

  test('baseEnv takes LOGNAME as the user when USER is missing', () {
    final env = hostPlatform.baseEnv({'LOGNAME': 'bob'});
    expect(env['USER'], 'bob');
  });

  test('baseEnv gives a PATH when the parent has none', () {
    final env = hostPlatform.baseEnv({'USER': 'ana'});
    expect(env['PATH'], isNotEmpty);
  });

  test('wineEnv adds the prefix and Wine variables', () {
    final env = wineEnv('/p', {'USER': 'ana', 'HOME': '/h'});
    expect(env['WINEPREFIX'], '/p');
    expect(env['WINEDLLOVERRIDES'], 'winemenubuilder.exe=d');
    expect(env['WINEDEBUG'], '-all');

    final debug = wineEnv('/p', {
      'USER': 'ana',
      'HOME': '/h',
      'BODEGA_WINEDEBUG': 'fixme-all',
    });
    expect(debug['WINEDEBUG'], 'fixme-all');
  });

  test('defaultHome uses XDG_DATA_HOME, else ~/.local/share', () {
    expect(
      hostPlatform.defaultHome({'XDG_DATA_HOME': '/x', 'HOME': '/h'}),
      '/x/bodega',
    );
    expect(
      hostPlatform.defaultHome({'HOME': '/h'}),
      '/h/.local/share/bodega',
    );
    expect(
      hostPlatform.defaultHome({'HOME': '/h', 'XDG_DATA_HOME': ''}),
      '/h/.local/share/bodega',
    );
  });

  test('findCI matches each segment without regard to case', () {
    final real = '$tmp/Program Files/Steam/STEAM.EXE';
    write(real, '');
    expect(findCI(tmp, 'Program Files/Steam/STEAM.EXE'), real);
    expect(findCI(tmp, 'program files/steam/steam.exe'), real);
    expect(findCI(tmp, r'program files\steam\steam.exe'), real);
    expect(findCI(tmp, 'nope/x.exe'), '$tmp/nope/x.exe');
  });

  test('the backends are wine and dxvk', () {
    expect(hostPlatform.backendNames, ['wine', 'dxvk']);
    expect(backendNames, ['wine', 'dxvk']);
  });

  test('dxvk overrides the D3D DLLs, and wine sets none', () {
    hostPlatform = const LinuxPlatform(mangoHud: false);
    final dxvk = backendEnv(home, 'dxvk');
    expect(
      dxvk['WINEDLLOVERRIDES'],
      allOf(contains('d3d11'), contains('n,b')),
    );
    expect(dxvk.containsKey('WINEDLLPATH_PREPEND'), isFalse);
    expect(backendEnv(home, 'wine')['WINEDLLOVERRIDES'], endsWith('dxgi=b'));
    expect(backendEnv(home, 'wine', hud: true).containsKey('DXVK_HUD'), isFalse);
    expect(
      backendEnv(home, 'dxvk', hud: true)['DXVK_HUD'],
      'fps,frametimes,gpuload,memory,compiler',
    );
  });

  test('MangoHud replaces DXVK_HUD and logs under the bottle', () {
    final bottle = '$home/bottles/b';
    hostPlatform = const LinuxPlatform(mangoHud: true);
    expect(
      backendEnv(home, 'dxvk', hud: true).containsKey('DXVK_HUD'),
      isFalse,
    );
    final perf = hostPlatform.perfEnv(bottle);
    expect(perf['MANGOHUD'], '1');
    expect(perf['MANGOHUD_CONFIG'], contains('output_folder='));
    expect(perf['MANGOHUD_CONFIG'], contains('autostart_log=1'));
    expect(Directory('$bottle/logs/perf').existsSync(), isTrue);

    hostPlatform = const LinuxPlatform(mangoHud: false);
    expect(hostPlatform.perfEnv(bottle), isEmpty);
  });

  test('dxmt and d3dmetal map to dxvk', () {
    expect(hostPlatform.mapBackend('dxmt'), 'dxvk');
    expect(hostPlatform.mapBackend('d3dmetal'), 'dxvk');
  });

  test('probe cases for wine and dxvk', () {
    expect(hostPlatform.probeCases(home, 'wine'), [(64, '11')]);
    expect(hostPlatform.probeCases(home, 'dxvk'), [
      (64, '11'),
      (64, '12'),
      (32, '11'),
    ]);
  });

  test('autoBackend picks dxvk only when it is installed', () async {
    expect(await hostPlatform.autoBackend(home, null), 'wine');
    Directory('$home/backends/dxvk/wine').createSync(recursive: true);
    expect(await hostPlatform.autoBackend(home, null), 'dxvk');
  });

  test('the Mac-only installers refuse on Linux', () async {
    await expectLater(installSdl(home), throwsA(contains('Linux')));
    await expectLater(importD3DMetal(home, tmp), throwsA(contains('Linux')));
  });

  test('prepareBottle copies the dxvk layer once per VERSION', () async {
    makeBottle();
    makeLayer();
    final windows = '$home/bottles/b/prefix/drive_c/windows';
    final prefix = '$home/bottles/b/prefix';

    await hostPlatform.prepareBottle(home, 'b');
    expect(
      File('$windows/system32/d3d11.dll').readAsStringSync(),
      'x64/d3d11.dll v1',
    );
    expect(File('$windows/system32/d3d12.dll').existsSync(), isTrue);
    expect(
      File('$windows/syswow64/d3d11.dll').readAsStringSync(),
      'x32/d3d11.dll v1',
    );
    expect(File('$prefix/.bodega-dxvk').readAsStringSync(), 'v1');

    // Same VERSION: the layer changes, but nothing is copied.
    write('$home/backends/dxvk/wine/x64/d3d11.dll', 'changed');
    await hostPlatform.prepareBottle(home, 'b');
    expect(
      File('$windows/system32/d3d11.dll').readAsStringSync(),
      'x64/d3d11.dll v1',
    );

    write('$home/backends/dxvk/VERSION', 'v2');
    await hostPlatform.prepareBottle(home, 'b');
    expect(File('$windows/system32/d3d11.dll').readAsStringSync(), 'changed');
    expect(File('$prefix/.bodega-dxvk').readAsStringSync(), 'v2');
  });

  test('GPU, sync and resolution follow Linux', () {
    expect(hostPlatform.gpuEnv('discrete')['DRI_PRIME'], '1');
    expect(hostPlatform.gpuEnv('auto'), isEmpty);
    expect(hostPlatform.highResRegistry(true), [
      [r'HKCU\Control Panel\Desktop', 'LogPixels', 'REG_DWORD', '192'],
    ]);
    expect(hostPlatform.syncEnv('none'), isEmpty);
  });

  test('capabilities of Linux', () {
    final caps = hostCapabilities();
    expect(caps.syncModes, ['none']);
    expect(caps.avx, isFalse);
    expect(caps.dlss, isFalse);
    expect(caps.d3dmetal, isFalse);
    expect(caps.sdl, isFalse);
    expect(caps.gpu, isTrue);
  });

  test('setBottleOptions accepts only auto or discrete for gpu', () {
    makeBottle();
    expect(
      () => setBottleOptions(home, 'b', gpu: 'turbo'),
      throwsA(contains('gpu desconocida')),
    );
    setBottleOptions(home, 'b', gpu: 'discrete');
    expect(bottleSettings(home, 'b').gpu, 'discrete');
  });

  test('GameMode is on by default and saved only when changed', () {
    makeBottle();
    final file = File('$home/bottles/b/settings.json');
    expect(bottleSettings(home, 'b').gamemode, isTrue);

    setBottleOptions(home, 'b', gamemode: false);
    expect(bottleSettings(home, 'b').gamemode, isFalse);
    expect(file.readAsStringSync(), contains('"gamemode": false'));

    setBottleOptions(home, 'b', gamemode: true);
    expect(file.readAsStringSync(), isNot(contains('gamemode')));
  });

  group('the Mac, under the same host', () {
    test('keeps msync and its own environment', () {
      hostPlatform = const TestMac();
      final env = wineEnv('/p', {'USER': 'ana', 'HOME': '/h'});
      expect(env['WINEMSYNC'], '1');
      expect(env['PATH'], '/usr/bin:/bin:/usr/sbin:/sbin');
      expect(hostPlatform.syncEnv('none'), {'WINEMSYNC': '0'});
      expect(hostPlatform.capabilities.syncModes, ['msync', 'none']);
    });

    test('GameMode is off by default and saved when on', () {
      hostPlatform = const TestMac();
      makeBottle();
      expect(bottleSettings(home, 'b').gamemode, isFalse);

      setBottleOptions(home, 'b', gamemode: true);
      expect(
        File('$home/bottles/b/settings.json').readAsStringSync(),
        contains('"gamemode": true'),
      );
    });
  });
}
