import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    self.title = "Living Scroll - Weave every thread"

    // Enforce the app's MINIMUM window size (640x480 points — LAYOUTS/window_size)
    // so the user cannot shrink the window below the UI's verified-safe floor.
    self.minSize = NSSize(width: 640, height: 480)
  }
}
