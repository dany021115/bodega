/// A compatdb setting the Native engine sends for one app (PA2). Off leaves
/// Mach9's own default.
enum NativeOption {
  /// No-execute as Wine does it, for old launchers and configurators.
  noForceNx,

  /// The 4 GB address space for a 32-bit game.
  largeAddressAware,

  /// Windows' scaling off, for interfaces drawn in fixed pixels.
  notDpiAware,

  /// macOS's own OpenGL instead of EGL.
  cglOpenGl,

  /// wined3d draws with Vulkan.
  vulkanWined3d,
}
