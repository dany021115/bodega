import AVFoundation
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 720, height: 480)
    self.setContentSize(NSSize(width: 1150, height: 800))
    self.center()
    // Starts maximized (the screen's usable area); the size above is what
    // zooming back restores.
    if let screen = self.screen ?? NSScreen.main {
      self.setFrame(screen.visibleFrame, display: true)
    }

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
