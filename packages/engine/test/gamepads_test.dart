import 'package:engine/engine.dart';
import 'package:test/test.dart';

// Taken from a Linux machine with an 8BitDo receiver plugged in: the pad has a
// jsN handler, and the receiver's keyboard and mouse, which share its USB ids,
// do not.
const _proc = '''
I: Bus=0011 Vendor=0001 Product=0001 Version=ab41
N: Name="AT Translated Set 2 keyboard"
P: Phys=isa0060/serio0/input0
H: Handlers=sysrq kbd leds event3 
B: PROP=0

I: Bus=0003 Vendor=2dc8 Product=310b Version=0100
N: Name="8BitDo Ultimate 2 Wireless Controller"
P: Phys=usb-0000:00:14.0-5/input0
H: Handlers=event27 js1 
B: PROP=0

I: Bus=0003 Vendor=2dc8 Product=310b Version=0111
N: Name="8BitDo 8BitDo UM 2 Receiver Mouse"
P: Phys=usb-0000:00:14.0-5/input1
H: Handlers=event29 mouse4 
B: PROP=0

I: Bus=0003 Vendor=045e Product=028e Version=0110
N: Name="Microsoft X-Box 360 pad"
H: Handlers=event26 js0 
B: PROP=0
''';

String? _install(String apt, String? dnf, String pacman) =>
    'apt: $apt dnf: $dnf pacman: $pacman';

void main() {
  test('only devices with a joystick handler are gamepads', () {
    final pads = parseInputDevices(_proc);
    expect(pads.map((pad) => pad.name), [
      '8BitDo Ultimate 2 Wireless Controller',
      'Microsoft X-Box 360 pad',
    ]);
    expect(pads.first.node, '/dev/input/event27');
    expect((pads.first.vid, pads.first.pid), ('2dc8', '310b'));
  });

  test('no devices file means no pads', () {
    expect(parseInputDevices(''), isEmpty);
  });

  test('a pad that cannot be opened is reported by name, with the udev rules, '
      'and missing SDL2 too (E3)', () {
    final pads = parseInputDevices(
      _proc,
      readable: (node) => node != '/dev/input/event27',
    );
    expect(gamepadIssues(pads, sdl: false, install: _install), [
      // Fedora has no package for the rules: the command is left for the
      // distro to fill.
      (
        kind: HostIssueKind.padNoAccess,
        subject: '8BitDo Ultimate 2 Wireless Controller',
        command: 'apt: steam-devices dnf: null pacman: steam-devices',
      ),
      (
        kind: HostIssueKind.noSdl,
        subject: null,
        command: 'apt: libsdl2-2.0-0 dnf: SDL2 pacman: sdl2-compat',
      ),
    ]);
  });

  test('missing SDL2 is reported with or without pads', () {
    final issues = gamepadIssues(const [], sdl: false, install: _install);
    expect(issues.single.kind, HostIssueKind.noSdl);
    expect(issues.single.command, contains('sdl2-compat'));
  });

  test('readable pads and SDL2 mean nothing to fix', () {
    expect(
      gamepadIssues(parseInputDevices(_proc), sdl: true, install: _install),
      isEmpty,
    );
  });
}
