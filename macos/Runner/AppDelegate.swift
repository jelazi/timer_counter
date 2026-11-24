import Cocoa
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate {

  /// Keep a reference to the notification channel so we can call back to Dart.
  private var notifChannel: FlutterMethodChannel?

  /// Pomodoro notifications: shown silently (the app plays its own sounds) and,
  /// when tapped while a phase waits, reported back instead of raising the window.
  private var pomodoroChannel: FlutterMethodChannel?

  /// Maps category identifier → reminder type string for "mute today" callback.
  private let categoryToType: [String: String] = [
    "REMIND_START": "start",
    "REMIND_STOP": "stop",
    "REMIND_BREAK": "break",
  ]

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // MARK: - UNUserNotificationCenterDelegate

  // Allow notifications to show even when app is in foreground
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    NSLog("[WorkReminder] willPresent called for: %@", notification.request.identifier)
    if #available(macOS 11.0, *) {
      NSLog("[WorkReminder] Showing banner + list + sound")
      completionHandler([.banner, .list, .sound])
    } else {
      NSLog("[WorkReminder] macOS < 11, sound only")
      completionHandler([.sound])
    }
  }

  // Handle notification action (tap or "Don't remind today")
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let actionId = response.actionIdentifier
    let categoryId = response.notification.request.content.categoryIdentifier

    if categoryId.hasPrefix("POMODORO") {
      if categoryId == "POMODORO_AWAITING" && actionId == UNNotificationDefaultActionIdentifier {
        DispatchQueue.main.async { [weak self] in
          self?.pomodoroChannel?.invokeMethod("onStartPending", arguments: nil)
        }
      }
      completionHandler()
      return
    }

    if actionId == "MUTE_TODAY_ACTION" {
      // User tapped "Don't remind today" — send back to Dart
      if let type = categoryToType[categoryId] {
        DispatchQueue.main.async { [weak self] in
          self?.notifChannel?.invokeMethod("onMuteToday", arguments: type)
        }
      }
    } else {
      // Default tap — bring app to front
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
      if let window = mainFlutterWindow {
        window.makeKeyAndOrderFront(nil)
      }
    }
    completionHandler()
  }

  // MARK: - Register notification categories with "Don't remind today" action

  private func registerNotificationCategories() {
    let muteAction = UNNotificationAction(
      identifier: "MUTE_TODAY_ACTION",
      title: "Don't remind today",
      options: []
    )

    let categories: Set<UNNotificationCategory> = [
      UNNotificationCategory(identifier: "REMIND_START", actions: [muteAction], intentIdentifiers: [], options: []),
      UNNotificationCategory(identifier: "REMIND_STOP", actions: [muteAction], intentIdentifiers: [], options: []),
      UNNotificationCategory(identifier: "REMIND_BREAK", actions: [muteAction], intentIdentifiers: [], options: []),
      UNNotificationCategory(identifier: "POMODORO", actions: [], intentIdentifiers: [], options: []),
      UNNotificationCategory(identifier: "POMODORO_AWAITING", actions: [], intentIdentifiers: [], options: []),
    ]

    UNUserNotificationCenter.current().setNotificationCategories(categories)
  }

  // MARK: - Application lifecycle

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController

    // Set notification delegate
    UNUserNotificationCenter.current().delegate = self

    // Dock hide/show channel
    let dockChannel = FlutterMethodChannel(name: "com.timer_counter/dock", binaryMessenger: controller.engine.binaryMessenger)

    dockChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "hideFromDock":
        NSApp.setActivationPolicy(.accessory)
        result(nil)
      case "showInDock":
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
          NSApp.activate(ignoringOtherApps: true)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let pomodoro = FlutterMethodChannel(name: "com.timer_counter/pomodoro", binaryMessenger: controller.engine.binaryMessenger)
    self.pomodoroChannel = pomodoro
    pomodoro.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "show":
        guard let args = call.arguments as? [String: Any],
              let title = args["title"] as? String,
              let body = args["body"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "Missing title or body", details: nil))
          return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = (args["awaiting"] as? Bool ?? false) ? "POMODORO_AWAITING" : "POMODORO"
        let identifier = args["identifier"] as? String ?? "pomodoro"
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil)) { error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(code: "NOTIFICATION_ERROR", message: error.localizedDescription, details: nil))
            } else {
              result(nil)
            }
          }
        }
      case "clear":
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["pomodoro_phase"])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Notifications channel
    let channel = FlutterMethodChannel(name: "com.timer_counter/notifications", binaryMessenger: controller.engine.binaryMessenger)
    self.notifChannel = channel

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "requestPermission":
        NSLog("[WorkReminder] requestPermission called")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
          DispatchQueue.main.async {
            if let error = error {
              NSLog("[WorkReminder] Permission error: %@", error.localizedDescription)
              result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil))
            } else {
              NSLog("[WorkReminder] Permission granted: %@", granted ? "YES" : "NO")
              result(granted)
            }
          }
        }

      case "registerActions":
        self?.registerNotificationCategories()
        result(nil)

      case "showNotification":
        NSLog("[WorkReminder] showNotification called")
        if let args = call.arguments as? [String: Any],
           let title = args["title"] as? String,
           let body = args["body"] as? String {
          let identifier = args["identifier"] as? String ?? "work_reminder"
          let categoryIdentifier = args["categoryIdentifier"] as? String ?? ""

          NSLog("[WorkReminder] Creating notification: id=%@, cat=%@, title=%@", identifier, categoryIdentifier, title)

          let content = UNMutableNotificationContent()
          content.title = title
          content.body = body
          content.sound = .default
          content.categoryIdentifier = categoryIdentifier

          let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
          UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
              if let error = error {
                NSLog("[WorkReminder] Notification error: %@", error.localizedDescription)
                result(FlutterError(code: "NOTIFICATION_ERROR", message: error.localizedDescription, details: nil))
              } else {
                NSLog("[WorkReminder] Notification added successfully: %@", identifier)
                result(nil)
              }
            }
          }
        } else {
          NSLog("[WorkReminder] Bad args for showNotification")
          result(FlutterError(code: "BAD_ARGS", message: "Missing title or body", details: nil))
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
