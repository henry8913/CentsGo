import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // CentsGo is designed around a phone-sized column: start with a compact
    // window on desktop and let the user resize it.
    let target = NSSize(width: 760, height: 900)
    self.minSize = NSSize(width: 400, height: 640)
    if let screen = self.screen ?? NSScreen.main {
      let visible = screen.visibleFrame
      let origin = NSPoint(
        x: visible.midX - target.width / 2,
        y: visible.midY - target.height / 2
      )
      self.setFrame(NSRect(origin: origin, size: target), display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
