import AVFoundation
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let frameName = "BodegaMainWindow"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 720, height: 480)
    // Starts at a fixed size, centered and never larger than the screen's
    // usable area: maximized, an ultrawide screen stretched every page across
    // it. Zoom still maximizes.
    let visible = (self.screen ?? NSScreen.main)?.visibleFrame
    self.setContentSize(
      NSSize(
        width: min(1150, visible?.width ?? 1150),
        height: min(800, visible?.height ?? 800)))
    self.center()
    // Later launches open where, and as big as, the user left the window.
    _ = self.setFrameUsingName(Self.frameName)
    self.setFrameAutosaveName(Self.frameName)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Games open the microphone (voice chat) through Wine, and macOS asks
    // Bodega. Asked here, once, so no game waits on the question with its
    // window frozen (MW3 stayed black).
    if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
      AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }

    super.awakeFromNib()
  }
}
