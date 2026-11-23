import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // An empty unified toolbar gives the 52 pt titlebar of Mail/Finder, so the
    // window buttons line up with the Flutter sidebar and pane toolbars.
    let toolbar = NSToolbar(identifier: "MainToolbar")
    toolbar.showsBaselineSeparator = false
    self.toolbar = toolbar
    if #available(macOS 11.0, *) {
      self.toolbarStyle = .unified
    }
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)

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
