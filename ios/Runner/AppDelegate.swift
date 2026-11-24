import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PomodoroPermission") {
      registerPomodoroChannel(messenger: registrar.messenger())
    }
  }

  private func registerPomodoroChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.timer_counter/pomodoro", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "authorizationStatus":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let status: String
          switch settings.authorizationStatus {
          case .notDetermined: status = "notDetermined"
          case .denied: status = "denied"
          default: status = "authorized"
          }
          DispatchQueue.main.async { result(status) }
        }
      case "openNotificationSettings":
        let target: String
        if #available(iOS 16.0, *) {
          target = UIApplication.openNotificationSettingsURLString
        } else {
          target = UIApplication.openSettingsURLString
        }
        if let url = URL(string: target) { UIApplication.shared.open(url) }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
