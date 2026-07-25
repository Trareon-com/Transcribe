import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // The session toolbar (title field, mode selector, MIC/SPK indicators,
    // Mulai/Export buttons) overflows below this width — see main_screen.dart.
    self.contentMinSize = NSSize(width: 860, height: 560)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
