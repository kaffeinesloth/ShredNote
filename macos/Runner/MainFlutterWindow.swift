import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let hapticsChannel = FlutterMethodChannel(
      name: "shred_note/haptics",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    hapticsChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "paperScroll":
        NSHapticFeedbackManager.defaultPerformer.perform(
          .levelChange,
          performanceTime: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.035) {
          NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .now)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
