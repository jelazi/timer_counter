import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Handle launch_at_startup MethodChannel using SMAppService (macOS 13+)
    let launchChannel = FlutterMethodChannel(
      name: "launch_at_startup",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    launchChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "launchAtStartupIsEnabled":
        if #available(macOS 13.0, *) {
          let status = SMAppService.mainApp.status
          result(status == .enabled)
        } else {
          result(false)
        }
      case "launchAtStartupSetEnabled":
        if let arguments = call.arguments as? [String: Any],
           let enabled = arguments["setEnabledValue"] as? Bool {
          if #available(macOS 13.0, *) {
            do {
              if enabled {
                try SMAppService.mainApp.register()
              } else {
                try SMAppService.mainApp.unregister()
              }
              result(nil)
            } catch {
              result(FlutterError(code: "LOGIN_ITEM_ERROR", message: error.localizedDescription, details: nil))
            }
          } else {
            result(FlutterError(code: "UNSUPPORTED", message: "macOS 13+ required for login items", details: nil))
          }
        } else {
          result(FlutterError(code: "BAD_ARGS", message: "Missing setEnabledValue", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
