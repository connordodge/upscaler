import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Wide enough for the Output bar on one row with the Custom chip and the `256–8192 px` hint
    // (measured in test/home_page_test.dart, 'minimum window width').
    self.contentMinSize = NSSize(width: 905, height: 720)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
