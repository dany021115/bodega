part of 'engine.dart';

/// A gamepad the kernel sees: [node] is its `/dev/input/event*` file and
/// [readable] whether this user can open it. Wine reads it through SDL2 or
/// udev, and both need that access.
typedef Gamepad = ({
  String name,
  String vid,
  String pid,
  String node,
  bool readable,
});

/// What [HostPlatform.gamepads] found: the pads, whether SDL2 is installed, and
/// what to fix. Unlike [HostIssue]s from `checkHost`, none of this stops a game
/// from running.
typedef GamepadReport = ({
  List<Gamepad> pads,
  bool sdl,
  List<HostIssue> issues,
});

/// The joysticks in `/proc/bus/input/devices`: the blocks whose handlers name
/// a `jsN`, which the kernel gives to every device with gamepad or joystick
/// buttons or axes. [readable] decides if a node can be opened.
List<Gamepad> parseInputDevices(
  String proc, {
  bool Function(String node)? readable,
}) {
  final pads = <Gamepad>[];
  for (final block in proc.split(RegExp(r'\n\s*\n'))) {
    final id = RegExp(
      r'^I: .*Vendor=([0-9a-f]{4}) Product=([0-9a-f]{4})',
      multiLine: true,
    ).firstMatch(block);
    final name = RegExp(r'^N: Name="(.*)"', multiLine: true).firstMatch(block);
    final handlers = RegExp(
      r'^H: Handlers=(.*)$',
      multiLine: true,
    ).firstMatch(block)?.group(1);
    if (id == null || name == null || handlers == null) continue;
    final words = handlers.trim().split(RegExp(r'\s+'));
    final event = words.where((word) => RegExp(r'^event\d+$').hasMatch(word));
    if (event.isEmpty ||
        !words.any((word) => RegExp(r'^js\d+$').hasMatch(word))) {
      continue;
    }
    final node = '/dev/input/${event.first}';
    pads.add((
      name: name.group(1)!,
      vid: id.group(1)!,
      pid: id.group(2)!,
      node: node,
      readable: readable?.call(node) ?? true,
    ));
  }
  return pads;
}

/// What is wrong, from the pads found and whether SDL2 is installed. [install]
/// builds the command for the distro, as [_installCommand] does.
List<HostIssue> gamepadIssues(
  List<Gamepad> pads, {
  required bool sdl,
  required String? Function(String apt, String? dnf, String pacman) install,
}) => [
  for (final pad in pads)
    if (!pad.readable)
      (
        id: 'padPermission',
        args: {'name': pad.name, 'node': pad.node},
        title: 'No permission for the gamepad ${pad.name}',
        detail:
            'Bodega can\'t open ${pad.node}, so Wine won\'t see the gamepad. '
            'It needs the gamepad udev rules (on Arch, the package is in '
            'multilib). Then unplug the gamepad and plug it back in.',
        command: install('steam-devices', null, 'steam-devices'),
      ),
  if (!sdl)
    (
      id: 'sdl',
      args: const {},
      title: 'SDL2 is missing',
      detail:
          'Wine uses SDL2 to understand gamepads. Without it, it uses udev, '
          'which knows fewer gamepads.',
      command: install('libsdl2-2.0-0', 'SDL2', 'sdl2-compat'),
    ),
];
