import 'dart:io';

import 'package:flutter/services.dart';

/// Service to hide/show the app in the macOS Dock.
/// On other platforms this is a no-op.
class DockService {
  static const _channel = MethodChannel('com.timer_counter/dock');

  /// Hide the app icon from the macOS Dock (only tray visible).
  static Future<void> hideFromDock() async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('hideFromDock');
    } catch (_) {}
  }

  /// Show the app icon in the macOS Dock again.
  static Future<void> showInDock() async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('showInDock');
    } catch (_) {}
  }
}
